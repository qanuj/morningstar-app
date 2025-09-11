// lib/services/share_handler_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/shared_content.dart';

class ShareHandlerService {
  static final ShareHandlerService _instance = ShareHandlerService._internal();
  factory ShareHandlerService() => _instance;
  ShareHandlerService._internal();

  final StreamController<SharedContent> _sharedContentController = StreamController<SharedContent>.broadcast();
  static const MethodChannel _methodChannel = MethodChannel('app.duggy/share');

  Stream<SharedContent> get sharedContentStream => _sharedContentController.stream;

  /// Initialize the share handler service
  void initialize() {
    try {
      print('📤 Initializing ShareHandlerService (Native Method Channel)');
      
      // Set up method channel listener for native sharing
      _methodChannel.setMethodCallHandler(_handleMethodCall);
      
      // Check for initial shared data (when app is launched via sharing)
      _getInitialSharedData();
      
      print('✅ ShareHandlerService initialized successfully (Native Method Channel)');
    } catch (e) {
      print('❌ Error initializing ShareHandlerService: $e');
    }
  }

  /// Handle method calls from native Android
  Future<void> _handleMethodCall(MethodCall call) async {
    print('📤 Received method call: ${call.method}');
    
    switch (call.method) {
      case 'onDataReceived':
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
        _processSharedData(data);
        break;
      default:
        print('⚠️ Unknown method call: ${call.method}');
    }
  }

  /// Get initial shared data when app is launched via sharing
  Future<void> _getInitialSharedData() async {
    try {
      final result = await _methodChannel.invokeMethod('getSharedData');
      if (result != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(result);
        _processSharedData(data);
      }
    } catch (e) {
      print('❌ Error getting initial shared data: $e');
    }
  }

  /// Process shared data from native Android
  void _processSharedData(Map<String, dynamic> data) {
    try {
      final String? text = data['text'] as String?;
      final String? subject = data['subject'] as String?;
      final String? type = data['type'] as String?;

      print('📤 Processing shared data - Type: $type, Text: $text, Subject: $subject');

      if (text != null && text.trim().isNotEmpty) {
        _handleSharedText(text);
      } else {
        print('⚠️ No valid text content in shared data');
      }
    } catch (e) {
      print('❌ Error processing shared data: $e');
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
      'isNativeMethodChannel': true,
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