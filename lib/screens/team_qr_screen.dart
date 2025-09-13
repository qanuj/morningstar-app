import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/team.dart';
import '../widgets/svg_avatar.dart';

class TeamQRScreen extends StatelessWidget {
  final Team team;

  const TeamQRScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    // Generate QR data for team info
    final qrData = jsonEncode({
      'type': 'team_info',
      'id': team.id,
      'name': team.name,
      'logo': team.logo,
      'sport': team.sport,
      'isPrimary': team.isPrimary,
      'provider': team.provider,
      'providerId': team.providerId,
      'isVerified': team.isVerified,
      'city': team.city,
      'state': team.state,
      'country': team.country,
      'owners': team.owners
          .map(
            (owner) => {
              'id': owner.id,
              'name': owner.name,
              'profile_picture': owner.profilePicture,
            },
          )
          .toList(),
      if (team.club != null)
        'club': {
          'id': team.club!.id,
          'name': team.club!.name,
          'logo': team.club!.logo,
        },
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
                      color: Theme.of(context).textTheme.titleLarge?.color,
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
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // QR Code - Hero of the page
                      Container(
                        padding: const EdgeInsets.all(24),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).primaryColor,
                          errorStateBuilder: (cxt, err) {
                            return Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Error generating QR code',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Team logo and name
                      SVGAvatar(
                        imageUrl: team.logo,
                        size: 60,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.1),
                        fallbackIcon: Icons.groups,
                        iconSize: 30,
                        fallbackText: team.name,
                        fallbackTextStyle: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        team.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      if (team.club?.name != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          team.club!.name,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
