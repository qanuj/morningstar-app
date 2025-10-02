import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPickerScreen extends StatefulWidget {
  final Function(List<Contact>) onContactsSelected;

  const ContactPickerScreen({
    Key? key,
    required this.onContactsSelected,
  }) : super(key: key);

  @override
  ContactPickerScreenState createState() => ContactPickerScreenState();
}

class ContactPickerScreenState extends State<ContactPickerScreen> {
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _selectedContactIds = {};
  String _searchQuery = '';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      print('📱 Loading contacts for picker screen...');

      // Check and request permission first
      bool permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contacts permission is required to add members'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () async {
                  // Try to open app settings (this may not work on all devices)
                  await FlutterContacts.requestPermission();
                },
              ),
            ),
          );
        }
        return;
      }

      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);
      
      // Filter contacts with phone numbers and display names
      contacts = contacts.where((contact) => 
        contact.phones.isNotEmpty && 
        contact.displayName.isNotEmpty
      ).toList();

      // Sort contacts alphabetically
      contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
      
      print('📱 Loaded ${contacts.length} contacts for picker');
    } catch (e) {
      print('📱 Error loading contacts: $e');
      setState(() {
        _isLoading = false;
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

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts.where((contact) {
          final nameMatch = contact.displayName.toLowerCase().contains(query.toLowerCase());
          final phoneMatch = contact.phones.any((phone) => 
            phone.number.replaceAll(RegExp(r'[^\d]'), '').contains(query.replaceAll(RegExp(r'[^\d]'), '')));
          return nameMatch || phoneMatch;
        }).toList();
      }
    });
  }

  void _toggleContactSelection(Contact contact) {
    setState(() {
      if (_selectedContactIds.contains(contact.id)) {
        _selectedContactIds.remove(contact.id);
      } else {
        _selectedContactIds.add(contact.id);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _selectAllContacts() {
    setState(() {
      if (_selectedContactIds.length == _filteredContacts.length) {
        _selectedContactIds.clear();
      } else {
        _selectedContactIds = _filteredContacts.map((c) => c.id).toSet();
      }
    });
    HapticFeedback.mediumImpact();
  }

  List<Contact> _getSelectedContacts() {
    return _allContacts.where((contact) => _selectedContactIds.contains(contact.id)).toList();
  }

  void _confirmSelection() {
    final selectedContacts = _getSelectedContacts();
    Navigator.pop(context);
    widget.onContactsSelected(selectedContacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFF003f9b),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Contacts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_selectedContactIds.isNotEmpty)
              Text(
                '${_selectedContactIds.length} selected',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
          ],
        ),
        actions: [
          if (_filteredContacts.isNotEmpty)
            TextButton(
              onPressed: _selectAllContacts,
              child: Text(
                _selectedContactIds.length == _filteredContacts.length 
                  ? 'Deselect All' 
                  : 'Select All',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Color(0xFF003f9b),
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterContacts,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: Color(0xFF003f9b),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[600],
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[600],
                          size: 22,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterContacts('');
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Contact count and loading
          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF003f9b),
                    ),
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
              ),
            )
          else if (_filteredContacts.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty ? Icons.search_off : Icons.contacts,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty 
                        ? 'No contacts found'
                        : 'No contacts available',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Try adjusting your search terms',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else ...[
            // Contact count header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.contacts, size: 20, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    '${_filteredContacts.length} contact${_filteredContacts.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Contacts List
            Expanded(
              child: ListView.builder(
                itemCount: _filteredContacts.length,
                padding: EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  final isSelected = _selectedContactIds.contains(contact.id);

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Color(0xFF003f9b).withOpacity(0.08)
                        : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                          ? Color(0xFF003f9b).withOpacity(0.3)
                          : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _toggleContactSelection(contact),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Color(0xFF003f9b).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected 
                                      ? Color(0xFF003f9b)
                                      : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    contact.displayName.isNotEmpty
                                        ? contact.displayName[0].toUpperCase()
                                        : 'C',
                                    style: TextStyle(
                                      color: isSelected 
                                        ? Color(0xFF003f9b)
                                        : Color(0xFF003f9b).withOpacity(0.7),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              
                              SizedBox(width: 16),
                              
                              // Contact Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.displayName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (contact.phones.isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        contact.phones.first.number,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              // Selection Indicator
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                    ? Color(0xFF003f9b)
                                    : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected 
                                      ? Color(0xFF003f9b)
                                      : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected 
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
      
      // Bottom Action Bar
      bottomNavigationBar: _selectedContactIds.isNotEmpty 
        ? Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF003f9b),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Add ${_selectedContactIds.length} Member${_selectedContactIds.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          )
        : null,
    );
  }
}