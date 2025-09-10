import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/club.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/svg_avatar.dart';
import '../../widgets/transaction_dialog_helper.dart';
import '../transactions/bulk_transaction_screen.dart';
import '../points/bulk_points_screen.dart';
import 'club_member_manage.dart';
import 'contact_picker_screen.dart';
import 'manual_add_member_screen.dart';

class EnhancedClubMembersScreen extends StatefulWidget {
  final Club club;

  const EnhancedClubMembersScreen({super.key, required this.club});

  @override
  EnhancedClubMembersScreenState createState() =>
      EnhancedClubMembersScreenState();
}

class EnhancedClubMembersScreenState extends State<EnhancedClubMembersScreen> {
  // State variables
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<ClubMember> _members = [];
  List<ClubMember> _filteredMembers = [];

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;

  // Search and filters
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filter states
  bool _showActiveMembers = true;
  bool _showPendingMembers = false;
  bool _showBannedMembers = false;
  bool _showInactiveMembers = false;
  bool _showLowBalanceMembers = false;

  // Selection state
  Set<String> _selectedMembers = {};
  bool _isSelectionMode = false;

  // Controllers
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreMembers();
      }
    }
  }

  Future<void> _loadMembers({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _members.clear();
      _filteredMembers.clear();
    }

    setState(() => _isLoading = true);

    try {
      final newMembers = await _fetchMembersFromAPI(_currentPage, _pageSize);

      if (refresh) {
        _members = newMembers;
      } else {
        _members.addAll(newMembers);
      }

      _hasMoreData = newMembers.length == _pageSize;
      _applyFilters();
    } catch (error) {
      _showErrorSnackBar('Failed to load members. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreMembers() async {
    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      final newMembers = await _fetchMembersFromAPI(_currentPage, _pageSize);
      _members.addAll(newMembers);
      _hasMoreData = newMembers.length == _pageSize;
      _applyFilters();
    } catch (error) {
      _currentPage--; // Revert page number on error
      _showErrorSnackBar('Failed to load more members.');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<List<ClubMember>> _fetchMembersFromAPI(int page, int pageSize) async {
    try {
      // Make API call to get members for the specific club
      final response = await ApiService.get(
        '/members?clubId=${widget.club.id}&page=$page&limit=$pageSize',
      );

      // Parse the response
      final membersData = response['members'] as List<dynamic>? ?? [];
      
      print('🔍 MEMBERS API RESPONSE DEBUG:');
      print('   Total Members: ${membersData.length}');
      if (membersData.isNotEmpty) {
        print('   Sample Member Data: ${membersData.first}');
      }

      return membersData.map((memberData) {
        return ClubMember(
          id: memberData['id'] ?? '',
          userId:
              memberData['userId'] ??
              memberData['user']?['id'], // Fallback to user.id if userId is null
          name: memberData['user']?['name'] ?? 'Unknown',
          email: memberData['user']?['email'] ?? '',
          phoneNumber: memberData['user']?['phoneNumber'] ?? '',
          role: memberData['role'] ?? 'Member',
          balance: (memberData['balance'] ?? 0).toDouble(),
          points: memberData['points'] ?? 0,
          profilePicture: memberData['user']?['profilePicture'],
          joinedDate: memberData['joinedAt'] != null
              ? DateTime.parse(memberData['joinedAt'])
              : DateTime.now(),
          isActive: memberData['isActive'] ?? false,
          approved: memberData['approved'] ?? false,
          isBanned: memberData['isBanned'] ?? false,
          lastActive: memberData['lastActive'] != null
              ? DateTime.parse(memberData['lastActive'])
              : null,
        );
      }).toList();
    } catch (error) {
      debugPrint('Error fetching members: $error');

      // Return mock data as fallback for development
      if (page == 1) {
        return _generateMockMembers().take(pageSize).toList();
      }
      return [];
    }
  }

  List<ClubMember> _generateMockMembers() {
    return List.generate(50, (index) {
      final statuses = ['active', 'pending', 'banned', 'inactive'];
      final roles = ['Member', 'Captain', 'Vice Captain', 'Treasurer'];
      final status = statuses[index % statuses.length];

      return ClubMember(
        id: 'member_${index + 1}',
        userId: 'user_${index + 1}',
        name: 'Member ${index + 1}',
        email: 'member${index + 1}@example.com',
        phoneNumber: '+91 ${9876543210 - index}',
        role: roles[index % roles.length],
        balance: (1000 + (index * 50) - (index % 3 * 200)).toDouble(),
        points: 100 + (index * 25),
        profilePicture: index % 4 == 0
            ? 'https://i.pravatar.cc/150?img=${index + 1}'
            : null,
        joinedDate: DateTime.now().subtract(Duration(days: index * 10)),
        isActive: status == 'active',
        approved: status != 'pending',
        isBanned: status == 'banned',
        lastActive: DateTime.now().subtract(Duration(hours: index)),
      );
    });
  }

  void _applyFilters() {
    List<ClubMember> filtered = _members;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((member) {
        final query = _searchQuery.toLowerCase();

        // Check for balance search patterns (>1000, <500, =0)
        final balanceMatch = RegExp(
          r'^([><=])(\d+(?:\.\d{1,2})?)$',
        ).firstMatch(query);
        if (balanceMatch != null) {
          final operator = balanceMatch.group(1)!;
          final amount = double.parse(balanceMatch.group(2)!);

          switch (operator) {
            case '>':
              return member.balance > amount;
            case '<':
              return member.balance < amount;
            case '=':
              return (member.balance - amount).abs() < 0.01;
            default:
              return false;
          }
        }

        // Regular text search
        return member.name.toLowerCase().contains(query) ||
            member.email.toLowerCase().contains(query) ||
            member.phoneNumber.contains(query) ||
            member.role.toLowerCase().contains(query);
      }).toList();
    }

    // Apply status filters
    filtered = filtered.where((member) {
      if (!_showActiveMembers &&
          !_showPendingMembers &&
          !_showBannedMembers &&
          !_showInactiveMembers &&
          !_showLowBalanceMembers) {
        return false;
      }

      if (_showActiveMembers &&
          member.approved &&
          member.isActive &&
          !member.isBanned)
        return true;
      if (_showPendingMembers && !member.approved) return true;
      if (_showBannedMembers && member.isBanned) return true;
      if (_showInactiveMembers && !member.isActive && !member.isBanned)
        return true;
      if (_showLowBalanceMembers && member.balance < 0) return true;

      return false;
    }).toList();

    setState(() {
      _filteredMembers = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _onFilterChanged() {
    _applyFilters();
  }

  void _toggleMemberSelection(String memberId) {
    setState(() {
      if (_selectedMembers.contains(memberId)) {
        _selectedMembers.remove(memberId);
        if (_selectedMembers.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMembers.add(memberId);
        _isSelectionMode = true;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _selectAllMembers() {
    setState(() {
      if (_selectedMembers.length == _filteredMembers.length) {
        _selectedMembers.clear();
        _isSelectionMode = false;
      } else {
        _selectedMembers = _filteredMembers.map((m) => m.id).toSet();
        _isSelectionMode = true;
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedMembers.clear();
      _isSelectionMode = false;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _loadMembers(refresh: true),
        ),
      ),
    );
  }

  Future<void> _showAddMemberOptions() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            
            Text(
              'Add New Member',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24),
            
            // From Contacts Option
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF003f9b).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.contacts,
                  color: Color(0xFF003f9b),
                ),
              ),
              title: Text('From Contacts'),
              subtitle: Text('Select from your phone contacts'),
              onTap: () {
                Navigator.pop(context);
                _showAddMemberFromContacts();
              },
            ),
            
            SizedBox(height: 8),
            
            // Manual Entry Option
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_add,
                  color: Colors.green,
                ),
              ),
              title: Text('Enter Manually'),
              subtitle: Text('Add member details manually'),
              onTap: () {
                Navigator.pop(context);
                _showManualAddMember();
              },
            ),
            
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMemberFromContacts() async {
    try {
      // Check current permission status first
      PermissionStatus currentStatus = await Permission.contacts.status;
      
      // Try direct contact access first (iOS-specific fallback)
      if (currentStatus == PermissionStatus.denied || currentStatus == PermissionStatus.permanentlyDenied) {
        try {
          // This will trigger iOS permission dialog if not permanently denied
          await FlutterContacts.getContacts(withProperties: false);
          // If we get here, permission was granted
          _showContactPicker();
          return;
        } catch (e) {
          // Continue with permission_handler flow
        }
      }
      
      // Request contacts permission using permission_handler
      PermissionStatus permissionStatus = await Permission.contacts.request();
      
      if (permissionStatus == PermissionStatus.granted) {
        // Permission granted, show contact picker
        _showContactPicker();
      } else if (permissionStatus == PermissionStatus.denied) {
        // Permission denied, fallback to manual entry
        _showPermissionDeniedWithFallback();
      } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
        // Permission permanently denied, show settings dialog with manual option
        _showPermissionPermanentlyDeniedWithFallback();
      } else {
        _showErrorSnackBar('Unknown permission status: $permissionStatus');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to request contacts permission: $e');
    }
  }

  void _showPermissionDeniedWithFallback() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contacts Permission'),
        content: Text(
          'To add members from your contacts, we need access to your contacts. You can try again or add members manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualAddMember();
            },
            child: Text('Add Manually'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _showAddMemberFromContacts();
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedWithFallback() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📱 Contacts Permission Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To add members from your contacts, you need to grant contacts permission.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'iOS Steps:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '1. Tap "Open Settings" below\n'
              '2. Find "Duggy" in the app list\n'
              '3. Toggle "Contacts" to ON\n'
              '4. Return to the app and try again',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 16),
            Text(
              'Or you can add members manually without contacts access.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualAddMember();
            },
            child: Text('Add Manually'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF003f9b),
              foregroundColor: Colors.white,
            ),
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showContactPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactPickerScreen(
          onContactsSelected: _addMembersFromContacts,
        ),
      ),
    );
  }

  void _showManualAddMember() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualAddMemberScreen(
          onMemberAdded: _addMemberManually,
        ),
      ),
    );
  }

  Future<void> _addMemberManually(String name, String phoneNumber) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF003f9b)),
                SizedBox(height: 16),
                Text('Adding member...'),
              ],
            ),
          ),
        ),
      );

      // Clean phone number
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      final memberData = {
        'name': name,
        'phoneNumber': cleanPhone,
        'clubId': widget.club.id,
      };
      
      await ApiService.post('/members', memberData);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added $name to the club!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the members list
        _loadMembers(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showErrorSnackBar('Failed to add member: $e');
      }
    }
  }


  Future<void> _addMembersFromContacts(List<Contact> selectedContacts) async {
    if (selectedContacts.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${selectedContacts.length} Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add the following contacts as club members:'),
            SizedBox(height: 12),
            ...selectedContacts.take(5).map((contact) => Text(
              '• ${contact.displayName}',
              style: TextStyle(fontSize: 14),
            )),
            if (selectedContacts.length > 5)
              Text('... and ${selectedContacts.length - 5} more'),
            SizedBox(height: 12),
            Text(
              'All members will be added with "Member" role.',
              style: TextStyle(
                fontSize: 12, 
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF003f9b),
              foregroundColor: Colors.white,
            ),
            child: Text('Add Members'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF003f9b)),
            SizedBox(height: 16),
            Text('Adding ${selectedContacts.length} members...'),
          ],
        ),
      ),
    );

    try {
      // For multiple members, make individual API calls as per the requirement
      List<Map<String, dynamic>> results = [];
      List<String> errors = [];
      
      for (final contact in selectedContacts) {
        try {
          final memberData = {
            'name': contact.displayName,
            'phoneNumber': contact.phones.first.number.replaceAll(RegExp(r'[^\d+]'), ''), // Clean phone number
            'clubId': widget.club.id,
          };
          
          final response = await ApiService.post('/members', memberData);
          results.add(response);
        } catch (e) {
          errors.add('Failed to add ${contact.displayName}: $e');
        }
      }
      
      // Create a response structure
      final response = {
        'success': true,
        'added': results,
        'errors': errors,
      };

      Navigator.pop(context); // Close progress dialog

      if (response['success'] == true) {
        final addedCount = results.length;
        
        if (errors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added $addedCount members. ${errors.length} failed to add.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully added $addedCount members!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Refresh the members list
        _loadMembers(refresh: true);
      } else {
        throw Exception('Failed to add members');
      }
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      _showErrorSnackBar('Failed to add members: $e');
    }
  }

  void _showSearchAndFilterDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Search & Filter',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003f9b),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search section
                      Text(
                        'Search Members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone number...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                      SizedBox(height: 24),

                      // Filter section
                      Text(
                        'Filter Members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Status filters
                      Text(
                        'Member Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: Text('Active Members'),
                            selected: _showActiveMembers,
                            onSelected: (selected) {
                              setState(() {
                                _showActiveMembers = selected;
                              });
                              _onFilterChanged();
                            },
                          ),
                          FilterChip(
                            label: Text('Pending Approval'),
                            selected: _showPendingMembers,
                            onSelected: (selected) {
                              setState(() {
                                _showPendingMembers = selected;
                              });
                              _onFilterChanged();
                            },
                          ),
                          FilterChip(
                            label: Text('Banned Members'),
                            selected: _showBannedMembers,
                            onSelected: (selected) {
                              setState(() {
                                _showBannedMembers = selected;
                              });
                              _onFilterChanged();
                            },
                          ),
                          FilterChip(
                            label: Text('Inactive Members'),
                            selected: _showInactiveMembers,
                            onSelected: (selected) {
                              setState(() {
                                _showInactiveMembers = selected;
                              });
                              _onFilterChanged();
                            },
                          ),
                          FilterChip(
                            label: Text('Low Balance'),
                            selected: _showLowBalanceMembers,
                            onSelected: (selected) {
                              setState(() {
                                _showLowBalanceMembers = selected;
                              });
                              _onFilterChanged();
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Quick actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showActiveMembers = true;
                                  _showPendingMembers = false;
                                  _showBannedMembers = false;
                                  _showInactiveMembers = false;
                                  _showLowBalanceMembers = false;
                                });
                                _onSearchChanged('');
                                _onFilterChanged();
                              },
                              child: Text('Clear All'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF003f9b),
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            
            Text(
              'Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24),
            
            // Add Member Option
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF003f9b).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_add,
                  color: Color(0xFF003f9b),
                ),
              ),
              title: Text('Add Member'),
              subtitle: Text('Add new member to club'),
              onTap: () {
                Navigator.pop(context);
                _showAddMemberOptions();
              },
            ),
            
            // Search Option
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.search,
                  color: Colors.blue,
                ),
              ),
              title: Text('Search Members'),
              subtitle: Text('Search by name or phone'),
              onTap: () {
                Navigator.pop(context);
                _showSearchDialog();
              },
            ),
            
            // Filter Option
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.filter_list,
                  color: Colors.orange,
                ),
              ),
              title: Text('Filter Members'),
              subtitle: Text('Filter by status or balance'),
              onTap: () {
                Navigator.pop(context);
                _showFilterDialog();
              },
            ),
            
            if (_selectedMembers.isNotEmpty) ...[
              Divider(),
              
              // Bulk Actions for selected members
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.group,
                    color: Colors.purple,
                  ),
                ),
                title: Text('Bulk Actions'),
                subtitle: Text('${_selectedMembers.length} member${_selectedMembers.length != 1 ? 's' : ''} selected'),
                onTap: () {
                  Navigator.pop(context);
                  _showBulkActionsBottomSheet();
                },
              ),
            ],
            
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showBulkActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BulkActionsBottomSheet(
        selectedCount: _selectedMembers.length,
        onAddExpense: _handleBulkExpense,
        onAddFunds: _handleBulkFunds,
        onAddPoints: _handleBulkPoints,
        onRemovePoints: _handleBulkRemovePoints,
      ),
    );
  }

  void _handleBulkExpense() {
    Navigator.pop(context);
    _showBulkTransactionScreen();
  }

  void _handleBulkFunds() {
    Navigator.pop(context);
    _showBulkTransactionScreen();
  }

  void _handleBulkPoints() {
    Navigator.pop(context);
    _showBulkPointsScreen();
  }

  void _handleBulkRemovePoints() {
    Navigator.pop(context);
    _showBulkPointsScreen();
  }

  void _showBulkTransactionScreen() {
    final selectedMembersList = _getSelectedMembers();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkTransactionScreen(
          selectedMembers: selectedMembersList,
          onSubmit: _handleBulkTransactionSubmit,
        ),
      ),
    );
  }

  Future<void> _handleBulkTransactionSubmit(
    Map<String, dynamic> data,
    String type,
  ) async {
    await _handleTransactionSubmit(data, type, true);
  }

  void _showBulkPointsScreen() {
    final selectedMembersList = _getSelectedMembers();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkPointsScreen(
          selectedMembers: selectedMembersList,
          onSubmit: _handleBulkPointsSubmit,
        ),
      ),
    );
  }

  Future<void> _handleBulkPointsSubmit(
    Map<String, dynamic> data,
    String action,
  ) async {
    await _handlePointsSubmit(data, action, true);
  }

  void _showTransactionDialog(String type, String title, bool isBulk) {
    final selectedUsers = isBulk ? _getSelectedMembers().map((member) => 
        User(
          id: member.id,
          phoneNumber: member.phoneNumber,
          name: member.name,
          email: member.email,
          profilePicture: member.profilePicture,
          role: member.role,
          isProfileComplete: true,
          createdAt: member.joinedDate,
          userId: member.userId,
        )
    ).toList() : <User>[];

    if (isBulk) {
      TransactionDialogHelper.showBulkTransactionDialog(
        context: context,
        type: type,
        title: title,
        selectedMembers: selectedUsers,
        onSubmit: (data) => _handleTransactionSubmit(data, type, isBulk),
      );
    } else {
      TransactionDialogHelper.showTransactionDialog(
        context: context,
        type: type,
        title: title,
        isBulk: false,
        selectedMembers: selectedUsers,
        onSubmit: (data) => _handleTransactionSubmit(data, type, isBulk),
      );
    }
  }

  void _showPointsDialog(String type, bool isBulk) {
    showDialog(
      context: context,
      builder: (context) => _PointsDialog(
        type: type,
        isBulk: isBulk,
        selectedMembers: isBulk ? _getSelectedMembers() : [],
        onSubmit: (data) => _handlePointsSubmit(data, type, isBulk),
      ),
    );
  }

  void _navigateToMemberManage(ClubMember member) async {
    // Convert ClubMember to User for the management screen
    final user = User(
      id: member.id,
      userId: member.userId, // Pass the actual user ID
      phoneNumber: member.phoneNumber,
      name: member.name,
      email: member.email,
      profilePicture: member.profilePicture,
      role: member.role.toUpperCase(),
      isProfileComplete: true,
      createdAt: member.joinedDate,
      balance: member.balance,
      lastActive: member.lastActive,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ClubMemberManageScreen(club: widget.club, member: user),
      ),
    );

    // Refresh the members list if changes were made
    if (result == true) {
      _loadMembers(refresh: true);
    }
  }

  List<ClubMember> _getSelectedMembers() {
    return _filteredMembers
        .where((member) => _selectedMembers.contains(member.id))
        .toList();
  }

  Future<void> _handleTransactionSubmit(
    Map<String, dynamic> data,
    String type,
    bool isBulk,
  ) async {
    try {
      if (isBulk) {
        // Bulk transaction API call - matches web app implementation
        final selectedMembersList = _getSelectedMembers();
        // The server expects userIds - use the userId field from ClubMember model
        final userIds = selectedMembersList.map((member) => member.userId ?? member.id).toList();

        print('🔵 BULK TRANSACTION DEBUG:');
        print('   Selected Members: ${selectedMembersList.length}');
        print('   Member IDs: ${selectedMembersList.map((m) => m.id).toList()}');
        print('   User IDs: $userIds');
        print('   Type: $type');
        print('   Amount: ${data['amount']}');
        print('   Purpose: ${data['purpose']}');
        print('   Description: ${data['description']}');
        print('   Club ID: ${widget.club.id}');
        print('   Payment Method: ${data['paymentMethod']}');

        final requestPayload = {
          'userIds': userIds,
          'amount': double.parse(data['amount']),
          'type': type,
          'purpose': data['purpose'],
          'description': data['description'],
          'clubId': widget.club.id,
          'paymentMethod': type == 'CREDIT'
              ? data['paymentMethod']
              : null, // No payment method for expenses
        };

        print('🔵 Full Request Payload: $requestPayload');

        final response = await ApiService.post('/transactions/bulk', requestPayload);
        
        print('🔵 BULK TRANSACTION RESPONSE: $response');

        if (!mounted) return;

        // Handle partial failures like web app
        if (response['errors'] != null && response['errors'].length > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Some transactions failed: ${response['errors'].length} out of ${response['total'] ?? _selectedMembers.length}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          final action = type == 'CREDIT'
              ? 'added funds for'
              : 'recorded bulk expense for';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully $action ${_selectedMembers.length} members',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        _exitSelectionMode();
      } else {
        // Individual transaction for a specific member
        if (_selectedMembers.isNotEmpty) {
          final memberId = _selectedMembers.first;
          final member = _filteredMembers.firstWhere((m) => m.id == memberId);

          await ApiService.post('/transactions?clubId=${widget.club.id}', {
            'userId': member.id,
            'amount': double.parse(data['amount']),
            'type': type,
            'purpose': data['purpose'],
            'description': data['description'],
            'clubId': widget.club.id,
            'paymentMethod': type == 'CREDIT' ? data['paymentMethod'] : null,
          });

          if (!mounted) return;

          final action = type == 'CREDIT'
              ? 'added funds for'
              : 'recorded expense for';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully $action ${member.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Refresh data
      _loadMembers(refresh: true);
    } catch (error) {
      print('❌ BULK TRANSACTION ERROR: $error');
      print('❌ Error Type: ${error.runtimeType}');
      if (error is ApiException) {
        print('❌ API Error Message: ${error.message}');
        print('❌ Raw Response: ${error.rawResponse}');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process transaction: $error'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handlePointsSubmit(
    Map<String, dynamic> data,
    String type,
    bool isBulk,
  ) async {
    try {
      if (isBulk) {
        // Bulk points API calls - matches web app implementation
        final selectedMembersList = _getSelectedMembers();

        // Create individual point entries for each selected member like web app
        final pointEntries = selectedMembersList
            .map(
              (member) => ApiService.post('/points', {
                'userId': member.userId ?? member.id,
                'points': int.parse(data['points']),
                'type': type == 'add' ? 'EARNED' : 'DEDUCTED',
                'category': data['category'],
                'description': data['description'],
                'clubId': widget.club.id,
              }),
            )
            .toList();

        // Execute all point entries in parallel
        await Future.wait(pointEntries);

        if (!mounted) return;

        final action = type == 'add' ? 'added' : 'deducted';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully $action points for ${_selectedMembers.length} members',
            ),
            backgroundColor: Colors.green,
          ),
        );

        _exitSelectionMode();
      } else {
        // Individual points for a specific member
        if (_selectedMembers.isNotEmpty) {
          final memberId = _selectedMembers.first;
          final member = _filteredMembers.firstWhere((m) => m.id == memberId);

          await ApiService.post('/points', {
            'userId': member.userId ?? member.id,
            'points': int.parse(data['points']),
            'type': type == 'add' ? 'EARNED' : 'DEDUCTED',
            'category': data['category'],
            'description': data['description'],
            'clubId': widget.club.id,
          });

          if (!mounted) return;

          final action = type == 'add' ? 'added' : 'deducted';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully $action ${data['points']} points for ${member.name}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Refresh data
      _loadMembers(refresh: true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process points: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isSelectionMode
          ? AppBar(
              title: Text('${_selectedMembers.length} selected'),
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.select_all),
                  onPressed: _selectAllMembers,
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: Icon(Icons.more_vert),
                  onPressed: _showBulkActionsBottomSheet,
                  tooltip: 'Bulk Actions',
                ),
              ],
              backgroundColor: Color(0xFF003f9b), // Brand blue
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : AppBar(
              backgroundColor: const Color(0xFF003f9b),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Row(
                children: [
                  // Club Logo
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child:
                          widget.club.logo != null &&
                              widget.club.logo!.isNotEmpty
                          ? _buildClubLogo()
                          : _buildDefaultClubLogo(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Club Name and Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.club.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Members',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search, color: Colors.white),
                  onPressed: _showSearchAndFilterDrawer,
                  tooltip: 'Search & Filter',
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onPressed: _showMoreActionsBottomSheet,
                  tooltip: 'More Actions',
                ),
              ],
            ),
      body: Column(
        children: [
          // Active filters display
          if (_getActiveFiltersCount() > 0) _buildActiveFiltersChips(),

          // Members list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadMembers(refresh: true),
              color: Color(0xFF003f9b), // Brand blue refresh indicator
              backgroundColor: Colors.white,
              child: _filteredMembers.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : _buildMembersList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active filters:',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              if (_showPendingMembers)
                _buildFilterChip(
                  'Pending',
                  () => setState(() => _showPendingMembers = false),
                ),
              if (_showBannedMembers)
                _buildFilterChip(
                  'Banned',
                  () => setState(() => _showBannedMembers = false),
                ),
              if (_showInactiveMembers)
                _buildFilterChip(
                  'Inactive',
                  () => setState(() => _showInactiveMembers = false),
                ),
              if (_showLowBalanceMembers)
                _buildFilterChip(
                  'Low Balance',
                  () => setState(() => _showLowBalanceMembers = false),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: Icon(Icons.close, size: 16),
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      labelStyle: TextStyle(color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh on empty state
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.people_outline,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No members found'
                      : 'No members yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Try adjusting your search terms or filters'
                      : 'Club members will appear here once they join',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersList() {
    // Show initial loading state if no members are loaded yet
    if (_isLoading && _members.isEmpty) {
      return ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        physics:
            const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh on loading state
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF003f9b), // Brand blue
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading members...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      physics:
          const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh even with few items
      itemCount: _filteredMembers.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredMembers.length) {
          return _buildLoadingMoreIndicator();
        }

        final member = _filteredMembers[index];
        return _buildMemberCard(member);
      },
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildMemberCard(ClubMember member) {
    final isSelected = _selectedMembers.contains(member.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _isSelectionMode
            ? _toggleMemberSelection(member.id)
            : _navigateToMemberManage(member),
        onLongPress: () => _toggleMemberSelection(member.id),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : null,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Member Profile Image with overlaid checkbox
              Stack(
                children: [
                  member.profilePicture == null ||
                          member.profilePicture!.isEmpty
                      ? SVGAvatar(
                          size: 50,
                          backgroundColor: _getMemberAvatarColor(member.name),
                          iconColor: Colors.white,
                          fallbackIcon: Icons.person,
                          child: Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : 'M',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : SVGAvatar.medium(
                          imageUrl: member.profilePicture,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          fallbackIcon: Icons.person,
                        ),
                  // Status indicator
                  _buildStatusIndicator(member),
                ],
              ),

              SizedBox(width: 12),

              // Member Info (Expanded)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Member Name
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        height: 1.2,
                      ),
                    ),

                    SizedBox(height: 4),

                    // Member Details Row
                    Row(
                      children: [
                        // Role Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(member.role).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            member.role,
                            style: TextStyle(
                              color: _getRoleColor(member.role),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Status Badge
                        if (!member.approved || member.isBanned) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(member).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getStatusText(member),
                              style: TextStyle(
                                color: _getStatusColor(member),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],

                        // Phone number
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            member.phoneNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4),

                    // Email and joined date
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                          ),
                        ),
                        Text(
                          _formatJoinedDate(member.joinedDate),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: 12),

              // Balance & Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${member.balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: member.balance >= 0
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.amber),
                      SizedBox(width: 2),
                      Text(
                        '${member.points}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),

                ],
              ),

              // Navigation arrow (only show when not in selection mode)
              if (!_isSelectionMode) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ClubMember member) {
    Color indicatorColor;
    if (member.isBanned) {
      indicatorColor = Colors.red;
    } else if (!member.approved) {
      indicatorColor = Colors.orange;
    } else if (member.isActive) {
      indicatorColor = Colors.green;
    } else {
      indicatorColor = Colors.grey;
    }

    return Positioned(
      right: 2,
      bottom: 2,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: indicatorColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 2,
          ),
        ),
      ),
    );
  }


  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'captain':
        return Colors.blue;
      case 'vice captain':
        return Colors.indigo;
      case 'treasurer':
        return Colors.green;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Color _getStatusColor(ClubMember member) {
    if (member.isBanned) return Colors.red;
    if (!member.approved) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(ClubMember member) {
    if (member.isBanned) return 'Banned';
    if (!member.approved) return 'Pending';
    return 'Active';
  }

  Color _getMemberAvatarColor(String name) {
    final colors = [
      Colors.blue[600]!,
      Colors.green[600]!,
      Colors.orange[600]!,
      Colors.purple[600]!,
      Colors.red[600]!,
      Colors.teal[600]!,
      Colors.pink[600]!,
      Colors.indigo[600]!,
      Colors.amber[600]!,
      Colors.deepOrange[600]!,
    ];

    final colorIndex = name.hashCode.abs() % colors.length;
    return colors[colorIndex];
  }

  String _formatJoinedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference < 7) {
      return '${difference}d ago';
    } else if (difference < 30) {
      return '${(difference / 7).round()}w ago';
    } else if (difference < 365) {
      return '${(difference / 30).round()}m ago';
    } else {
      return '${(difference / 365).round()}y ago';
    }
  }

  int _getActiveFiltersCount() {
    return [
      _showPendingMembers,
      _showBannedMembers,
      _showInactiveMembers,
      _showLowBalanceMembers,
    ].where((filter) => filter).length;
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Members'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Name, email, phone, or balance (>1000, <500, =0)...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _onSearchChanged,
          onSubmitted: (value) => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
              Navigator.pop(context);
            },
            child: Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Members'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: Text('Active Members'),
                value: _showActiveMembers,
                onChanged: (value) =>
                    setDialogState(() => _showActiveMembers = value ?? false),
              ),
              CheckboxListTile(
                title: Text('Pending Approval'),
                value: _showPendingMembers,
                onChanged: (value) =>
                    setDialogState(() => _showPendingMembers = value ?? false),
              ),
              CheckboxListTile(
                title: Text('Banned Members'),
                value: _showBannedMembers,
                onChanged: (value) =>
                    setDialogState(() => _showBannedMembers = value ?? false),
              ),
              CheckboxListTile(
                title: Text('Inactive Members'),
                value: _showInactiveMembers,
                onChanged: (value) =>
                    setDialogState(() => _showInactiveMembers = value ?? false),
              ),
              CheckboxListTile(
                title: Text('Low Balance (<0)'),
                value: _showLowBalanceMembers,
                onChanged: (value) => setDialogState(
                  () => _showLowBalanceMembers = value ?? false,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _showActiveMembers = true;
                _showPendingMembers = false;
                _showBannedMembers = false;
                _showInactiveMembers = false;
                _showLowBalanceMembers = false;
              });
              _onFilterChanged();
              Navigator.pop(context);
            },
            child: Text('Reset'),
          ),
          TextButton(
            onPressed: () {
              _onFilterChanged();
              Navigator.pop(context);
            },
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildClubLogo() {
    // Check if the URL is an SVG
    if (widget.club.logo!.toLowerCase().contains('.svg') ||
        widget.club.logo!.toLowerCase().contains('svg?')) {
      return SvgPicture.network(
        widget.club.logo!,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildDefaultClubLogo(),
      );
    } else {
      // Regular image (PNG, JPG, etc.)
      return Image.network(
        widget.club.logo!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultClubLogo();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildDefaultClubLogo();
        },
      );
    }
  }

  Widget _buildDefaultClubLogo() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.club.name.isNotEmpty
              ? widget.club.name.substring(0, 1).toUpperCase()
              : 'C',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// Enhanced ClubMember model with additional fields
class ClubMember {
  final String id;
  final String? userId;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  final double balance;
  final int points;
  final String? profilePicture;
  final DateTime joinedDate;
  final bool isActive;
  final bool approved;
  final bool isBanned;
  final DateTime? lastActive;

  ClubMember({
    required this.id,
    this.userId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.balance,
    required this.points,
    this.profilePicture,
    required this.joinedDate,
    required this.isActive,
    required this.approved,
    required this.isBanned,
    this.lastActive,
  });
}

// Native Bulk Actions Bottom Sheet
class _BulkActionsBottomSheet extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onAddExpense;
  final VoidCallback onAddFunds;
  final VoidCallback onAddPoints;
  final VoidCallback onRemovePoints;

  const _BulkActionsBottomSheet({
    required this.selectedCount,
    required this.onAddExpense,
    required this.onAddFunds,
    required this.onAddPoints,
    required this.onRemovePoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 32,
            height: 4,
            margin: EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$selectedCount members selected',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Action items
          Column(
            children: [
              _buildActionTile(
                context,
                icon: Icons.add_circle,
                iconColor: Colors.green[600]!,
                title: 'Add Funds',
                subtitle: 'Credit money to selected members',
                onTap: onAddFunds,
              ),
              _buildActionTile(
                context,
                icon: Icons.remove_circle,
                iconColor: Colors.red[600]!,
                title: 'Add Expense',
                subtitle: 'Record expenses for selected members',
                onTap: onAddExpense,
              ),
              _buildActionTile(
                context,
                icon: Icons.star_border,
                iconColor: Colors.amber[600]!,
                title: 'Award Points',
                subtitle: 'Add points to selected members',
                onTap: onAddPoints,
              ),
              _buildActionTile(
                context,
                icon: Icons.star_outline,
                iconColor: Colors.orange[600]!,
                title: 'Deduct Points',
                subtitle: 'Remove points from selected members',
                onTap: onRemovePoints,
                isLast: true,
              ),
            ],
          ),

          // Safe area bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// Transaction Dialog
class _TransactionDialog extends StatefulWidget {
  final String type;
  final String title;
  final bool isBulk;
  final List<ClubMember> selectedMembers;
  final Function(Map<String, dynamic>) onSubmit;

  const _TransactionDialog({
    required this.type,
    required this.title,
    required this.isBulk,
    required this.selectedMembers,
    required this.onSubmit,
  });

  @override
  _TransactionDialogState createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _purpose = 'OTHER';
  String _paymentMethod = 'CASH';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isBulk)
              Text(
                'Selected: ${widget.selectedMembers.length} members',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Amount is required';
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) return 'Enter valid amount';
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Description is required';
                return null;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _purpose,
              decoration: InputDecoration(
                labelText: 'Purpose',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'MATCH_FEE', child: Text('Match Fee')),
                DropdownMenuItem(
                  value: 'MEMBERSHIP',
                  child: Text('Membership'),
                ),
                DropdownMenuItem(
                  value: 'JERSEY_ORDER',
                  child: Text('Jersey Order'),
                ),
                DropdownMenuItem(
                  value: 'GEAR_PURCHASE',
                  child: Text('Gear Purchase'),
                ),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _purpose = value!),
            ),
            if (widget.type == 'CREDIT') ...[
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(
                    value: 'BANK_TRANSFER',
                    child: Text('Bank Transfer'),
                  ),
                ],
                onChanged: (value) => setState(() => _paymentMethod = value!),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSubmit({
                'amount': _amountController.text,
                'description': _descriptionController.text,
                'purpose': _purpose,
                'paymentMethod': _paymentMethod,
              });
              Navigator.pop(context);
            }
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}

