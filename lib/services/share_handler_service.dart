// lib/services/share_handler_service.dart

import 'dart:async';
import 'package:flutter/services.dart';
import '../models/shared_content.dart';

class ShareHandlerService {
  static final ShareHandlerService _instance = ShareHandlerService._internal();
  factory ShareHandlerService() => _instance;
  ShareHandlerService._internal();

  final StreamController<SharedContent> _sharedContentController =
      StreamController<SharedContent>.broadcast();
  static const MethodChannel _methodChannel = MethodChannel('app.duggy/share');
  Stream<SharedContent> get sharedContentStream =>
      _sharedContentController.stream;

  /// Initialize the share handler service
  void initialize() {
    try {
      print(
        '📤 Initializing ShareHandlerService (Custom Method Channel with iOS Support)',
      );

      // Set up method channel listener for native sharing
      _methodChannel.setMethodCallHandler(_handleMethodCall);

      // Check for initial shared data (when app is launched via sharing)
      _getInitialSharedData();

      // Add a test to verify method channel is working
      _testMethodChannel();

      print(
        '✅ ShareHandlerService initialized successfully (Custom Method Channel with iOS Support)',
      );
    } catch (e) {
      print('❌ Error initializing ShareHandlerService: $e');
    }
  }

  /// Test method channel connectivity
  Future<void> _testMethodChannel() async {
    try {
      print('📤 Testing method channel connectivity...');
      final result = await _methodChannel.invokeMethod('getSharedData');
      print('📤 Method channel test result: $result');
    } catch (e) {
      print('📤 Method channel test error (expected if no shared data): $e');
    }
  }

