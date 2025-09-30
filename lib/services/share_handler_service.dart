// lib/services/share_handler_service.dart

import 'dart:async';
import 'dart:io';
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
      print('📤 === RAW SHARED DATA RECEIVED ===');
      print('📤 Data keys: ${data.keys.toList()}');
      print('📤 Full data: $data');
      print('📤 ===================================');

      final String? text = data['text'] as String?;
      final String? content = data['content'] as String?;
      final String? subject = data['subject'] as String?;
      final String? type = data['type'] as String?;
      final String? message = data['message'] as String?;
      final String? timestamp = data['timestamp']?.toString();

      print('📤 Processing enhanced shared data:');
      print('   Type: $type');
      print('   Text: $text');
      print('   Content: $content');
      print('   Subject: $subject');
      print('   Message: $message');
      print('   Timestamp: $timestamp');

      // Handle multiple files type specially
      if (type == 'multiple_files' && data['files'] != null) {
        // Process files asynchronously without waiting
        _processMultipleFiles(data['files'] as List<dynamic>);
        return;
      }

      // Use content or text - prioritize content from share extension
      final sharedText = content ?? text;

      if (sharedText != null && sharedText.trim().isNotEmpty) {
        // Create SharedContent with enhanced data
        print('📤 Creating SharedContent from sharedText: $sharedText');
        final sharedContent = _createSharedContentFromData(
          sharedText,
          type,
          message,
        );
        print('📤 Created SharedContent: ${sharedContent.displayText}');

        if (!_sharedContentController.isClosed) {
          _sharedContentController.add(sharedContent);
          print('📤 Added SharedContent to stream');
        } else {
          print('❌ SharedContent controller is closed');
        }
      } else if (type == 'image' && message != null) {
        // Handle image sharing even without text content
        print('📤 Creating SharedContent for image without text content');
        final sharedContent = _createSharedContentFromData('', type, message);

        if (!_sharedContentController.isClosed) {
          _sharedContentController.add(sharedContent);
          print('📤 Added image SharedContent to stream');
        } else {
          print('❌ SharedContent controller is closed');
        }
      } else if (type == 'video' && message != null) {
        // Handle video sharing even without text content
        print('📤 Creating SharedContent for video without text content');
        final sharedContent = _createSharedContentFromData('', type, message);

        if (!_sharedContentController.isClosed) {
          _sharedContentController.add(sharedContent);
          print('📤 Added video SharedContent to stream');
        } else {
          print('❌ SharedContent controller is closed');
        }
      } else {
        print('⚠️ No valid content in shared data');
        print('   sharedText: $sharedText');
        print('   type: $type');
        print('   message: $message');
      }
    } catch (e, stackTrace) {
      print('❌ Error processing shared data: $e');
      print('❌ Stack trace: $stackTrace');
      // Don't rethrow to prevent app crash
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

      // Handle duggy://share?link=<url>&text=<text> format
      if (scheme.toLowerCase() == 'duggy' && host.toLowerCase() == 'share') {
        final String? linkUrl = params?['link'] as String?;
        final String? textParam = params?['text'] as String?;

        if (linkUrl != null && linkUrl.isNotEmpty) {
          print('📤 Processing duggy://share with link: $linkUrl');

          // Create SharedContent directly for the URL
          final urlSharedContent = SharedContent(
            type: SharedContentType.url,
            text: linkUrl,
            url: linkUrl,
            metadata: {
              'isUrlShare': true,
              'viaUrlScheme': true,
              if (textParam != null && textParam.isNotEmpty) 'userText': textParam,
            },
          );

          if (!_sharedContentController.isClosed) {
            _sharedContentController.add(urlSharedContent);
            print('📤 Added URL from scheme to stream: ${urlSharedContent.displayText}');
            if (textParam != null && textParam.isNotEmpty) {
              print('📤 URL scheme includes text parameter: $textParam');
            }
          }
        } else if (textParam != null && textParam.isNotEmpty) {
          print('📤 Processing duggy://share with text only: $textParam');

          // Create SharedContent for plain text
          final textSharedContent = SharedContent(
            type: SharedContentType.text,
            text: textParam,
            metadata: {'isTextShare': true, 'viaUrlScheme': true},
          );

          if (!_sharedContentController.isClosed) {
            _sharedContentController.add(textSharedContent);
            print('📤 Added text from scheme to stream: ${textSharedContent.displayText}');
          }
        } else {
          print('⚠️ No link or text parameter found in duggy://share URL');
        }
      } else if (host.toLowerCase() == 'share' && params != null) {
        // Convert generic URL to share data format (legacy support)
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

  /// Check for shared content from App Groups container (called when app resumes)
  Future<void> checkForSharedContent() async {
    try {
      print('📤 Checking App Groups container for shared content...');

      // Get shared content from iOS App Groups using method channel
      final result = await _methodChannel.invokeMethod('checkSharedContent');
      if (result != null) {
        print('📤 Found shared content in App Groups container');
        final Map<String, dynamic> data = Map<String, dynamic>.from(result);
        _processSharedData(data);
      } else {
        print('📤 No shared content found in App Groups container');
      }
    } catch (e) {
      print('❌ Error checking for shared content: $e');
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

  /// Simulate duggy://share?link=<url> URL scheme for testing
  void simulateUrlSchemeShare(String url) {
    final urlData = {
      'scheme': 'duggy',
      'host': 'share',
      'path': '',
      'params': {'link': url},
    };
    _processGenericURL(urlData);
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

  /// Process multiple files shared at once
  Future<void> _processMultipleFiles(List<dynamic> files) async {
    try {
      print('📤 === PROCESSING MULTIPLE FILES ===');
      print('📤 Number of files: ${files.length}');

      // For single file, check if it's a URL first
      if (files.length == 1) {
        final fileData = files[0];
        print('📤 Processing single file: $fileData');

        if (fileData is Map) {
          final map = Map<String, dynamic>.from(fileData);
          final filePath = map['path'] as String? ?? map['content'] as String?;
          final fileType = map['type'] as String?;

          // Check if it's a URL stored as file
          if (fileType == 'file' && filePath != null && await _isFileContainingUrl(filePath)) {
            final urlContent = await _readUrlFromFile(filePath);
            if (urlContent != null) {
              print('📤 Detected URL in single file: $urlContent');
              final urlSharedContent = SharedContent(
                type: SharedContentType.url,
                text: urlContent,
                url: urlContent,
                metadata: {'isUrlShare': true, 'originalFilePath': filePath},
              );
              if (!_sharedContentController.isClosed) {
                _sharedContentController.add(urlSharedContent);
                print('📤 Added single URL SharedContent to stream: ${urlSharedContent.displayText}');
              }
              return; // Exit early for single URL
            }
          }

          // Check if it's a direct URL
          if (fileType == 'url' || (filePath != null && FileUtils.isUrl(filePath))) {
            print('📤 Detected direct URL: $filePath');
            final urlSharedContent = SharedContent(
              type: SharedContentType.url,
              text: filePath!,
              url: filePath,
              metadata: {'isUrlShare': true},
            );
            if (!_sharedContentController.isClosed) {
              _sharedContentController.add(urlSharedContent);
              print('📤 Added direct URL SharedContent to stream: ${urlSharedContent.displayText}');
            }
            return; // Exit early for single URL
          }
        }
      }

      // Process multiple files (images, documents, etc.) - but not URLs
      final List<String> validImagePaths = [];
      final List<String> validFilePaths = [];
      String? firstMessage;

      for (int i = 0; i < files.length; i++) {
        final fileData = files[i];
        print('📤 Processing file $i raw data: $fileData');

        if (fileData is Map) {
          final map = Map<String, dynamic>.from(fileData);
          final filePath = map['path'] as String? ?? map['content'] as String?;
          final fileType = map['type'] as String?;
          final message = map['message'] as String?;

          if (firstMessage == null && message != null) {
            firstMessage = message;
          }

          print('📤 File $i details:');
          print('   Path: $filePath');
          print('   Type: $fileType');
          print('   Message: $message');

          if (filePath != null && filePath.isNotEmpty) {
            // Skip URLs in multiple files processing - URLs should be shared individually
            if (fileType == 'url' || FileUtils.isUrl(filePath)) {
              print('⚠️ Skipping URL in multiple files: $filePath (URLs should be shared individually)');
              continue;
            }

            // Categorize non-URL files
            if (fileType == 'image' && FileUtils.isImage(filePath)) {
              validImagePaths.add(filePath);
              print('📤 Added image file: $filePath');
            } else {
              validFilePaths.add(filePath);
              print('📤 Added non-image file: $filePath');
            }
          }
        }
      }

      // Create SharedContent for multiple files (no URLs)
      SharedContent? sharedContent;

      if (validImagePaths.isNotEmpty && validFilePaths.isEmpty) {
        // All images
        if (validImagePaths.length == 1) {
          sharedContent = SharedContent.fromImages(validImagePaths);
          print('📤 Created single image SharedContent');
        } else {
          sharedContent = SharedContent(
            type: SharedContentType.multipleImages,
            text: firstMessage ?? '📸 Shared ${validImagePaths.length} images',
            imagePaths: validImagePaths,
          );
          print('📤 Created multiple images SharedContent with ${validImagePaths.length} images');
        }
      } else if (validImagePaths.isEmpty && validFilePaths.isNotEmpty) {
        // All files
        sharedContent = SharedContent(
          type: SharedContentType.file,
          text: firstMessage ?? '📄 Shared ${validFilePaths.length} files',
          filePaths: validFilePaths,
        );
        print('📤 Created file SharedContent with ${validFilePaths.length} files');
      } else if (validImagePaths.isNotEmpty && validFilePaths.isNotEmpty) {
        // Mixed content
        sharedContent = SharedContent(
          type: SharedContentType.file,
          text: firstMessage ?? '📁 Shared ${validImagePaths.length + validFilePaths.length} files',
          imagePaths: validImagePaths,
          filePaths: validFilePaths,
        );
        print('📤 Created mixed content SharedContent');
      }

      // Add SharedContent to stream
      if (sharedContent != null) {
        if (!_sharedContentController.isClosed) {
          _sharedContentController.add(sharedContent);
          print('📤 Added SharedContent to stream: ${sharedContent.displayText}');
        }
      } else {
        print('⚠️ No valid files found to create SharedContent');
      }

      print('📤 ================================');
    } catch (e, stackTrace) {
      print('❌ Error processing multiple files: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  /// Check if a file contains a URL (for URLs saved as files)
  Future<bool> _isFileContainingUrl(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // Read small portion to check if it contains a URL
      final bytes = await file.readAsBytes();
      if (bytes.length > 1024) return false; // URLs shouldn't be that large

      final content = String.fromCharCodes(bytes).trim();
      return FileUtils.isUrl(content);
    } catch (e) {
      print('❌ Error checking file for URL: $e');
      return false;
    }
  }

  /// Read URL from file content
  Future<String?> _readUrlFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.length > 2048) return null; // Increase size limit for plist files

      final content = String.fromCharCodes(bytes);

      // First check if it's a plain URL
      if (FileUtils.isUrl(content.trim())) {
        final cleanUrl = content.trim();
        print('📤 Successfully read plain URL from file: $cleanUrl');
        return cleanUrl;
      }

      // Extract URL from binary plist or other formats using regex
      final urlPattern = RegExp(r'https?://[^\s\x00-\x1f\x7f-\x9f]+');
      final urlMatch = urlPattern.firstMatch(content);

      if (urlMatch != null) {
        final extractedUrl = urlMatch.group(0)!;
        // Clean up any trailing characters that aren't part of the URL
        final cleanUrl = _cleanExtractedUrl(extractedUrl);
        if (FileUtils.isUrl(cleanUrl)) {
          print('📤 Successfully extracted URL from binary content: $cleanUrl');
          return cleanUrl;
        }
      }

      print('📤 No valid URL found in file content');
      return null;
    } catch (e) {
      print('❌ Error reading URL from file: $e');
      return null;
    }
  }

  /// Clean extracted URL from binary content
  String _cleanExtractedUrl(String url) {
    // Remove any trailing non-URL characters
    final cleanedUrl = url.replaceAll(RegExp(r'[^\w\-._~:/?#[\]@!\$&'"'"'()*+,;=%]+\$'), '');

    // Ensure the URL ends properly (remove any incomplete parameters)
    if (cleanedUrl.contains('&') && !cleanedUrl.endsWith('&')) {
      // If there's an incomplete parameter, remove it
      final lastAmpersand = cleanedUrl.lastIndexOf('&');
      final afterAmpersand = cleanedUrl.substring(lastAmpersand + 1);
      if (!afterAmpersand.contains('=') || afterAmpersand.endsWith('=')) {
        return cleanedUrl.substring(0, lastAmpersand);
      }
    }

    return cleanedUrl;
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
    if (text.isEmpty) return false;

    // Basic URL pattern check
    final urlRegex = RegExp(r'^https?://[^\s]+$');
    if (!urlRegex.hasMatch(text)) return false;

    // Additional validation to ensure it's a proper URL
    try {
      final uri = Uri.parse(text);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  static bool isYouTubeUrl(String url) {
    final youtubeRegex = RegExp(r'(youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/)');
    return youtubeRegex.hasMatch(url);
  }

  static bool isSocialMediaUrl(String url) {
    final socialRegex = RegExp(r'(youtube\.com|youtu\.be|instagram\.com|twitter\.com|x\.com|facebook\.com|tiktok\.com)');
    return socialRegex.hasMatch(url);
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
