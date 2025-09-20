import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../../models/club.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../club_invite_qr_screen.dart';

// Lightweight contact model for caching
class CachedContact {
  final String id;
  final String displayName;
  final String primaryPhone;

  CachedContact({
    required this.id,
    required this.displayName,
    required this.primaryPhone,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'primaryPhone': primaryPhone,
  };

  factory CachedContact.fromJson(Map<String, dynamic> json) => CachedContact(
    id: json['id'],
    displayName: json['displayName'],
    primaryPhone: json['primaryPhone'],
  );

  factory CachedContact.fromContact(Contact contact) => CachedContact(
    id: contact.id,
    displayName: contact.displayName,
    primaryPhone: contact.phones.isNotEmpty ? contact.phones.first.number : '',
  );
}

// Synced contact from contact-sync API
class SyncedContact {
  final String? userId; // null if not a Duggy user
  final String name;
  final String phoneNumber;
  final String? memberId;
  final String? profilePicture;
  final bool isClubMember;
  final String? clubRole;
  final String? status; // 'active', 'inactive', 'pending', 'banned'

  SyncedContact({
    this.userId,
    required this.name,
    required this.phoneNumber,
    this.memberId,
    this.profilePicture,
    required this.isClubMember,
    this.clubRole,
    this.status,
  });

  factory SyncedContact.fromJson(Map<String, dynamic> json) => SyncedContact(
    userId: json['userId'],
    name: json['name'],
    phoneNumber: json['phoneNumber'],
    memberId: json['memberId'],
    profilePicture: json['profilePicture'],
    isClubMember: json['isClubMember'] ?? false,
    clubRole: json['clubRole'],
    status: json['status'],
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'phoneNumber': phoneNumber,
    'memberId': memberId,
    'profilePicture': profilePicture,
    'isClubMember': isClubMember,
    'clubRole': clubRole,
    'status': status,
  };

  bool get isAlreadyMember => isClubMember;
  bool get isDuggyUser => userId != null;
  bool get isBanned => status == 'banned';
  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get canBeAdded => isDuggyUser && !isClubMember;
}

class AddMembersScreen extends StatefulWidget {
  final Club club;
  final Function(List<Contact>)? onContactsSelected;
  final Function(List<SyncedContact>)? onSyncedContactsSelected;

  const AddMembersScreen({
    Key? key,
    required this.club,
    this.onContactsSelected,
    this.onSyncedContactsSelected,
  }) : super(key: key);

  @override
  AddMembersScreenState createState() => AddMembersScreenState();
}

class AddMembersScreenState extends State<AddMembersScreen> {
  // Use cached contacts for performance
  List<CachedContact> _allCachedContacts = [];
  List<CachedContact> _filteredCachedContacts = [];

  // Original contacts map for selection callback
  Map<String, Contact> _contactsMap = {};

  // Synced contacts from contact-sync API (replaces Duggy user search)
  List<SyncedContact> _syncedContacts = [];
  Map<String, SyncedContact> _syncedContactsMap = {};
  bool _isSyncingContacts = false;
  Timer? _searchTimer;

  final Set<String> _selectedContactIds = {};
  final Set<String> _selectedSyncedContactIds = {};
  String _searchQuery = '';
  bool _isLoadingFromCache = true;
  final TextEditingController _searchController = TextEditingController();

  static const String _cacheKey = 'cached_contacts_v1';
  static const String _cacheTimestampKey = 'contacts_cache_timestamp';
  static const String _syncedCacheKey = 'synced_contacts_v1';
  static const String _syncedCacheTimestampKey = 'synced_contacts_cache_timestamp';
  static const int _cacheValidityHours = 24; // Cache valid for 24 hours

