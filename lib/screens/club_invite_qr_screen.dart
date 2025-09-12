import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/club.dart';
import '../widgets/svg_avatar.dart';

class ClubInviteQRScreen extends StatelessWidget {
  final Club club;

  const ClubInviteQRScreen({
    super.key,
    required this.club,
  });

  @override
  Widget build(BuildContext context) {
    // Generate QR data for club invitation
    final qrData = jsonEncode({
      'type': 'club_invite',
      'club_id': club.id,
      'club_name': club.name,
      'logo': club.logo,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // QR Code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF003f9b),
                    errorStateBuilder: (cxt, err) {
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.red.withOpacity(0.1),
                        child: const Center(
                          child: Text(
                            'Error generating QR code',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Club logo and name
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Club logo
                    SVGAvatar(
                      imageUrl: club.logo,
                      size: 60,
                      backgroundColor: const Color(0xFF003f9b).withOpacity(0.1),
                      fallbackIcon: Icons.sports_cricket,
                      iconSize: 30,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Club name
                    Text(
                      club.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003f9b),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}