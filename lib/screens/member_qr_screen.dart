import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../widgets/svg_avatar.dart';

class MemberQRScreen extends StatelessWidget {
  final User user;

  const MemberQRScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Generate QR data for member profile
    final qrData = jsonEncode({
      'type': 'member_profile',
      'user_id': user.id,
      'name': user.name,
      'phone_number': user.phoneNumber,
      'email': user.email,
      'profile_picture': user.profilePicture,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Scaffold(
      backgroundColor: Colors.white,
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
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF003f9b),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _copyToClipboard(context, user.id),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 18, color: Color(0xFF003f9b)),
                        SizedBox(width: 4),
                        Text(
                          'Copy ID',
                          style: TextStyle(color: Color(0xFF003f9b)),
                        ),
                      ],
                    ),
                  ),
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

                      // Member profile and name
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Member avatar
                          SVGAvatar(
                            imageUrl: user.profilePicture,
                            size: 60,
                            backgroundColor: const Color(0xFF003f9b),
                            child: user.profilePicture == null
                                ? Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),

                          const SizedBox(height: 12),

                          // Member name
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF003f9b),
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 4),

                          // Member phone
                          Text(
                            user.phoneNumber,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6c757d),
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

  void _copyToClipboard(BuildContext context, String memberId) {
    Clipboard.setData(ClipboardData(text: memberId));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Member ID copied to clipboard'),
        backgroundColor: const Color(0xFF16a34a),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}