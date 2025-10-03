import 'package:duggy/models/club.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/media_item.dart';
import 'base_message_bubble.dart';
import '../svg_avatar.dart';
import '../markdown_mention_text.dart';
import '../video_player_widget.dart';

/// Text message bubble - renders images/videos first, then text body below
class TextMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final bool isLastFromSender;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;
  final Function(ClubMessage message, String emoji)? onReactionAdded;
  final Club club;
  final Function(String messageId, int mediaIndex)? onMediaTap;

  const TextMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.club,
    this.isSelected = false,
    this.showSenderInfo = false,
    this.isLastFromSender = false,
    this.onReactionRemoved,
    this.onReactionAdded,
    this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      showShadow: true,
      isLastFromSender: isLastFromSender,
      overlayBottomPosition: -2, // Move timestamp slightly down
      content: _buildContent(context),
      onReactionRemoved: onReactionRemoved,
      onReactionAdded: onReactionAdded,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sender name and role for received messages
        if (!isOwn && showSenderInfo) ...[
          _buildSenderInfo(context),
          SizedBox(height: 4),
        ],

        // Media first (images and videos)
        if (message.media.isNotEmpty) ...[
          _buildMediaGallery(context),
          if (message.content.trim().isNotEmpty || message.document != null)
            SizedBox(height: 8),
        ],

        // Document (if any)
        if (message.document != null) ...[
          _buildDocumentCard(context),
          if (message.content.trim().isNotEmpty) SizedBox(height: 8),
        ],

        // Text content below media (if any)
        if (message.content.trim().isNotEmpty) _buildTextContent(context),

        // Add bottom padding for media when no text content (for meta overlay space)
        if (message.media.isNotEmpty && message.content.trim().isEmpty)
          SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDocumentCard(BuildContext context) {
    final doc = message.document!;
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isOwn
            ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(
                      0.1,
                    ) // Light overlay on blue background in dark mode
                  : Colors.black.withOpacity(
                      0.05,
                    )) // Subtle dark overlay on light cyan in light mode
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getDocumentIcon(doc.filename),
            color: isOwn
                ? (Theme.of(context).brightness == Brightness.dark
                      ? Colors
                            .white // White icons on blue background in dark mode
                      : Colors
                            .black87) // Dark icons on light cyan background in light mode
                : Theme.of(context).primaryColor,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.filename,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isOwn
                        ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors
                                    .white // White text on blue background in dark mode
                              : Colors
                                    .black87) // Black text on light cyan background in light mode
                        : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (doc.size != null)
                  Text(
                    doc.size!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOwn
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors
                                      .white70 // Light white text on blue background in dark mode
                                : Colors
                                      .black54) // Dark text on light cyan background in light mode
                          : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.download,
            color: isOwn
                ? (Theme.of(context).brightness == Brightness.dark
                      ? Colors
                            .white // White icons on blue background in dark mode
                      : Colors
                            .black87) // Dark icons on light cyan background in light mode
                : Theme.of(context).primaryColor,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildSenderInfo(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4), // Add left padding for sender name
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.senderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF06aeef)
                  : Color(0xFF003f9b),
            ),
          ),
          // Role icon for Admin and Owner only
          if (message.senderRole != null &&
              (message.senderRole!.toUpperCase() == 'ADMIN' ||
                  message.senderRole!.toUpperCase() == 'OWNER')) ...[
            SizedBox(width: 4),
            Icon(
              message.senderRole!.toUpperCase() == 'OWNER'
                  ? Icons.star
                  : Icons.shield,
              size: 12,
              color: message.senderRole!.toUpperCase() == 'OWNER'
                  ? Colors.orange
                  : Colors.purple,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 170),
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: 4,
        bottom: isLastFromSender
            ? 0
            : 4, // Remove bottom padding for last message to allow shadow space
      ),
      child: MarkdownMentionText(
        text: message.content,
        mentions: message.mentions,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isOwn
              ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors
                          .white // White text on blue background in dark mode
                    : Colors
                          .black87) // Black text on light cyan background in light mode
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87),
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _openMediaGallery(BuildContext context, int initialIndex) {
    // Simply call the callback with message ID and media index
    if (onMediaTap != null) {
      onMediaTap!(message.id, initialIndex);
    } else {
      debugPrint('❌ No onMediaTap callback provided');
    }
  }

  /// Build media gallery that handles both images and videos as unified grid
  Widget _buildMediaGallery(BuildContext context) {
    final mediaItems = message.media;
    if (mediaItems.isEmpty) {
      return SizedBox.shrink();
    }

    // Show processing status if message is still being processed
    if (_isProcessingMessage()) {
      return _buildProcessingOverlay(context, mediaItems);
    }

    // Build unified media grid (images and videos together)
    return _buildUnifiedMediaGrid(context, mediaItems);
  }

  bool _isProcessingMessage() {
    return message.status == MessageStatus.preparing ||
        message.status == MessageStatus.compressing ||
        message.status == MessageStatus.uploading;
  }

  Widget _buildProcessingOverlay(
    BuildContext context,
    List<MediaItem> mediaItems,
  ) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Show blurred/faded preview if available
          if (mediaItems.isNotEmpty) ...[
            _buildMediaPreview(context, mediaItems.first),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],

          // Processing indicator
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    value: _getOverallProgress(),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  message.processingStatus ?? 'Processing...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_getOverallProgress() != null) ...[
                  SizedBox(height: 4),
                  Text(
                    '${(_getOverallProgress()! * 100).round()}%',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _getOverallProgress() {
    final mediaItems = message.media;
    if (mediaItems.isEmpty) return null;

    double totalProgress = 0;
    int itemsWithProgress = 0;

    for (final item in mediaItems) {
      if (item.compressionProgress != null) {
        totalProgress += item.compressionProgress!;
        itemsWithProgress++;
      } else if (item.uploadProgress != null) {
        totalProgress += item.uploadProgress!;
        itemsWithProgress++;
      }
    }

    if (itemsWithProgress == 0) return null;
    return totalProgress / itemsWithProgress / 100;
  }

  Widget _buildMediaPreview(BuildContext context, MediaItem item) {
    if (item.isVideo) {
      // Use best available thumbnail (remote URL first, then local path)
      if (item.hasThumbnail) {
        final thumbnailSource = item.bestThumbnail!;
        final isRemoteUrl = thumbnailSource.startsWith('http');

        return isRemoteUrl
            ? Image.network(
                thumbnailSource,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    VideoThumbnailWidget(
                      videoUrl: item.url,
                      onTap: () {},
                      borderRadius: 12,
                    ),
              )
            : Image.file(
                File(thumbnailSource),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    VideoThumbnailWidget(
                      videoUrl: item.url,
                      onTap: () {},
                      borderRadius: 12,
                    ),
              );
      } else {
        return VideoThumbnailWidget(
          videoUrl: item.url,
          onTap: () {},
          borderRadius: 12,
        );
      }
    } else {
      return item.isLocal
          ? Image.file(
              File(item.url),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Image.network(
              item.url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            );
    }
  }

  /// Build unified media grid for all media types (images and videos together)
  Widget _buildUnifiedMediaGrid(
    BuildContext context,
    List<MediaItem> mediaItems,
  ) {
    if (mediaItems.length == 1) {
      return _buildSingleMediaItem(context, mediaItems.first);
    } else if (mediaItems.length == 2) {
      return _buildTwoMediaItems(context, mediaItems);
    } else if (mediaItems.length == 3) {
      return _buildThreeMediaItems(context, mediaItems);
    } else {
      return _buildFourPlusMediaItems(context, mediaItems);
    }
  }

  Widget _buildSingleMediaItem(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () => _openMediaGallery(context, 0),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 300,
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildMediaItemWidget(context, item),
        ),
      ),
    );
  }

  Widget _buildTwoMediaItems(BuildContext context, List<MediaItem> items) {
    return Container(
      height: 150,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openMediaGallery(context, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildMediaItemWidget(context, items[0]),
              ),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => _openMediaGallery(context, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildMediaItemWidget(context, items[1]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeMediaItems(BuildContext context, List<MediaItem> items) {
    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _openMediaGallery(context, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildMediaItemWidget(context, items[0]),
              ),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openMediaGallery(context, 1),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildMediaItemWidget(context, items[1]),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openMediaGallery(context, 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildMediaItemWidget(context, items[2]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourPlusMediaItems(BuildContext context, List<MediaItem> items) {
    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _openMediaGallery(context, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildMediaItemWidget(context, items[0]),
              ),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openMediaGallery(context, 1),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildMediaItemWidget(context, items[1]),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openMediaGallery(context, 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          _buildMediaItemWidget(context, items[2]),
                          if (items.length > 3)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '+${items.length - 3}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItemWidget(BuildContext context, MediaItem item) {
    if (item.isVideo) {
      // For videos, show thumbnail with play button overlay
      if (item.hasThumbnail) {
        final thumbnailSource = item.bestThumbnail!;
        final isRemoteUrl = thumbnailSource.startsWith('http');

        return Stack(
          children: [
            // Thumbnail
            isRemoteUrl
                ? Image.network(
                    thumbnailSource,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.videocam, color: Colors.grey[600]),
                    ),
                  )
                : Image.file(
                    File(thumbnailSource),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.videocam, color: Colors.grey[600]),
                    ),
                  ),
            // Play button overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        );
      } else {
        // Fallback for videos without thumbnails
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Icon(Icons.videocam, color: Colors.grey[600], size: 32),
          ),
        );
      }
    } else {
      // For images
      return SVGAvatar.image(
        imageUrl: item.url,
        width: double.infinity,
        height: double.infinity,
      );
    }
  }
}
