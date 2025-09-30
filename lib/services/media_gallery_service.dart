import '../models/club_message.dart';
import '../models/media_item.dart';
import '../models/message_status.dart';

/// Lightweight media reference for memory efficiency
class MediaReference {
  final String url;
  final String messageId;
  final DateTime timestamp;
  final String senderName;
  final String? caption;
  final String contentType;
  final double? duration;
  final String? thumbnailUrl;
  final String? thumbnailPath;
  final bool isLocal;

  MediaReference({
    required this.url,
    required this.messageId,
    required this.timestamp,
    required this.senderName,
    this.caption,
    required this.contentType,
    this.duration,
    this.thumbnailUrl,
    this.thumbnailPath,
    required this.isLocal,
  });

  bool get isVideo => contentType == 'video';
  bool get isImage => contentType == 'image';
  String? get bestThumbnail => thumbnailUrl ?? thumbnailPath;
  bool get hasThumbnail => thumbnailUrl != null || thumbnailPath != null;

  /// Convert back to MediaItem for gallery display
  MediaItem toMediaItem() {
    return MediaItem(
      url: url,
      contentType: contentType,
      caption: caption,
      duration: duration,
      thumbnailUrl: thumbnailUrl,
      thumbnailPath: thumbnailPath,
      isLocal: isLocal,
    );
  }
}

/// Memory-efficient media gallery service
class MediaGalleryService {
  static final Map<String, List<MediaReference>> _clubMediaCache = {};

  /// Build lightweight media index from messages list
  static List<MediaReference> buildMediaIndex(List<ClubMessage> messages) {
    final List<MediaReference> mediaIndex = [];

    for (final message in messages) {
      if (message.media.isNotEmpty) {
        for (final mediaItem in message.media) {
          // Only include images and videos
          if (mediaItem.isImage || mediaItem.isVideo) {
            mediaIndex.add(
              MediaReference(
                url: mediaItem.url,
                messageId: message.id,
                timestamp: message.createdAt,
                senderName: message.senderName,
                caption: mediaItem.caption,
                contentType: mediaItem.contentType,
                duration: mediaItem.duration,
                thumbnailUrl: mediaItem.thumbnailUrl,
                thumbnailPath: mediaItem.thumbnailPath,
                isLocal: mediaItem.isLocal,
              ),
            );
          }
        }
      }
    }

    // Sort by timestamp (oldest first for chronological viewing)
    mediaIndex.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return mediaIndex;
  }

  /// Find index of specific media URL in the media index
  static int findMediaIndex(List<MediaReference> mediaIndex, String targetUrl) {
    for (int i = 0; i < mediaIndex.length; i++) {
      if (mediaIndex[i].url == targetUrl) {
        return i;
      }
    }
    return 0; // Fallback to first item if not found
  }

  /// Cache media index for a club to avoid rebuilding
  static void cacheClubMediaIndex(
    String clubId,
    List<MediaReference> mediaIndex,
  ) {
    _clubMediaCache[clubId] = mediaIndex;
  }

  /// Get cached media index for a club
  static List<MediaReference>? getCachedClubMediaIndex(String clubId) {
    return _clubMediaCache[clubId];
  }

  /// Clear cache for a specific club
  static void clearClubCache(String clubId) {
    _clubMediaCache.remove(clubId);
  }

  /// Clear all cache
  static void clearAllCache() {
    _clubMediaCache.clear();
  }

  /// Get media index size (for debugging/monitoring)
  static int getIndexSize(List<MediaReference> mediaIndex) {
    return mediaIndex.length;
  }
}

/// MediaWithMessage class for gallery compatibility
class MediaWithMessage {
  final MediaItem mediaItem;
  final ClubMessage message;

  MediaWithMessage({required this.mediaItem, required this.message});
}
