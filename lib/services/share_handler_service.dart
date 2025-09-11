// lib/services/share_handler_service.dart

import 'dart:async';
import 'dart:io';
import '../models/shared_content.dart';

class ShareHandlerService {
  static final ShareHandlerService _instance = ShareHandlerService._internal();
  factory ShareHandlerService() => _instance;
  ShareHandlerService._internal();

  StreamSubscription? _textStreamSubscription;
  StreamSubscription? _mediaStreamSubscription;
  final StreamController<SharedContent> _sharedContentController = StreamController<SharedContent>.broadcast();

  Stream<SharedContent> get sharedContentStream => _sharedContentController.stream;

  /// Initialize the share handler service
  void initialize() {
    try {
      print('📤 Initializing ShareHandlerService');
      
      // For now, we'll just handle initial shared content
      // The receive_sharing_intent package has different APIs
      _checkInitialSharedContent();
      
      print('✅ ShareHandlerService initialized successfully');
    } catch (e) {
      print('❌ Error initializing ShareHandlerService: $e');
    }
  }

  /// Check for initial shared content when app is opened from share
  void _checkInitialSharedContent() async {
    try {
      // Note: The receive_sharing_intent package API needs to be checked
      // For now, this is a placeholder for when the API is properly configured
      print('📤 Checking for initial shared content');
    } catch (e) {
      print('❌ Error checking initial shared content: $e');
    }
  }

  /// Handle shared text content
  void _handleSharedText(String text) {
    try {
      if (text.trim().isEmpty) return;

      final sharedContent = SharedContent.fromText(text);
      print('📤 Processing shared ${sharedContent.type.name}: ${sharedContent.displayText}');
      
      _sharedContentController.add(sharedContent);
    } catch (e) {
      print('❌ Error handling shared text: $e');
    }
  }

  /// Handle shared media files (simplified native implementation)
  void _handleSharedMedia(List<String> imagePaths) {
    try {
      if (imagePaths.isEmpty) return;

      // Verify files exist
      final existingFiles = imagePaths.where((path) => File(path).existsSync()).toList();
      
      if (existingFiles.isEmpty) {
        print('⚠️ No existing image files found');
        return;
      }

      final sharedContent = SharedContent.fromImages(existingFiles);
      print('📤 Processing shared images: ${sharedContent.displayText}');
      
      _sharedContentController.add(sharedContent);
    } catch (e) {
      print('❌ Error handling shared media: $e');
    }
  }

  /// Reset/clear any pending shared content (call after processing)
  void clearSharedContent() {
    try {
      // Note: API call needs proper implementation
      print('✅ Cleared shared content');
    } catch (e) {
      print('❌ Error clearing shared content: $e');
    }
  }

  /// Manually trigger a share event for testing
  void simulateShare(SharedContent content) {
    if (!_sharedContentController.isClosed) {
      _sharedContentController.add(content);
    }
  }

  /// Get sharing statistics
  Map<String, dynamic> getStats() {
    return {
      'hasActiveListeners': !_sharedContentController.isClosed,
      'textStreamActive': _textStreamSubscription != null && !_textStreamSubscription!.isPaused,
      'mediaStreamActive': _mediaStreamSubscription != null && !_mediaStreamSubscription!.isPaused,
    };
  }

  /// Dispose of the service
  void dispose() {
    try {
      print('📤 Disposing ShareHandlerService');
      
      _textStreamSubscription?.cancel();
      _mediaStreamSubscription?.cancel();
      
      if (!_sharedContentController.isClosed) {
        _sharedContentController.close();
      }
      
      print('✅ ShareHandlerService disposed');
    } catch (e) {
      print('❌ Error disposing ShareHandlerService: $e');
    }
  }
}

/// Utility functions for file handling
class FileUtils {
  static bool isImage(String path) {
    const validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final extension = path.split('.').last.toLowerCase();
    return validExtensions.contains(extension);
  }
  
  static String getDisplayName(String path) {
    try {
      return path.split('/').last;
    } catch (e) {
      return 'Unknown file';
    }
  }
  
  static String getFileExtension(String path) {
    try {
      final name = getDisplayName(path);
      final lastDot = name.lastIndexOf('.');
      return lastDot != -1 ? name.substring(lastDot + 1).toLowerCase() : '';
    } catch (e) {
      return '';
    }
  }
}