  @override
  void initState() {
    super.initState();
    _loadContactsOptimized();
    // Fallback timeout to ensure loading doesn't hang
    Timer(Duration(seconds: 10), () {
      if (_isLoadingFromCache && mounted) {
        print('📱 Loading timeout, forcing fresh load...');
        setState(() {
          _isLoadingFromCache = false;
        });
        _loadFreshContacts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContactsOptimized() async {
    try {
      print('⚡ Loading contacts with caching optimization...');

      // Step 1: Try to load contacts from cache first
      final cachedContacts = await _loadContactsFromCache();
      if (cachedContacts != null && cachedContacts.isNotEmpty) {
        print('📱 Loaded ${cachedContacts.length} contacts from cache');
        _displayCachedContacts(cachedContacts);

        // Step 2: Try to load synced contacts from cache
        final cachedSyncedContacts = await _loadSyncedContactsFromCache();
        if (cachedSyncedContacts != null && cachedSyncedContacts.isNotEmpty) {
          print('🔄 Loaded ${cachedSyncedContacts.length} synced contacts from cache');
          setState(() {
            _syncedContacts = cachedSyncedContacts;
            _syncedContactsMap = {
              for (final contact in cachedSyncedContacts)
                contact.phoneNumber.replaceAll(RegExp(r'[^\d]'), ''): contact
            };
          });
        } else {
          // No synced cache - sync in background
          _syncContactsWithDuggy();
        }

        // Load fresh contacts in background for next time
        _loadFreshContactsInBackground();
        return;
      }

      print('📱 No contacts cache found, loading fresh contacts...');
      // No cache - load directly
      await _loadFreshContacts();
    } catch (e) {
      print('📱 Error loading contacts: $e');
      setState(() {
        _isLoadingFromCache = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<CachedContact>?> _loadContactsFromCache() async {
    try {
      print('📱 Attempting to load from cache...');
      final prefs = await SharedPreferences.getInstance();
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      print('📱 Cache timestamp: $cacheTimestamp, Current: $now');

      // Check if cache is still valid
      if (now - cacheTimestamp < _cacheValidityHours * 60 * 60 * 1000) {
        final cachedData = prefs.getString(_cacheKey);
        if (cachedData != null && cachedData.isNotEmpty) {
          print('📱 Found cached data, parsing...');
          final List<dynamic> jsonList = json.decode(cachedData);
          final contacts = jsonList.map((json) => CachedContact.fromJson(json)).toList();
          print('📱 Successfully parsed ${contacts.length} cached contacts');
          return contacts;
        } else {
          print('📱 Cache data is null or empty');
        }
      } else {
        print('📱 Cache is expired');
      }
    } catch (e) {
      print('📱 Cache load error: $e');
    }
    print('📱 No valid cache found');
    return null;
  }

  Future<List<SyncedContact>?> _loadSyncedContactsFromCache() async {
    try {
      print('🔄 Attempting to load synced contacts from cache...');
      final prefs = await SharedPreferences.getInstance();
      final cacheTimestamp = prefs.getInt(_syncedCacheTimestampKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      print('🔄 Synced cache timestamp: $cacheTimestamp, Current: $now');

      // Check if cache is still valid
      if (now - cacheTimestamp < _cacheValidityHours * 60 * 60 * 1000) {
        final cachedData = prefs.getString(_syncedCacheKey);
        if (cachedData != null && cachedData.isNotEmpty) {
          print('🔄 Found synced cached data, parsing...');
          final List<dynamic> jsonList = json.decode(cachedData);
          final syncedContacts = jsonList.map((json) => SyncedContact.fromJson(json)).toList();
          print('🔄 Successfully parsed ${syncedContacts.length} cached synced contacts');
          return syncedContacts;
        } else {
          print('🔄 Synced cache data is null or empty');
        }
      } else {
        print('🔄 Synced cache is expired');
      }
    } catch (e) {
      print('🔄 Synced cache load error: $e');
    }
    print('🔄 No valid synced cache found');
    return null;
  }

  void _displayCachedContacts(List<CachedContact> cachedContacts) {
    setState(() {
      _allCachedContacts = cachedContacts;
      _filteredCachedContacts = List.from(cachedContacts);
      _isLoadingFromCache = false;
      // Keep _isLoading true until we have real contacts for selection
    });
  }

  Future<void> _loadFreshContactsInBackground() async {
    try {
      // Load real contacts for selection callback
      await _loadFreshContacts(updateUI: false);
    } catch (e) {
      print('📱 Background refresh error: $e');
    }
  }

  Future<void> _loadFreshContacts({bool updateUI = true}) async {
    print('📱 Loading fresh contacts...');
    List<Contact> contacts = await FlutterContacts.getContacts(
      withProperties: true,
    ).timeout(
      Duration(seconds: 30),
      onTimeout: () {
        print('📱 Contact loading timed out');
        throw TimeoutException('Contact loading timed out', Duration(seconds: 30));
      },
    );

    // Filter contacts with phone numbers and display names
    contacts = contacts
        .where(
          (contact) =>
              contact.phones.isNotEmpty && contact.displayName.isNotEmpty,
        )
        .toList();

    // Sort contacts alphabetically
    contacts.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    // Create contacts map for selection
    final contactsMap = <String, Contact>{};
    for (final contact in contacts) {
      contactsMap[contact.id] = contact;
    }

    // Convert to cached contacts
    final cachedContacts = contacts
        .map((contact) => CachedContact.fromContact(contact))
        .toList();

    // Cache the data
    await _saveToCache(cachedContacts);

    if (updateUI) {
      setState(() {
        _allCachedContacts = cachedContacts;
        _filteredCachedContacts = List.from(cachedContacts);
        _contactsMap = contactsMap;
        _isLoading = false;
        _isLoadingFromCache = false;
      });

      print('📱 Loaded ${contacts.length} fresh contacts');
    } else {
      // Update contacts map for selection without UI update
      _contactsMap = contactsMap;
      setState(() {
        _isLoading = false;
      });
      print('📱 Updated ${contacts.length} contacts in background');
    }

    // After loading contacts, sync them to find Duggy users
    await _syncContactsWithDuggy();
  }

  Future<void> _saveToCache(List<CachedContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(contacts.map((c) => c.toJson()).toList());
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('📱 Cached ${contacts.length} contacts');
    } catch (e) {
      print('📱 Cache save error: $e');
    }
  }

  Future<void> _saveSyncedContactsToCache(List<SyncedContact> syncedContacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(syncedContacts.map((c) => c.toJson()).toList());
      await prefs.setString(_syncedCacheKey, jsonString);
      await prefs.setInt(
        _syncedCacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('🔄 Cached ${syncedContacts.length} synced contacts');
    } catch (e) {
      print('🔄 Synced cache save error: $e');
    }
  }

  Future<void> _manualSyncContacts() async {
    if (_isSyncingContacts) return; // Already syncing

    print('🔄 Manual sync requested by user');

    // If we have contacts loaded, sync them
    if (_allCachedContacts.isNotEmpty) {
      await _syncContactsWithDuggy();
    } else {
      // Load fresh contacts first, then sync
      await _loadFreshContacts();
    }

    HapticFeedback.lightImpact();
  }

  Future<void> _syncContactsWithDuggy() async {
    if (_allCachedContacts.isEmpty) {
      print('🔄 No contacts to sync');
      return;
    }

    setState(() {
      _isSyncingContacts = true;
    });

    try {
      print('🔄 Syncing ${_allCachedContacts.length} contacts with Duggy...');

      // Prepare contacts for API
      final contactsToSync = _allCachedContacts
          .where((contact) => contact.primaryPhone.isNotEmpty)
          .map((contact) => {
                'name': contact.displayName,
                'phoneNumber': contact.primaryPhone,
              })
          .toList();

      if (contactsToSync.isEmpty) {
        print('🔄 No contacts with phone numbers to sync');
        setState(() {
          _isSyncingContacts = false;
        });
        return;
      }

      // Call contact-sync API
      final response = await ApiService.post(
        '/clubs/${widget.club.id}/contact-sync',
        {'contacts': contactsToSync},
      );

      final List<dynamic> contactsData = response['contacts'] ?? [];
      final syncedContacts = contactsData
          .map((contactData) => SyncedContact.fromJson(contactData))
          .toList();

      // Create map for quick lookup
      final syncedContactsMap = <String, SyncedContact>{};
      for (final contact in syncedContacts) {
        // Clean phone number for matching
        final cleanPhone = contact.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
        syncedContactsMap[cleanPhone] = contact;
      }

      setState(() {
        _syncedContacts = syncedContacts;
        _syncedContactsMap = syncedContactsMap;
        _isSyncingContacts = false;
      });

      // Cache the synced contacts for future use
      await _saveSyncedContactsToCache(syncedContacts);

      print('🔄 Successfully synced ${syncedContacts.length} Duggy users');
    } catch (e) {
      print('❌ Contact sync error: $e');
      setState(() {
        _isSyncingContacts = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _filterContacts(String query) {
    print('🔍 Filtering cached contacts with query: "$query"');
    print('📱 Total cached contacts: ${_allCachedContacts.length}');

    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchQuery = '';
        _filteredCachedContacts = List.from(_allCachedContacts);
      });
      print('📱 No query - showing all ${_allCachedContacts.length} contacts');
      return;
    }

    final lowercaseQuery = trimmedQuery.toLowerCase();
    final filteredList = _allCachedContacts.where((contact) {
      // Search in name (check if contact name contains the search query)
      final nameMatch = contact.displayName.toLowerCase().contains(lowercaseQuery);

      // Search in phone number (only if query contains digits)
      bool phoneMatch = false;
      if (RegExp(r'\d').hasMatch(trimmedQuery)) {
        final cleanPhone = contact.primaryPhone.replaceAll(RegExp(r'[^\d]'), '');
        final cleanQuery = trimmedQuery.replaceAll(RegExp(r'[^\d]'), '');
        phoneMatch = cleanPhone.isNotEmpty && cleanQuery.isNotEmpty && cleanPhone.contains(cleanQuery);
      }

      final matches = nameMatch || phoneMatch;
      if (matches) {
        print('📱 Match: ${contact.displayName} - name:$nameMatch, phone:$phoneMatch');
      }
      return matches;
    }).toList();

    setState(() {
      _searchQuery = trimmedQuery;
      _filteredCachedContacts = filteredList;
    });

    print('📱 Query "$trimmedQuery" - filtered to ${_filteredCachedContacts.length} contacts');

    // The synced contacts already contain all the information we need
    // No need for separate Duggy user search as contact-sync provides this
  }


  void _toggleContactSelection(String contactId) {
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else {
        _selectedContactIds.add(contactId);
      }
    });
    HapticFeedback.lightImpact();
  }


  bool _isContactAlreadyMember(CachedContact contact) {
    if (contact.primaryPhone.isEmpty) return false;
    final cleanPhone = contact.primaryPhone.replaceAll(RegExp(r'[^\d]'), '');
    final syncedContact = _syncedContactsMap[cleanPhone];
    return syncedContact?.isClubMember ?? false;
  }

  bool _isSyncedContactAlreadyMember(SyncedContact syncedContact) {
    return syncedContact.isClubMember;
  }

  List<Contact> _getSelectedContacts() {
    return _selectedContactIds
        .where((id) => _contactsMap.containsKey(id))
        .map((id) => _contactsMap[id]!)
        .toList();
  }

  List<SyncedContact> _getSelectedSyncedContacts() {
    return _selectedSyncedContactIds
        .map((id) => _syncedContacts.firstWhere((contact) => contact.userId == id || contact.phoneNumber.replaceAll(RegExp(r'[^\d]'), '') == id))
        .toList();
  }

  void _confirmSelection() {
    final selectedContacts = _getSelectedContacts();
    final selectedSyncedContacts = _getSelectedSyncedContacts();

    if (widget.onContactsSelected != null && selectedContacts.isNotEmpty) {
      widget.onContactsSelected!(selectedContacts);
    }

    if (widget.onSyncedContactsSelected != null && selectedSyncedContacts.isNotEmpty) {
      widget.onSyncedContactsSelected!(selectedSyncedContacts);
    }

    Navigator.pop(context);
  }

  void _inviteViaLink() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubInviteQRScreen(club: widget.club),
      ),
    );
  }

  // Group cached contacts by first letter
  Map<String, List<CachedContact>> _groupContactsByLetter() {
    final Map<String, List<CachedContact>> grouped = {};
    print(
      '📱 Grouping ${_filteredCachedContacts.length} filtered cached contacts',
    );
    for (final contact in _filteredCachedContacts) {
      final firstLetter = contact.displayName.isNotEmpty
          ? contact.displayName[0].toUpperCase()
          : '#';
      if (!grouped.containsKey(firstLetter)) {
        grouped[firstLetter] = [];
      }
      grouped[firstLetter]!.add(contact);
    }
    print(
      '📱 Grouped into ${grouped.keys.length} letter groups: ${grouped.keys.join(', ')}',
    );
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final groupedContacts = _groupContactsByLetter();
    print('📱 Building UI with ${groupedContacts.length} groups, search: "$_searchQuery"');

    return Scaffold(
      backgroundColor: isDarkTheme ? Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkTheme ? Color(0xFF1e1e1e) : Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF06aeef),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        leadingWidth: 80,
        title: Column(
          children: [
            Text(
              'Add members',
              style: TextStyle(
                color: isDarkTheme ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_selectedContactIds.length + _selectedDuggyUserIds.length}/${_allCachedContacts.length + _duggyUsers.length}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_selectedContactIds.isNotEmpty || _selectedDuggyUserIds.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                'Add',
                style: TextStyle(
                  color: Color(0xFF06aeef),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text(
                'Add',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.grey[300]),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            color: isDarkTheme ? Color(0xFF1e1e1e) : Colors.white,
            child: Container(
              decoration: BoxDecoration(
                color: isDarkTheme ? Color(0xFF2c2c2c) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterContacts,
                style: TextStyle(
                  color: isDarkTheme ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by 10-digit phone number',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey[500],
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterContacts('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Invite via link section
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkTheme ? Color(0xFF1e1e1e) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF06aeef).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.link, color: Color(0xFF06aeef), size: 20),
              ),
              title: Text(
                'Invite via link or QR code',
                style: TextStyle(
                  color: isDarkTheme ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _inviteViaLink,
            ),
          ),

          // Contacts List
          Expanded(
            child: _isLoadingFromCache
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF06aeef)),
                        SizedBox(height: 16),
                        Text(
                          'Loading contacts...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Synced Contacts Section (Duggy Users)
                        if (_searchQuery.isNotEmpty && _syncedContacts.where((c) => c.isDuggyUser).isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.people, color: Color(0xFF06aeef), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Duggy Users',
                                  style: TextStyle(
                                    color: Color(0xFF06aeef),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_isSyncingContacts) ...[
                                  SizedBox(width: 8),
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF06aeef),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_syncedContacts.where((c) => c.isDuggyUser).isNotEmpty)
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDarkTheme ? Color(0xFF1e1e1e) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: _duggyUsers.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final user = entry.value;
                                  final isSelected = _selectedDuggyUserIds.contains(user.id);
                                  final isLast = index == _duggyUsers.length - 1;

                                  return Column(
                                    children: [
                                      _buildDuggyUserTile(user, isSelected, _isDuggyUserAlreadyMember(user)),
                                      if (!isLast)
                                        Divider(
                                          height: 1,
                                          indent: 56,
                                          color: Colors.grey[200],
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          SizedBox(height: 12),
                        ],

                        // Contacts Section Header
                        if (_allCachedContacts.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.contacts, color: Colors.grey[600], size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Contacts',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Spacer(),
                                // Sync icon for manual refresh
                                GestureDetector(
                                  onTap: _manualSyncContacts,
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    child: _isSyncingContacts
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF06aeef),
                                            ),
                                          )
                                        : Icon(
                                            Icons.sync,
                                            color: Color(0xFF06aeef),
                                            size: 20,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Alphabetical contacts
                        ...groupedContacts.entries.map((entry) {
                          final letter = entry.key;
                          final contacts = entry.value;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Letter header
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Contacts in this letter group
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDarkTheme
                                      ? Color(0xFF1e1e1e)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: contacts.asMap().entries.map((
                                    contactEntry,
                                  ) {
                                    final index = contactEntry.key;
                                    final contact = contactEntry.value;
                                    final isSelected = _selectedContactIds
                                        .contains(contact.id);
                                    final isLast = index == contacts.length - 1;

                                    return Column(
                                      children: [
                                        _buildCachedContactTile(
                                          contact,
                                          isSelected,
                                          _isContactAlreadyMember(contact),
                                        ),
                                        if (!isLast)
                                          Divider(
                                            height: 1,
                                            indent: 56,
                                            color: Colors.grey[200],
                                          ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                              SizedBox(height: 12),
                            ],
                          );
                        }).toList(),

                        SizedBox(
                          height: 100,
                        ), // Bottom padding for floating button
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedContactTile(CachedContact contact, bool isSelected, bool isDisabled) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isDisabled ? null : () => _toggleContactSelection(contact.id),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF06aeef).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName[0].toUpperCase()
                        : 'C',
                    style: TextStyle(
                      color: Color(0xFF06aeef),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(width: 12),

              // Contact Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDisabled
                                  ? Colors.grey[400]
                                  : (isDarkTheme ? Colors.white : Colors.black),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDisabled)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Already Member',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (contact.primaryPhone.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        contact.primaryPhone,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDisabled ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Selection checkbox
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDisabled
                        ? Colors.grey[300]!
                        : (isSelected ? Color(0xFF06aeef) : Colors.grey[400]!),
                    width: 2,
                  ),
                  color: isDisabled
                      ? Colors.grey[200]
                      : (isSelected ? Color(0xFF06aeef) : Colors.transparent),
                ),
                child: isDisabled
                    ? Icon(Icons.close, size: 12, color: Colors.grey[400])
                    : (isSelected
                        ? Icon(Icons.check, size: 12, color: Colors.white)
                        : null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDuggyUserTile(User user, bool isSelected, bool isDisabled) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isDisabled ? null : () => _toggleDuggyUserSelection(user.id),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF06aeef).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: user.profilePicture != null
                    ? ClipOval(
                        child: Image.network(
                          user.profilePicture!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  color: Color(0xFF06aeef),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: Color(0xFF06aeef),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),

              SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDisabled
                                  ? Colors.grey[400]
                                  : (isDarkTheme ? Colors.white : Colors.black),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDisabled
                                ? Colors.grey[300]
                                : Color(0xFF06aeef).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isDisabled ? 'Already Member' : 'Duggy User',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDisabled ? Colors.grey[600] : Color(0xFF06aeef),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (user.phoneNumber.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        user.phoneNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDisabled ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Selection checkbox
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDisabled
                        ? Colors.grey[300]!
                        : (isSelected ? Color(0xFF06aeef) : Colors.grey[400]!),
                    width: 2,
                  ),
                  color: isDisabled
                      ? Colors.grey[200]
                      : (isSelected ? Color(0xFF06aeef) : Colors.transparent),
                ),
                child: isDisabled
                    ? Icon(Icons.close, size: 12, color: Colors.grey[400])
                    : (isSelected
                        ? Icon(Icons.check, size: 12, color: Colors.white)
                        : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