  /// Handle method calls from native iOS/Android
  Future<void> _handleMethodCall(MethodCall call) async {
    print('📤 ====== FLUTTER METHOD CALL RECEIVED ======');
    print('📤 Method: ${call.method}');
    print('📤 Arguments: ${call.arguments}');
    print('📤 Arguments type: ${call.arguments.runtimeType}');

    switch (call.method) {
      case 'onDataReceived':
        print('📤 Processing onDataReceived...');
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          call.arguments,
        );
        print('📤 Parsed data: $data');
        _processSharedData(data);
        break;
      case 'onURLReceived':
        final Map<String, dynamic> urlData = Map<String, dynamic>.from(
          call.arguments,
        );
        _processGenericURL(urlData);
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

  /// Process shared data from native iOS/Android
  void _processSharedData(Map<String, dynamic> data) {
    try {
      final String? text = data['text'] as String?;
      final String? content = data['content'] as String?;
      final String? subject = data['subject'] as String?;
      final String? type = data['type'] as String?;
      final String? message = data['message'] as String?;
      final String? timestamp = data['timestamp'] as String?;

      print('📤 Processing enhanced shared data:');
      print('   Type: $type');
      print('   Text: $text');
      print('   Content: $content');
      print('   Subject: $subject');
      print('   Message: $message');
      print('   Timestamp: $timestamp');

      // Use content or text - prioritize content from share extension
      final sharedText = content ?? text;

      if (sharedText != null && sharedText.trim().isNotEmpty) {
        // Create SharedContent with enhanced data
        final sharedContent = _createSharedContentFromData(
          sharedText,
          type,
          message,
        );
        _sharedContentController.add(sharedContent);
      } else if (type == 'image' && message != null) {
        // Handle image sharing even without text content
        final sharedContent = _createSharedContentFromData('', type, message);
        _sharedContentController.add(sharedContent);
      } else {
        print('⚠️ No valid content in shared data');
      }
    } catch (e) {
      print('❌ Error processing shared data: $e');
    }
  }

  /// Process generic URL data for deep linking
  void _processGenericURL(Map<String, dynamic> urlData) {
    try {
      final String scheme = urlData['scheme'] as String? ?? '';
      final String host = urlData['host'] as String? ?? '';
      final String path = urlData['path'] as String? ?? '';
      final Map<String, dynamic>? params =
          urlData['params'] as Map<String, dynamic>?;

      print('📤 Processing generic URL:');
      print('   Scheme: $scheme');
      print('   Host: $host');
      print('   Path: $path');
      print('   Params: $params');

      // Handle different URL patterns for future extensibility
      if (host.toLowerCase() == 'share' && params != null) {
        // Convert generic URL to share data format
        _processSharedData(params);
      } else {
        print('⚠️ Unhandled URL pattern: $scheme://$host$path');
      }
    } catch (e) {
      print('❌ Error processing generic URL: $e');
    }
  }

  /// Create SharedContent from enhanced data
  SharedContent _createSharedContentFromData(
    String text,
    String? type,
    String? message,
  ) {
    try {
      // Determine content type
      SharedContent sharedContent;

      switch (type?.toLowerCase()) {
        case 'url':
          // Validate URL format and create URL content
          if (text.startsWith(RegExp(r'https?://'))) {
            sharedContent = SharedContent.fromText(text);
          } else {
            print('⚠️ Invalid URL format: $text');
            sharedContent = SharedContent.fromText(text); // Treat as text
          }
          break;
        case 'image':
          // Create image content
          if (text.isNotEmpty && text.startsWith('/')) {
            // We have an actual image file path (from file:// URL or share extension)
            print('📤 Creating SharedContent from image file path: $text');
            sharedContent = SharedContent.fromImages([text]);
          } else if (text.contains('📸 IMAGE_SHARED')) {
            // Legacy fallback - image shared from native but no file path
            final content = message?.isNotEmpty == true
                ? message!
                : '📸 Shared an image';
            // Create a special SharedContent that indicates image sharing
            sharedContent = SharedContent(
              type: SharedContentType.image,
              text: content,
              metadata: {'isImageShare': true},
            );
          } else {
            // Check if message contains a file path
            if (message?.isNotEmpty == true && message!.startsWith('/')) {
              print(
                '📤 Creating SharedContent from image file path in message: $message',
              );
              sharedContent = SharedContent.fromImages([message]);
            } else {
              // Fallback - create as text with message
              final content = message?.isNotEmpty == true
                  ? message!
                  : 'Shared an image';
              sharedContent = SharedContent.fromText(content);
            }
          }
          break;
        case 'video':
          // Create video content
          if (text.isNotEmpty && text.startsWith('/')) {
            // We have an actual video file path
            print('📤 Creating SharedContent from video file path: $text');
            sharedContent = SharedContent(
              type: SharedContentType.file,
              text: message?.isNotEmpty == true ? message! : '🎥 Shared a video',
              filePaths: [text],
              metadata: {'isVideoShare': true},
            );
          } else if (text.contains('🎥 VIDEO_SHARED')) {
            // Legacy fallback - video shared from native but no file path
            final content = message?.isNotEmpty == true
                ? message!
                : '🎥 Shared a video';
            sharedContent = SharedContent(
              type: SharedContentType.file,
              text: content,
              metadata: {'isVideoShare': true},
            );
          } else {
            // Fallback - create as text with message
            final content = message?.isNotEmpty == true
                ? message!
                : 'Shared a video';
            sharedContent = SharedContent.fromText(content);
          }
          break;
        case 'file':
          // Create file content
          if (text.isNotEmpty && text.startsWith('/')) {
            // We have an actual file path
            print('📤 Creating SharedContent from file path: $text');
            final fileName = text.split('/').last;
            sharedContent = SharedContent(
              type: SharedContentType.file,
              text: message?.isNotEmpty == true ? message! : '📄 Shared file: $fileName',
              filePaths: [text],
              metadata: {'isFileShare': true},
            );
          } else {
            // Fallback - create as text with message
            final content = message?.isNotEmpty == true
                ? message!
                : 'Shared a file';
            sharedContent = SharedContent.fromText(content);
          }
          break;
        case 'text':
        default:
          // Handle text content - use text if available, otherwise message
          if (text.trim().isNotEmpty) {
            sharedContent = SharedContent.fromText(text);
          } else if (message?.isNotEmpty == true) {
            sharedContent = SharedContent.fromText(message!);
          } else {
            print('⚠️ No valid text content provided');
            sharedContent = SharedContent.fromText(
              'Shared content',
            ); // Fallback
          }
          break;
      }

      print(
        '📤 Created SharedContent: ${sharedContent.displayText} (${sharedContent.type.name})',
      );
      return sharedContent;
    } catch (e) {
      print('❌ Error creating SharedContent: $e');
      // Return fallback content instead of crashing
      return SharedContent.fromText('Shared content');
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

  /// Simulate sharing an image for testing
  void simulateImageShare(String caption) {
    final sharedContent = SharedContent(
      type: SharedContentType.image,
      text: caption.isEmpty ? '📸 Shared an image' : caption,
      metadata: {'isImageShare': true},
    );
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

  /// Get the path to shared images directory
  Future<String?> getSharedImagesDirectory() async {
    try {
      final result = await _methodChannel.invokeMethod(
        'getSharedImagesDirectory',
      );
      return result as String?;
    } catch (e) {
      print('❌ Error getting shared images directory: $e');
      return null;
    }
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
    const validExtensions = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'wmv',
      'flv',
      '3gp',
      'webm',
      'm4v',
      'mpg',
      'mpeg',
    ];
    final extension = path.split('.').last.toLowerCase();
    return validExtensions.contains(extension);
  }

  static bool isDocument(String path) {
    const validExtensions = [
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'txt',
      'rtf',
    ];
    final extension = path.split('.').last.toLowerCase();
    return validExtensions.contains(extension);
  }

  static bool isAudio(String path) {
    const validExtensions = [
      'mp3',
      'wav',
      'aac',
      'flac',
      'm4a',
      'ogg',
    ];
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
