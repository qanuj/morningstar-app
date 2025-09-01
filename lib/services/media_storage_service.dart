import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class MediaStorageService {
  static const String _mediaMetadataPrefix = 'media_meta_';
  static const String _mediaDownloadsPrefix = 'media_downloads_';
  
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
    final lastDot = path.lastIndexOf('.');
    if (lastDot != -1 && lastDot < path.length - 1) {
      return path.substring(lastDot);
    }
    return '.bin'; // Default extension
  }

  /// Download and cache a media file
  static Future<String?> downloadMedia(String url, {String? clubId}) async {
    try {
      print('📥 Downloading media: $url');
      
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
      await _saveMediaMetadata(url, file.path, clubId);
      
      print('✅ Media downloaded and cached: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Error downloading media: $e');
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
  static Future<void> _saveMediaMetadata(String url, String localPath, String? clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataKey = '$_mediaMetadataPrefix${_hashUrl(url)}';
      
      final metadata = {
        'url': url,
        'localPath': localPath,
        'downloadedAt': DateTime.now().toIso8601String(),
        'clubId': clubId,
        'fileSize': await File(localPath).length(),
      };
      
      await prefs.setString(metadataKey, jsonEncode(metadata));
      
      // Add to downloads list for club
      if (clubId != null) {
        await _addToClubDownloads(clubId, url);
      }
    } catch (e) {
      print('❌ Error saving media metadata: $e');
    }
  }

  /// Add media URL to club downloads list
  static Future<void> _addToClubDownloads(String clubId, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsKey = '$_mediaDownloadsPrefix$clubId';
      
      final existingJson = prefs.getString(downloadsKey);
      List<String> downloads = [];
      
      if (existingJson != null) {
        downloads = List<String>.from(jsonDecode(existingJson));
      }
      
      if (!downloads.contains(url)) {
        downloads.add(url);
        await prefs.setString(downloadsKey, jsonEncode(downloads));
      }
    } catch (e) {
      print('❌ Error adding to club downloads: $e');
    }
  }

  /// Hash URL for consistent key generation
  static String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Download all media for a club's messages
  static Future<void> downloadAllMediaForClub(String clubId, List<Map<String, dynamic>> mediaUrls) async {
    print('📥 Starting bulk media download for club $clubId (${mediaUrls.length} items)');
    
    int downloaded = 0;
    int failed = 0;
    int skipped = 0;
    
    for (final mediaInfo in mediaUrls) {
      final url = mediaInfo['url'] as String;
      final type = mediaInfo['type'] as String? ?? 'unknown';
      
      try {
        // Check if already downloaded
        final localPath = await getLocalMediaPath(url);
        if (localPath != null && await File(localPath).exists()) {
          skipped++;
          continue;
        }
        
        // Download media
        final result = await downloadMedia(url, clubId: clubId);
        if (result != null) {
          downloaded++;
          print('✅ Downloaded $type: $url');
        } else {
          failed++;
          print('❌ Failed to download $type: $url');
        }
        
        // Small delay to avoid overwhelming the server
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        failed++;
        print('❌ Error downloading $type ($url): $e');
      }
    }
    
    print('📥 Bulk download complete for club $clubId:');
    print('   Downloaded: $downloaded, Skipped: $skipped, Failed: $failed');
  }

  /// Get all media URLs from a list of messages
  static List<Map<String, dynamic>> extractMediaUrls(List<dynamic> messages) {
    final List<Map<String, dynamic>> mediaUrls = [];
    
    for (final message in messages) {
      if (message is! Map<String, dynamic>) continue;
      
      // Extract images
      final pictures = message['pictures'] as List<dynamic>? ?? [];
      for (final picture in pictures) {
        if (picture is Map<String, dynamic> && picture['url'] != null) {
          mediaUrls.add({
            'url': picture['url'],
            'type': 'image',
            'messageId': message['id'],
          });
        }
      }
      
      // Extract documents
      final documents = message['documents'] as List<dynamic>? ?? [];
      for (final document in documents) {
        if (document is Map<String, dynamic> && document['url'] != null) {
          mediaUrls.add({
            'url': document['url'],
            'type': 'document',
            'messageId': message['id'],
            'filename': document['filename'] ?? 'document',
          });
        }
      }
      
      // Extract audio
      final audio = message['audio'] as Map<String, dynamic>?;
      if (audio != null && audio['url'] != null) {
        mediaUrls.add({
          'url': audio['url'],
          'type': 'audio',
          'messageId': message['id'],
          'duration': audio['duration'],
        });
      }
      
      // Extract GIFs
      if (message['gifUrl'] != null) {
        mediaUrls.add({
          'url': message['gifUrl'],
          'type': 'gif',
          'messageId': message['id'],
        });
      }
    }
    
    return mediaUrls;
  }

  /// Clear all cached media for a club
  static Future<void> clearClubMedia(String clubId) async {
    try {
      print('🗑️ Clearing media cache for club $clubId');
      
      final prefs = await SharedPreferences.getInstance();
      final downloadsKey = '$_mediaDownloadsPrefix$clubId';
      final downloadsJson = prefs.getString(downloadsKey);
      
      if (downloadsJson != null) {
        final downloads = List<String>.from(jsonDecode(downloadsJson));
        
        for (final url in downloads) {
          final localPath = await getLocalMediaPath(url);
          if (localPath != null) {
            final file = File(localPath);
            if (await file.exists()) {
              await file.delete();
            }
            
            // Remove metadata
            final metadataKey = '$_mediaMetadataPrefix${_hashUrl(url)}';
            await prefs.remove(metadataKey);
          }
        }
        
        // Remove downloads list
        await prefs.remove(downloadsKey);
      }
      
      print('✅ Media cache cleared for club $clubId');
    } catch (e) {
      print('❌ Error clearing club media: $e');
    }
  }

  /// Get storage statistics for a club
  static Future<Map<String, dynamic>> getStorageStats(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsKey = '$_mediaDownloadsPrefix$clubId';
      final downloadsJson = prefs.getString(downloadsKey);
      
      if (downloadsJson == null) {
        return {
          'totalFiles': 0,
          'totalSizeBytes': 0,
          'totalSizeMB': 0.0,
          'byType': <String, int>{},
        };
      }
      
      final downloads = List<String>.from(jsonDecode(downloadsJson));
      int totalSize = 0;
      final typeCount = <String, int>{};
      int existingFiles = 0;
      
      for (final url in downloads) {
        final localPath = await getLocalMediaPath(url);
        if (localPath != null && await File(localPath).exists()) {
          existingFiles++;
          final file = File(localPath);
          final size = await file.length();
          totalSize += size;
          
          // Determine type from extension
          final extension = _getFileExtension(url);
          final type = _getTypeFromExtension(extension);
          typeCount[type] = (typeCount[type] ?? 0) + 1;
        }
      }
      
      return {
        'totalFiles': existingFiles,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)),
        'byType': typeCount,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Get type from file extension
  static String _getTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
        return 'image';
      case '.mp3':
      case '.wav':
      case '.m4a':
      case '.aac':
        return 'audio';
      case '.pdf':
      case '.doc':
      case '.docx':
      case '.txt':
        return 'document';
      case '.mp4':
      case '.mov':
      case '.avi':
        return 'video';
      default:
        return 'other';
    }
  }

  /// Check if media is available offline
  static Future<bool> isMediaAvailableOffline(String url) async {
    final localPath = await getLocalMediaPath(url);
    return localPath != null && await File(localPath).exists();
  }
}