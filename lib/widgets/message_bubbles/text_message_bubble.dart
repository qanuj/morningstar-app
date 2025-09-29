import 'package:duggy/models/club.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/media_item.dart';
import 'base_message_bubble.dart';
import '../image_gallery_screen.dart';
import '../svg_avatar.dart';
import '../markdown_mention_text.dart';
import '../../screens/shared/video_player_screen.dart';
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
  final List<ClubMessage>? allMessages;
  final Club club;

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
    this.allMessages, // Optional: List of all messages for unified media gallery
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

  Widget _buildSingleImage(BuildContext context, String imageUrl) {
    return GestureDetector(
      onTap: () => _openImageGallery(context, 0),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 300,
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SVGAvatar.image(imageUrl: imageUrl, width: 200, height: 200),
        ),
      ),
    );
  }

  Widget _buildTwoImages(BuildContext context, List<String> images) {
    return Container(
      height: 150,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openImageGallery(context, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SVGAvatar.image(
                  imageUrl: images[0],
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => _openImageGallery(context, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SVGAvatar.image(
                  imageUrl: images[1],
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleImages(BuildContext context, List<String> images) {
    return SizedBox(
      height: 280,
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: images.length > 4 ? 4 : images.length,
        itemBuilder: (context, index) {
          if (index == 3 && images.length > 4) {
            // Show "+X more" overlay on 4th image
            return GestureDetector(
              onTap: () => _openImageGallery(context, index),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SVGAvatar.image(
                      imageUrl: images[index],
                      width: 200,
                      height: 200,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '+${images.length - 3}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return GestureDetector(
            onTap: () => _openImageGallery(context, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SVGAvatar.image(
                imageUrl: images[index],
                width: 200,
                height: 200,
              ),
            ),
          );
        },
      ),
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
    // Get the MediaItem from the current message
    final mediaItems = message.media
        .where((item) => item.isImage || item.isVideo)
        .toList();

    if (mediaItems.isEmpty) return;

    final initialMediaItem = initialIndex < mediaItems.length
        ? mediaItems[initialIndex]
        : mediaItems.first;

    // Use all messages if available, otherwise fallback to current message
    final messagesToUse = allMessages ?? [message];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          messages: messagesToUse,
          initialMediaIndex: 0, // Will be recalculated in the gallery
          initialMediaUrl: initialMediaItem.url,
          club: club,
        ),
      ),
    );
  }

  void _openImageGallery(BuildContext context, int initialIndex) {
    // Redirect to new unified media gallery
    _openMediaGallery(context, initialIndex);
  }

  /// Build media gallery that handles both images and videos
  Widget _buildMediaGallery(BuildContext context) {
    final mediaItems = message.media;
    if (mediaItems.isEmpty) return SizedBox.shrink();

    // Show processing status if message is still being processed
    if (_isProcessingMessage()) {
      return _buildProcessingOverlay(context, mediaItems);
    }

    // Separate images and videos for mixed handling if needed
    final images = mediaItems.where((item) => item.isImage).toList();
    final videos = mediaItems.where((item) => item.isVideo).toList();

    return Column(
      children: [
        // Show images using existing image gallery logic
        if (images.isNotEmpty) _buildImageGalleryForMediaItems(context, images),
        // Show videos using video grid logic
        if (videos.isNotEmpty) ...[
          if (images.isNotEmpty) SizedBox(height: 8),
          _buildVideoGalleryForMediaItems(context, videos),
        ],
      ],
    );
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

  /// Build image gallery for specific MediaItem images
  Widget _buildImageGalleryForMediaItems(
    BuildContext context,
    List<MediaItem> images,
  ) {
    final imageUrls = images.map((item) => item.url).toList();
    if (images.length == 1) {
      return _buildSingleImage(context, imageUrls.first);
    } else if (images.length == 2) {
      return _buildTwoImages(context, imageUrls);
    } else {
      return _buildMultipleImages(context, imageUrls);
    }
  }

  /// Build video gallery for MediaItem videos
  Widget _buildVideoGalleryForMediaItems(
    BuildContext context,
    List<MediaItem> videos,
  ) {
    if (videos.length == 1) {
      return _buildSingleVideoFromMedia(context, videos.first);
    } else if (videos.length == 2) {
      return _buildTwoVideosFromMedia(context, videos);
    } else {
      // For 3+ videos, show first two and indicate more
      return _buildMultipleVideosFromMedia(context, videos);
    }
  }

  Widget _buildSingleVideoFromMedia(BuildContext context, MediaItem video) {
    return _buildVideoThumbnailFromMedia(
      context,
      video,
      width: double.infinity,
      height: 200,
    );
  }

  Widget _buildTwoVideosFromMedia(
    BuildContext context,
    List<MediaItem> videos,
  ) {
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(
            child: _buildVideoThumbnailFromMedia(
              context,
              videos[0],
              borderRadius: 8,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildVideoThumbnailFromMedia(
              context,
              videos[1],
              borderRadius: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleVideosFromMedia(
    BuildContext context,
    List<MediaItem> videos,
  ) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildVideoThumbnailFromMedia(context, videos[0]),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildVideoThumbnailFromMedia(context, videos[1]),
                ),
                if (videos.length > 2) ...[
                  SizedBox(height: 4),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildVideoThumbnailFromMedia(context, videos[2]),
                        if (videos.length > 3)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '+${videos.length - 2}',
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced method that uses MediaItem thumbnail information
  Widget _buildVideoThumbnailFromMedia(
    BuildContext context,
    MediaItem video, {
    double? width,
    double? height,
    double borderRadius = 8,
  }) {
    // Use the best available thumbnail (remote URL first, then local path)
    if (video.hasThumbnail) {
      final thumbnailSource = video.bestThumbnail!;
      final isRemoteUrl = thumbnailSource.startsWith('http');

      return GestureDetector(
        onTap: () => _playVideo(context, video.url),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.black12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Stack(
              children: [
                // Thumbnail image
                isRemoteUrl
                    ? Image.network(
                        thumbnailSource,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildVideoFallback(context, video.url),
                      )
                    : Image.file(
                        File(thumbnailSource),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildVideoFallback(context, video.url),
                      ),
                // Play button overlay
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                // Duration badge if available
                if (video.duration != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(video.duration!),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Fallback to VideoThumbnailWidget if no thumbnail available
    return _buildVideoFallback(
      context,
      video.url,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  Widget _buildVideoFallback(
    BuildContext context,
    String videoUrl, {
    double? width,
    double? height,
    double borderRadius = 8,
  }) {
    return VideoThumbnailWidget(
      videoUrl: videoUrl,
      onTap: () => _playVideo(context, videoUrl),
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _playVideo(BuildContext context, String videoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            VideoPlayerScreen(videoUrl: videoUrl, title: 'Video'),
      ),
    );
  }
}
