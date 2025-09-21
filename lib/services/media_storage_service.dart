import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class MediaStorageService {
  static const String _mediaMetadataPrefix = 'media_meta_';
  
  /// Get the local media directory
  static Future<Directory> getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Get a unique filename for a URL
  static String _getFileNameFromUrl(String url) {
    // Create hash of URL for unique filename
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    final extension = _getFileExtension(url);
    return '$digest$extension';
  }

  /// Extract file extension from URL
  static String _getFileExtension(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;

    // Handle special cases like dicebear URLs
    if (path.contains('/svg')) {
      return '.svg';
    }

    // Get the last segment of the path
    final segments = path.split('/');
    final lastSegment = segments.isNotEmpty ? segments.last : '';

    // Check if last segment has an extension
    final lastDot = lastSegment.lastIndexOf('.');
    if (lastDot != -1 && lastDot < lastSegment.length - 1) {
      final extension = lastSegment.substring(lastDot);
      // Ensure extension doesn't contain path separators
      if (!extension.contains('/') && extension.length <= 6) {
        return extension;
      }
    }

    // Default fallback
    return '.bin';
  }

  /// Download and cache a media file with smart caching
  static Future<String?> downloadMedia(String url) async {
    try {
      print('📥 Downloading media: $url');

      // Check if URL is already a local path
      if (_isLocalPath(url)) {
        print('ℹ️ URL is already a local path, returning as is: $url');
        return File(url).existsSync() ? url : null;
      }

      // Check if already downloaded
      final localPath = await getLocalMediaPath(url);
      if (localPath != null && await File(localPath).exists()) {
        print('✅ Media already cached: $localPath');
        return localPath;
      }

      // Download the file
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print('❌ Failed to download media: ${response.statusCode}');
        return null;
      }

      // Save to local storage
      final mediaDir = await getMediaDirectory();
      final fileName = _getFileNameFromUrl(url);
      final file = File('${mediaDir.path}/$fileName');

      await file.writeAsBytes(response.bodyBytes);

      // Save metadata
      await _saveMediaMetadata(url, file.path);

      print('✅ Media downloaded and cached: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Error downloading media: $e');
      return null;
    }
  }

  /// Get cached media file or download if not exists (for widgets)
  static Future<String?> getCachedMediaPath(String url) async {
    try {
      // Check if URL is already a local path
      if (_isLocalPath(url)) {
        return File(url).existsSync() ? url : null;
      }

      // Check if already cached
      final localPath = await getLocalMediaPath(url);
      if (localPath != null && await File(localPath).exists()) {
        return localPath;
      }

      // Download and cache if not exists
      return await downloadMedia(url);
    } catch (e) {
      print('❌ Error getting cached media: $e');
      return null;
    }
  }

  /// Get local path for a media URL if it exists
  static Future<String?> getLocalMediaPath(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataKey = '$_mediaMetadataPrefix${_hashUrl(url)}';
      final metadataJson = prefs.getString(metadataKey);
      
      if (metadataJson == null) return null;
      
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      final localPath = metadata['localPath'] as String;
      
      // Check if file still exists
      if (await File(localPath).exists()) {
        return localPath;
      } else {
        // Clean up metadata for missing file
        await prefs.remove(metadataKey);
        return null;
      }
    } catch (e) {
      print('❌ Error getting local media path: $e');
      return null;
    }
  }

  /// Save media metadata
  static Future<void> _saveMediaMetadata(String url, String localPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataKey = '$_mediaMetadataPrefix${_hashUrl(url)}';
      
      final metadata = {
        'url': url,
        'localPath': localPath,
        'downloadedAt': DateTime.now().toIso8601String(),
        'fileSize': await File(localPath).length(),
      };

      await prefs.setString(metadataKey, jsonEncode(metadata));
    } catch (e) {
      print('❌ Error saving media metadata: $e');
    }
  }


  /// Hash URL for consistent key generation
  static String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Check if URL is a local file path
  static bool _isLocalPath(String url) {
    // Check if it's a local file path
    if (url.startsWith('/') ||
        url.startsWith('file://') ||
        url.contains('/Documents/') ||
        url.contains('/Library/') ||
        url.contains('/var/mobile/')) {
      return true;
    }

    // Check if it's a valid HTTP/HTTPS URL
    try {
      final uri = Uri.parse(url);
      return !(uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      // If URI parsing fails, assume it's a local path
      return true;
    }
  }


  /// Clear all cached media
  static Future<void> clearAllMedia() async {
    try {
      print('🗑️ Clearing all media cache');

      final mediaDir = await getMediaDirectory();
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }

      // Clear metadata from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final mediaKeys = keys.where((key) => key.startsWith(_mediaMetadataPrefix));

      for (final key in mediaKeys) {
        await prefs.remove(key);
      }

      print('✅ All media cache cleared');
    } catch (e) {
      print('❌ Error clearing media cache: $e');
    }
  }

  /// Get total cache size and file count
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final mediaDir = await getMediaDirectory();
      if (!await mediaDir.exists()) {
        return {
          'totalFiles': 0,
          'totalSizeBytes': 0,
          'totalSizeMB': 0.0,
        };
      }

      final files = await mediaDir.list().toList();
      int totalSize = 0;
      int fileCount = 0;

      for (final file in files) {
        if (file is File) {
          fileCount++;
          final size = await file.length();
          totalSize += size;
        }
      }

      return {
        'totalFiles': fileCount,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Check if media is available offline
  static Future<bool> isMediaAvailableOffline(String url) async {
    final localPath = await getLocalMediaPath(url);
    return localPath != null && await File(localPath).exists();
  }
}