import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      if (team.club != null) 'club': {
        'id': team.club!.id,
        'name': team.club!.name,
        'logo': team.club!.logo,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Professional Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF003f9b),
                    const Color(0xFF06aeef),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF003f9b).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    children: [
                      // Header with close button
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Team QR Code',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Balance the close button
                        ],
                      ),
                      
                      const SizedBox(height: 32),

                      // Team Information Header
                      Row(
                        children: [
                          // Team Avatar with glow effect
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: SVGAvatar(
                              imageUrl: team.logo,
                              size: 80,
                              backgroundColor: Colors.white,
                              fallbackIcon: Icons.groups,
                              iconSize: 40,
                              fallbackText: team.name,
                              fallbackTextStyle: const TextStyle(
                                color: Color(0xFF003f9b),
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Team Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                
                                if (team.club?.name != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    team.club!.name,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 8),
                                
                                // Team badges
                                Row(
                                  children: [
                                    if (team.isPrimary)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Primary',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    
                                    if (team.isVerified) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.verified,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Verified',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // QR Code Card with premium styling
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color: const Color(0xFF003f9b).withOpacity(0.1),
                            blurRadius: 60,
                            spreadRadius: 0,
                            offset: const Offset(0, 30),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            // QR Code with sophisticated border
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF003f9b).withOpacity(0.1),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF003f9b).withOpacity(0.05),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 240.0,
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF003f9b),
                                gapless: true,
                                errorStateBuilder: (cxt, err) {
                                  return Container(
                                    width: 240,
                                    height: 240,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.05),
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
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Team ID with copy functionality
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: team.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Team ID copied to clipboard'),
                                    backgroundColor: const Color(0xFF16a34a),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF003f9b).withOpacity(0.1),
                                      const Color(0xFF06aeef).withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF003f9b).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tag,
                                      color: const Color(0xFF003f9b),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ID: ${team.id}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF003f9b),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.copy,
                                      color: const Color(0xFF003f9b).withOpacity(0.7),
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Professional Instructions Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF06aeef).withOpacity(0.05),
                            const Color(0xFF4dd0ff).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF06aeef).withOpacity(0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Icon with glow effect
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF06aeef),
                                    const Color(0xFF4dd0ff),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF06aeef).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              'How to Use',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF003f9b),
                                letterSpacing: 0.5,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'Share this QR code with others to quickly provide team information. Anyone can scan it to view team details and access relevant information.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.5,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 16),

                            // Feature highlights
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildFeature(
                                  Icons.flash_on,
                                  'Instant',
                                  'Access',
                                ),
                                _buildFeature(
                                  Icons.security,
                                  'Secure',
                                  'Data',
                                ),
                                _buildFeature(
                                  Icons.share,
                                  'Easy',
                                  'Sharing',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF003f9b).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF003f9b),
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF003f9b),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}