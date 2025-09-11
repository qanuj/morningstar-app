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
      appBar: AppBar(
        title: const Text('Share Test'),
        backgroundColor: const Color(0xFF003f9b),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Test Sharing Functionality',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () => _testTextShare(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003f9b),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Test Text Share'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => _testUrlShare(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06aeef),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Test URL Share'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => _testImageShare(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf59e0b),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Test Multiple Images'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => _testSingleImageShare(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFdc2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Test Single Image'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => _testVideoShare(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFdc2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Test YouTube Video Share'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => _testRealSharing(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16a34a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Test Real Share Flow'),
            ),

            const SizedBox(height: 40),

            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'For iOS testing:\n'
                '1. Use these buttons to simulate sharing\n'
                '2. Or test URL scheme: duggy://share?text=Hello\n'
                '3. Android sharing should work from any app',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
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

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Testing YouTube video share - no app reload should occur!',
        ),
        backgroundColor: Color(0xFFdc2626),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _testImageShare(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

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

        // Show success message with count
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              'Selected ${images.length} image${images.length == 1 ? '' : 's'} for sharing',
            ),
            backgroundColor: const Color(0xFF16a34a),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // No images selected - create a mock image share for testing
        _showMockImageShare(navigator, scaffold);
      }
    } catch (e) {
      // If image picker fails, show mock image share
      if (mounted) {
        _showMockImageShare(navigator, scaffold);
      }
    }
  }

  void _testSingleImageShare(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

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

        // Show success message
        scaffold.showSnackBar(
          const SnackBar(
            content: Text('Selected 1 image for sharing'),
            backgroundColor: Color(0xFF16a34a),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // No image selected - create a mock single image share for testing
        _showMockSingleImageShare(navigator, scaffold);
      }
    } catch (e) {
      // If image picker fails, show mock image share
      if (mounted) {
        _showMockSingleImageShare(navigator, scaffold);
      }
    }
  }

  void _showMockSingleImageShare(
    NavigatorState navigator,
    ScaffoldMessengerState scaffold,
  ) {
    // Create a single mock image path for testing UI
    final mockImagePaths = ['/storage/emulated/0/Pictures/test_single_image.jpg'];

    final sharedContent = SharedContent.fromImages(mockImagePaths);

    navigator.push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
      ),
    );

    // Show info that this is mock data
    scaffold.showSnackBar(
      const SnackBar(
        content: Text(
          'Using mock data with 1 image for testing UI (image may not load)',
        ),
        backgroundColor: Color(0xFFf59e0b),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showMockImageShare(
    NavigatorState navigator,
    ScaffoldMessengerState scaffold,
  ) {
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

    // Show info that this is mock data
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          'Using mock data with ${mockImagePaths.length} images for testing UI (images may not load)',
        ),
        backgroundColor: const Color(0xFFf59e0b),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _testRealSharing(BuildContext context) {
    final sharedContent = SharedContent.fromText(
      '🏏 Check out this awesome cricket club app!',
    );

    // Simulate a real share by using the ShareHandlerService
    ShareHandlerService().simulateShare(sharedContent);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Simulated real sharing! Check if ShareTargetScreen opens.',
        ),
        backgroundColor: Color(0xFF16a34a),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
