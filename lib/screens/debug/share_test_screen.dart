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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Test Text Share'),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => _testUrlShare(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06aeef),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Test URL Share'),
            ),

            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => _testImageShare(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf59e0b),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Test Image Share'),
            ),

            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => _testRealSharing(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16a34a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
    final sharedContent = SharedContent.fromText('This is a test shared message from the debug screen!');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(
          sharedContent: sharedContent,
        ),
      ),
    );
  }

  void _testUrlShare(BuildContext context) {
    final sharedContent = SharedContent.fromText('https://flutter.dev - Check out this awesome framework!');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(
          sharedContent: sharedContent,
        ),
      ),
    );
  }

  void _testImageShare(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    
    try {
      // Pick an image from gallery
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (!mounted) return;
      
      if (image != null) {
        // Create shared content with the picked image
        final sharedContent = SharedContent.fromImages([image.path]);
        
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ShareTargetScreen(
              sharedContent: sharedContent,
            ),
          ),
        );
      } else {
        // No image selected - create a mock image share for testing
        _showMockImageShare(navigator, scaffold);
      }
    } catch (e) {
      // If image picker fails, show mock image share
      if (mounted) {
        _showMockImageShare(navigator, scaffold);
      }
    }
  }

  void _showMockImageShare(NavigatorState navigator, ScaffoldMessengerState scaffold) {
    // Create a mock image path for testing UI
    final mockImagePaths = [
      '/storage/emulated/0/Pictures/test_image_1.jpg',
      '/storage/emulated/0/Pictures/test_image_2.jpg',
    ];
    
    final sharedContent = SharedContent.fromImages(mockImagePaths);
    
    navigator.push(
      MaterialPageRoute(
        builder: (context) => ShareTargetScreen(
          sharedContent: sharedContent,
        ),
      ),
    );

    // Show info that this is mock data
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Using mock image data for testing UI (images may not load)'),
        backgroundColor: Color(0xFFf59e0b),
        duration: Duration(seconds: 3),
      ),
    );
  }


  void _testRealSharing(BuildContext context) {
    final sharedContent = SharedContent.fromText('🏏 Check out this awesome cricket club app!');
    
    // Simulate a real share by using the ShareHandlerService
    ShareHandlerService().simulateShare(sharedContent);
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulated real sharing! Check if ShareTargetScreen opens.'),
        backgroundColor: Color(0xFF16a34a),
        duration: Duration(seconds: 2),
      ),
    );
  }
}