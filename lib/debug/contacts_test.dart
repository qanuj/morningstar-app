import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactsTestScreen extends StatefulWidget {
  const ContactsTestScreen({Key? key}) : super(key: key);
  
  @override
  _ContactsTestScreenState createState() => _ContactsTestScreenState();
}

class _ContactsTestScreenState extends State<ContactsTestScreen> {
  List<Contact> _contacts = [];
  String _status = 'Tap the button to test contacts access';
  bool _isLoading = false;

  Future<void> _testContactAccess() async {
    setState(() {
      _isLoading = true;
      _status = 'Requesting contacts permission...';
    });

    try {
      // Request contacts permission
      PermissionStatus permissionStatus = await Permission.contacts.request();
      
      setState(() {
        _status = 'Permission status: ${permissionStatus.toString()}';
      });
      
      if (permissionStatus == PermissionStatus.granted) {
        setState(() {
          _status = 'Permission granted. Loading contacts...';
        });
        
        // Fetch contacts
        List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);
        
        setState(() {
          _status = 'Found ${contacts.length} total contacts';
        });
        
        // Filter contacts with phone numbers
        contacts = contacts.where((contact) => 
          contact.phones.isNotEmpty && 
          contact.displayName.isNotEmpty
        ).toList();

        setState(() {
          _contacts = contacts;
          _status = 'Found ${contacts.length} contacts with phone numbers';
        });
        
      } else if (permissionStatus == PermissionStatus.denied) {
        setState(() {
          _status = 'Permission denied. Please grant contacts permission.';
        });
      } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
        setState(() {
          _status = 'Permission permanently denied. Please enable in Settings.';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      print('Contacts error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contacts Test'),
        backgroundColor: Color(0xFF003f9b),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Contact Access Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _status,
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testContactAccess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF003f9b),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text('Test Contacts Access'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            if (_contacts.isNotEmpty) ...[
              Text(
                'Contacts (${_contacts.length}):',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFF003f9b),
                          child: Text(
                            contact.displayName.isNotEmpty 
                              ? contact.displayName[0].toUpperCase()
                              : 'C',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(contact.displayName),
                        subtitle: contact.phones.isNotEmpty 
                          ? Text(contact.phones.first.number)
                          : Text('No phone number'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}