// Points Dialog
class _PointsDialog extends StatefulWidget {
  final String type;
  final bool isBulk;
  final List<ClubMember> selectedMembers;
  final Function(Map<String, dynamic>) onSubmit;

  const _PointsDialog({
    required this.type,
    required this.isBulk,
    required this.selectedMembers,
    required this.onSubmit,
  });

  @override
  _PointsDialogState createState() => _PointsDialogState();
}


class _PointsDialogState extends State<_PointsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pointsController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'PERFORMANCE';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.type == 'add' ? 'Add' : 'Remove'} Points'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isBulk)
              Text(
                'Selected: ${widget.selectedMembers.length} members',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            SizedBox(height: 16),
            TextFormField(
              controller: _pointsController,
              decoration: InputDecoration(
                labelText: 'Points',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.star),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Points are required';
                final points = int.tryParse(value);
                if (points == null || points <= 0) return 'Enter valid points';
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Description is required';
                return null;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'PERFORMANCE',
                  child: Text('Performance'),
                ),
                DropdownMenuItem(
                  value: 'ATTENDANCE',
                  child: Text('Attendance'),
                ),
                DropdownMenuItem(value: 'BONUS', child: Text('Bonus')),
                DropdownMenuItem(value: 'PENALTY', child: Text('Penalty')),
              ],
              onChanged: (value) => setState(() => _category = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSubmit({
                'points': _pointsController.text,
                'description': _descriptionController.text,
                'category': _category,
              });
              Navigator.pop(context);
            }
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
