// lib/screens/debug/share_test_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../shared/share_target_screen.dart';
import '../../models/shared_content.dart';
import '../../services/share_handler_service.dart';

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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
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
                    '• iOS: Test URL scheme duggy://share?text=Hello\n'
                    '• Android: Sharing should work from any app\n'
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
            child: Column(
              children: children,
            ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  void _testTextShare(BuildContext context) {
    final sharedContent = SharedContent.fromText(
      'This is a test shared message from the debug screen!',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );
  }

  void _testUrlShare(BuildContext context) {
    final sharedContent = SharedContent.fromText('https://duggy.app');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );
  }

  void _testVideoShare(BuildContext context) {
    // Test with a YouTube video URL like the user mentioned
    final sharedContent = SharedContent.fromText('https://youtube.com/watch?v=dQw4w9WgXcQ');

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
    final mockImagePaths = ['/storage/emulated/0/Pictures/test_single_image.jpg'];

    final sharedContent = SharedContent.fromImages(mockImagePaths);

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
}
