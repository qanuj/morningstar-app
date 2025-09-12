import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/club.dart';

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
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 240.0,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF003f9b),
                        errorStateBuilder: (cxt, err) {
                          return Container(
                            width: 240,
                            height: 240,
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
                    
                    const SizedBox(height: 32),
                    
                    // Club logo and name
                    Column(
                      children: [
                        // Club logo
                        if (club.logo != null && club.logo!.isNotEmpty)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[100],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: club.logo!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.sports_cricket,
                                    size: 40,
                                    color: Color(0xFF003f9b),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.sports_cricket,
                                    size: 40,
                                    color: Color(0xFF003f9b),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF003f9b).withOpacity(0.1),
                            ),
                            child: const Icon(
                              Icons.sports_cricket,
                              size: 40,
                              color: Color(0xFF003f9b),
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // Club name
                        Text(
                          club.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003f9b),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Invite text
                        Text(
                          'Scan to join our cricket club',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}