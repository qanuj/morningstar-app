import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/club.dart';
import '../widgets/svg_avatar.dart';

class ClubInviteQRScreen extends StatelessWidget {
  final Club club;

  const ClubInviteQRScreen({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    // Generate QR data for club invitation
    final qrData = jsonEncode({
      'type': 'club_invite',
      'club_id': club.id,
      'club_name': club.name,
      'logo': club.logo,
      'owners': club.owners
          .map(
            (owner) => {
              'id': owner.id,
              'name': owner.name,
              'profile_picture': owner.profilePicture,
            },
          )
          .toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Close button header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Main content centered
            Expanded(
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.1),
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
                          foregroundColor: Colors.black,
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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            fallbackIcon: Icons.sports_cricket,
                            iconSize: 30,
                          ),

                          const SizedBox(height: 12),

                          // Club name
                          Text(
                            club.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
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
          ],
        ),
      ),
    );
  }
}
