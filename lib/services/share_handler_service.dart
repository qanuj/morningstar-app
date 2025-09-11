// lib/services/share_handler_service.dart

import 'dart:async';
import 'dart:io';
import '../models/shared_content.dart';

class ShareHandlerService {
  static final ShareHandlerService _instance = ShareHandlerService._internal();
  factory ShareHandlerService() => _instance;
  ShareHandlerService._internal();

  final StreamController<SharedContent> _sharedContentController = StreamController<SharedContent>.broadcast();

  Stream<SharedContent> get sharedContentStream => _sharedContentController.stream;

  /// Initialize the share handler service
  void initialize() {
    try {
      print('📤 Initializing ShareHandlerService (Basic Mode)');
      
      // For now, we'll create a basic implementation
      // The receive_sharing_intent plugin will be configured later
      print('✅ ShareHandlerService initialized successfully (Basic Mode)');
    } catch (e) {
      print('❌ Error initializing ShareHandlerService: $e');
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

  /// Handle shared media files using file paths
  void _handleSharedMedia(List<String> filePaths) {
    try {
      if (filePaths.isEmpty) return;

      // Verify files exist
      final existingFiles = filePaths.where((path) => File(path).existsSync()).toList();
      
      if (existingFiles.isEmpty) {
        print('⚠️ No existing media files found');
        return;
      }

      final sharedContent = SharedContent.fromImages(existingFiles);
      print('📤 Processing shared media: ${sharedContent.displayText}');
      
      _sharedContentController.add(sharedContent);
    } catch (e) {
      print('❌ Error handling shared media files: $e');
    }
  }

  /// Reset/clear any pending shared content (call after processing)
  void clearSharedContent() {
    try {
      print('✅ Clearing shared content');
    } catch (e) {
      print('❌ Error clearing shared content: $e');
    }
  }

  /// Manually trigger a share event for testing
  void simulateShare(SharedContent content) {
    if (!_sharedContentController.isClosed) {
      _sharedContentController.add(content);
      print('📤 Simulated share: ${content.displayText}');
    }
  }

  /// Simulate sharing a YouTube video URL for testing
  void simulateVideoShare(String videoUrl) {
    final sharedContent = SharedContent.fromText(videoUrl);
    simulateShare(sharedContent);
  }

  /// Get sharing statistics
  Map<String, dynamic> getStats() {
    return {
      'hasActiveListeners': !_sharedContentController.isClosed,
      'isBasicMode': true,
      'pluginAvailable': false,
    };
  }

  /// Dispose of the service
  void dispose() {
    try {
      print('📤 Disposing ShareHandlerService');
      
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
  
  static bool isVideo(String path) {
    const validExtensions = ['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', '3gp', 'webm'];
    final extension = path.split('.').last.toLowerCase();
    return validExtensions.contains(extension);
  }
  
  static bool isUrl(String text) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    return urlRegex.hasMatch(text);
  }
  
  static bool isYouTubeUrl(String url) {
    final youtubeRegex = RegExp(r'(youtube\.com/watch\?v=|youtu\.be/)');
    return youtubeRegex.hasMatch(url);
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