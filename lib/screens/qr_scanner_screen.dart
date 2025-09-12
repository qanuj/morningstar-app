import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Theme.of(context).primaryColor,
          borderRadius: 16,
          borderLength: 50,
          borderWidth: 4,
          cutOutSize: 250.0,
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && scanData.code!.isNotEmpty) {
        controller.pauseCamera();
        _handleScannedData(scanData.code!);
      }
    });
  }

  void _handleScannedData(String data) {
    // Process the scanned QR code data
    try {
      // Try to parse as JSON first
      final jsonData = json.decode(data);
      if (jsonData is Map<String, dynamic>) {
        final type = jsonData['type'] as String?;
        
        if (type == 'club_invite') {
          _handleClubInviteJson(jsonData);
        } else if (type == 'club_info') {
          _handleClubInfoJson(jsonData);
        } else {
          _showGenericDataDialog(data);
        }
        return;
      }
    } catch (e) {
      // Not valid JSON, continue with string parsing
    }

    // String-based parsing for legacy formats
    if (data.contains('Club ID:')) {
      // This looks like a club invite
      _handleClubInvite(data);
    } else if (data.contains('duggy://') || data.contains('join-club')) {
      // This is a deep link
      _handleDeepLink(data);
    } else {
      // Generic QR code data
      _showGenericDataDialog(data);
    }
  }

  void _handleClubInvite(String inviteData) {
    // Extract club ID from the invite data
    final clubIdMatch = RegExp(r'Club ID: ([a-zA-Z0-9-]+)').firstMatch(inviteData);
    final clubNameMatch = RegExp(r'Join (.+) cricket club!').firstMatch(inviteData);
    
    if (clubIdMatch != null) {
      final clubId = clubIdMatch.group(1)!;
      final clubName = clubNameMatch?.group(1) ?? 'Unknown Club';
      
      _showClubInviteDialog(clubId, clubName);
    } else {
      _showGenericDataDialog(inviteData);
    }
  }

  void _handleDeepLink(String deepLink) {
    // Handle deep link processing
    _showGenericDataDialog('Deep link detected:\n$deepLink');
  }

  void _showClubInviteDialog(String clubId, String clubName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.groups, color: Theme.of(context).primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Club Invitation',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You\'ve been invited to join:',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clubName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Club ID: $clubId',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement club joining logic
                Navigator.of(context).pop();
                
                // Show success message or navigate to join club flow
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Club invite processed: $clubName'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Text('Join Club'),
            ),
          ],
        );
      },
    );
  }

  void _showGenericDataDialog(String data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('QR Code Scanned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _handleClubInviteJson(Map<String, dynamic> jsonData) {
    final clubId = jsonData['club_id'] as String?;
    final clubName = jsonData['club_name'] as String?;
    
    if (clubId != null) {
      _showClubInviteDialog(clubId, clubName ?? 'Unknown Club');
    } else {
      _showGenericDataDialog(jsonEncode(jsonData));
    }
  }

  void _handleClubInfoJson(Map<String, dynamic> jsonData) {
    final clubId = jsonData['id'] as String?;
    final clubName = jsonData['name'] as String?;
    final clubDescription = jsonData['description'] as String?;
    final membersCount = jsonData['membersCount'];
    final city = jsonData['city'] as String?;
    final state = jsonData['state'] as String?;
    final contactPhone = jsonData['contactPhone'] as String?;
    final isVerified = jsonData['isVerified'] as bool?;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Club Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (clubName != null) ...[
                  _buildInfoRow('Club Name', clubName),
                  SizedBox(height: 8),
                ],
                if (clubId != null) ...[
                  _buildInfoRow('Club ID', clubId),
                  SizedBox(height: 8),
                ],
                if (clubDescription != null && clubDescription.isNotEmpty) ...[
                  _buildInfoRow('Description', clubDescription),
                  SizedBox(height: 8),
                ],
                if (city != null || state != null) ...[
                  _buildInfoRow('Location', [city, state].where((e) => e != null).join(', ')),
                  SizedBox(height: 8),
                ],
                if (contactPhone != null) ...[
                  _buildInfoRow('Contact', contactPhone),
                  SizedBox(height: 8),
                ],
                if (membersCount != null) ...[
                  _buildInfoRow('Members', membersCount.toString()),
                  SizedBox(height: 8),
                ],
                if (isVerified == true) ...[
                  Row(
                    children: [
                      Icon(Icons.verified, color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text('Verified Club', 
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            if (clubId != null)
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement navigation to club details or join logic
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Club information scanned: ${clubName ?? clubId}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: Text('View Club'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}