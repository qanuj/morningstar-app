import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../models/club.dart';

class ClubQRScanner extends StatefulWidget {
  const ClubQRScanner({super.key});

  @override
  State<ClubQRScanner> createState() => _ClubQRScannerState();
}

class _ClubQRScannerState extends State<ClubQRScanner> {
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
          'Scan Club QR Code',
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
    try {
      // Try to parse as JSON first
      final jsonData = json.decode(data);
      if (jsonData is Map<String, dynamic>) {
        final type = jsonData['type'] as String?;
        
        if (type == 'club_invite') {
          _handleClubInvite(jsonData);
        } else if (type == 'club_info') {
          _handleClubInfo(jsonData);
        } else {
          _showErrorDialog('QR code does not contain valid club information');
        }
        return;
      }
    } catch (e) {
      // Not valid JSON, try legacy text format
    }

    // Legacy text format parsing
    if (data.contains('Club ID:')) {
      _handleLegacyClubInvite(data);
    } else {
      _showErrorDialog('QR code does not contain club information');
    }
  }

  void _handleClubInvite(Map<String, dynamic> jsonData) {
    final clubId = jsonData['club_id'] as String?;
    final clubName = jsonData['club_name'] as String?;
    
    if (clubId != null && clubName != null) {
      // Create a minimal Club object for selection
      final club = Club(
        id: clubId,
        name: clubName,
        isVerified: false,
        membershipFee: 0.0,
        membershipFeeCurrency: 'INR',
        upiIdCurrency: 'INR',
        owners: [],
      );
      
      Navigator.of(context).pop(club);
    } else {
      _showErrorDialog('Invalid club invitation data');
    }
  }

  void _handleClubInfo(Map<String, dynamic> jsonData) {
    final clubId = jsonData['id'] as String?;
    final clubName = jsonData['name'] as String?;
    final clubDescription = jsonData['description'] as String?;
    final clubCity = jsonData['city'] as String?;
    final clubState = jsonData['state'] as String?;
    final clubCountry = jsonData['country'] as String?;
    final clubLogo = jsonData['logo'] as String?;
    final isVerified = jsonData['isVerified'] as bool? ?? false;
    final contactPhone = jsonData['contactPhone'] as String?;
    final contactEmail = jsonData['contactEmail'] as String?;
    
    if (clubId != null && clubName != null) {
      // Create a Club object with available data
      final club = Club(
        id: clubId,
        name: clubName,
        description: clubDescription,
        city: clubCity,
        state: clubState,
        country: clubCountry,
        logo: clubLogo,
        isVerified: isVerified,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        membershipFee: 0.0,
        membershipFeeCurrency: 'INR',
        upiIdCurrency: 'INR',
        owners: [],
      );
      
      Navigator.of(context).pop(club);
    } else {
      _showErrorDialog('Invalid club information data');
    }
  }

  void _handleLegacyClubInvite(String inviteData) {
    final clubIdMatch = RegExp(r'Club ID: ([a-zA-Z0-9-]+)').firstMatch(inviteData);
    final clubNameMatch = RegExp(r'Join (.+) cricket club!').firstMatch(inviteData);
    
    if (clubIdMatch != null && clubNameMatch != null) {
      final clubId = clubIdMatch.group(1)!;
      final clubName = clubNameMatch.group(1)!;
      
      // Create a minimal Club object for selection
      final club = Club(
        id: clubId,
        name: clubName,
        isVerified: false,
        membershipFee: 0.0,
        membershipFeeCurrency: 'INR',
        upiIdCurrency: 'INR',
        owners: [],
      );
      
      Navigator.of(context).pop(club);
    } else {
      _showErrorDialog('Could not parse club invitation');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Scan Error',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to scanner
              },
              child: Text('Try Again'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close scanner
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}