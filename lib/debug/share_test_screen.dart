// lib/screens/debug/share_test_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/shared/share_target_screen.dart';
import '../models/shared_content.dart';
import '../services/share_handler_service.dart';
import '../screens/qr_scanner.dart';
import 'api_test_screen.dart';

class ShareTestScreen extends StatefulWidget {
  const ShareTestScreen({super.key});

  @override
  State<ShareTestScreen> createState() => _ShareTestScreenState();
}

class _ShareTestScreenState extends State<ShareTestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.build, size: 20),
            SizedBox(width: 8),
            Text('Admin Toolbox'),
          ],
        ),
        backgroundColor: const Color(0xFF003f9b),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 48,
                    color: const Color(0xFF003f9b),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Admin Testing Tools',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF003f9b),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hidden toolbox for testing sharing functionality',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Content Sharing Tests
            _buildToolSection(
              title: 'Content Sharing Tests',
              icon: Icons.share,
              color: const Color(0xFF003f9b),
              children: [
                _buildToolButton(
                  label: 'Test Text Share',
                  icon: Icons.text_fields,
                  onPressed: () => _testTextShare(context),
                  color: const Color(0xFF003f9b),
                ),
                _buildToolButton(
                  label: 'Test URL Share',
                  icon: Icons.link,
                  onPressed: () => _testUrlShare(context),
                  color: const Color(0xFF06aeef),
                ),
                _buildToolButton(
                  label: 'Test YouTube Video',
                  icon: Icons.video_library,
                  onPressed: () => _testVideoShare(context),
                  color: const Color(0xFFdc2626),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Media Sharing Tests
            _buildToolSection(
              title: 'Media Sharing Tests',
              icon: Icons.photo_library,
              color: const Color(0xFFf59e0b),
              children: [
                _buildToolButton(
                  label: 'Test Single Image',
                  icon: Icons.image,
                  onPressed: () => _testSingleImageShare(context),
                  color: const Color(0xFFf59e0b),
                ),
                _buildToolButton(
                  label: 'Test Multiple Images',
                  icon: Icons.photo_library,
                  onPressed: () => _testImageShare(context),
                  color: const Color(0xFFf59e0b),
                ),
              ],
            ),

            SizedBox(height: 24),

            // QR Tools
            _buildToolSection(
              title: 'QR Code Tools',
              icon: Icons.qr_code,
              color: const Color(0xFF8B5CF6),
              children: [
                _buildToolButton(
                  label: 'QR Code Scanner (Raw JSON)',
                  icon: Icons.qr_code_scanner,
                  onPressed: () => _scanQRCode(context),
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Advanced Testing
            _buildToolSection(
              title: 'Advanced Testing',
              icon: Icons.science,
              color: const Color(0xFF16a34a),
              children: [
                _buildToolButton(
                  label: 'Test Real Share Flow',
                  icon: Icons.rocket_launch,
                  onPressed: () => _testRealSharing(context),
                  color: const Color(0xFF16a34a),
                ),
                _buildToolButton(
                  label: 'API Connectivity Test',
                  icon: Icons.network_check,
                  onPressed: () => _openApiTestScreen(context),
                  color: const Color(0xFF059669),
                ),
                _buildToolButton(
                  label: 'Test Share Flow End-to-End',
                  icon: Icons.analytics,
                  onPressed: () => _testEndToEndFlow(context),
                  color: const Color(0xFF7c3aed),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Testing Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Testing Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Use these buttons to simulate different sharing scenarios\n'
                    '• Messages are sent successfully (check console logs)\n'
                    '• To see messages in chat: Pull down to refresh chat screen\n'
                    '• Success notifications will confirm message was sent\n'
                    '• All tests work without external dependencies',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildToolSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
      ),
    );
  }

  void _testTextShare(BuildContext context) {
    final sharedContent = SharedContent.fromText(
      'This is a test shared message from the debug screen!',
    );

    print('🔧 Admin Tools: Starting text share test');
    print('🔧 Admin Tools: Content type: ${sharedContent.type}');
    print('🔧 Admin Tools: Content text: ${sharedContent.text}');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );
  }

  void _testUrlShare(BuildContext context) {
    final sharedContent = SharedContent.fromText('https://duggy.app');

    print('🔧 Admin Tools: Starting URL share test');
    print('🔧 Admin Tools: Content type: ${sharedContent.type}');
    print('🔧 Admin Tools: URL: ${sharedContent.url}');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );
  }

  void _testVideoShare(BuildContext context) {
    // Test with a YouTube video URL like the user mentioned
    final sharedContent = SharedContent.fromText(
      'https://youtube.com/watch?v=dQw4w9WgXcQ',
    );

    print('🔧 Admin Tools: Starting YouTube video share test');
    print('🔧 Admin Tools: Content type: ${sharedContent.type}');
    print('🔧 Admin Tools: URL: ${sharedContent.url}');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );
  }

  void _testImageShare(BuildContext context) async {
    final navigator = Navigator.of(context);

    try {
      // Pick multiple images from gallery
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultipleMedia(
        limit: 10, // Allow up to 10 images
        imageQuality: 80, // Compress images to 80% quality
      );

      if (!mounted) return;

      if (images.isNotEmpty) {
        // Create shared content with the picked images
        final imagePaths = images.map((image) => image.path).toList();
        final sharedContent = SharedContent.fromImages(imagePaths);

        navigator.push(
          MaterialPageRoute(
            builder: (context) =>
                ShareTargetScreen(sharedContent: sharedContent),
          ),
        );
      } else {
        // No images selected - create a mock image share for testing
        _showMockImageShare(navigator);
      }
    } catch (e) {
      // If image picker fails, show mock image share
      if (mounted) {
        _showMockImageShare(navigator);
      }
    }
  }

  void _testSingleImageShare(BuildContext context) async {
    final navigator = Navigator.of(context);

    try {
      // Pick a single image from gallery
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress image to 80% quality
      );

      if (!mounted) return;

      if (image != null) {
        // Create shared content with the picked image
        final sharedContent = SharedContent.fromImages([image.path]);

        navigator.push(
          MaterialPageRoute(
            builder: (context) =>
                ShareTargetScreen(sharedContent: sharedContent),
          ),
        );
      } else {
        // No image selected - create a mock single image share for testing
        _showMockSingleImageShare(navigator);
      }
    } catch (e) {
      // If image picker fails, show mock image share
      if (mounted) {
        _showMockSingleImageShare(navigator);
      }
    }
  }

  void _showMockSingleImageShare(NavigatorState navigator) {
    // Create a single mock image path for testing UI
    final mockImagePaths = [
      '/storage/emulated/0/Pictures/test_single_image.jpg',
    ];

    final sharedContent = SharedContent.fromImages(mockImagePaths);

    print('🔧 Admin Tools: Starting mock single image share test');
    print('🔧 Admin Tools: Content type: ${sharedContent.type}');
    print('🔧 Admin Tools: Mock image paths: $mockImagePaths');

    navigator.push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );
  }

  void _showMockImageShare(NavigatorState navigator) {
    // Create mock image paths for testing UI with multiple images
    final mockImagePaths = [
      '/storage/emulated/0/Pictures/test_image_1.jpg',
      '/storage/emulated/0/Pictures/test_image_2.jpg',
      '/storage/emulated/0/Pictures/test_image_3.jpg',
      '/storage/emulated/0/Pictures/test_image_4.jpg',
      '/storage/emulated/0/Pictures/test_image_5.jpg',
    ];

    final sharedContent = SharedContent.fromImages(mockImagePaths);

    print('🔧 Admin Tools: Starting mock multiple images share test');
    print('🔧 Admin Tools: Content type: ${sharedContent.type}');
    print('🔧 Admin Tools: Mock image paths: $mockImagePaths');

    navigator.push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );
  }

  void _testRealSharing(BuildContext context) {
    final sharedContent = SharedContent.fromText(
      '🏏 Check out this awesome cricket club app!',
    );

    // Simulate a real share by using the ShareHandlerService
    ShareHandlerService().simulateShare(sharedContent);
  }

  void _scanQRCode(BuildContext context) async {
    try {
      final String? qrData = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) =>
              const QRScanner(title: 'QR Code Scanner (Debug)'),
        ),
      );

      print('QR Scan Result: $qrData');

      if (qrData != null && mounted) {
        // Show the raw JSON data in a native alert dialog that auto-closes
        showDialog(
          context: this.context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.qr_code, color: const Color(0xFF8B5CF6)),
                  SizedBox(width: 8),
                  Text('QR Code Data'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Raw Data:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SelectableText(
                          qrData,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Close Now'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openApiTestScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ApiTestScreen()));
  }

  void _testEndToEndFlow(BuildContext context) {
    // Show dialog to explain what this test does
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End-to-End Share Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This test will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Create a test text message'),
            Text('• Navigate to club selection screen'),
            Text('• Send messages to selected clubs'),
            Text('• Show success confirmation'),
            Text('• Log detailed information to console'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'Note: After sending, pull down to refresh any chat screens to see the new messages.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
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
              Navigator.of(context).pop();
              _performEndToEndTest(context);
            },
            child: Text('Start Test'),
          ),
        ],
      ),
    );
  }

  void _performEndToEndTest(BuildContext context) {
    final sharedContent = SharedContent.fromText(
      '🚀 END-TO-END TEST MESSAGE - This is testing the complete sharing flow from admin tools!',
    );

    print('🧪 E2E Test: Starting end-to-end share test');
    print('🧪 E2E Test: Content type: ${sharedContent.type}');
    print('🧪 E2E Test: Content text: ${sharedContent.text}');
    print('🧪 E2E Test: Content valid: ${sharedContent.isValid}');
    print('🧪 E2E Test: Navigating to ShareTargetScreen...');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );
  }
}
