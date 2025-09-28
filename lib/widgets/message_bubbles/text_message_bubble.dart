import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import 'base_message_bubble.dart';
import '../image_gallery_screen.dart';
import '../svg_avatar.dart';
import '../markdown_mention_text.dart';

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

  const TextMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
    this.showSenderInfo = false,
    this.isLastFromSender = false,
    this.onReactionRemoved,
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

        // Images first (if any)
        if (message.images.isNotEmpty) ...[
          _buildImageGallery(context),
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

        // Add bottom padding for images when no text content (for meta overlay space)
        if (message.images.isNotEmpty && message.content.trim().isEmpty)
          SizedBox(height: 16),
      ],
    );
  }

  Widget _buildImageGallery(BuildContext context) {
    return Stack(
      children: [
        _buildImageGrid(context),
        // Show upload progress overlay if message is sending
        if (message.status == MessageStatus.sending)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Uploading...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    final images = message.images;

    if (images.length == 1) {
      return _buildSingleImage(context, images[0]);
    } else if (images.length == 2) {
      return _buildTwoImages(context, images);
    } else if (images.length == 3) {
      return _buildThreeImages(context, images);
    } else {
      return _buildMultipleImages(context, images);
    }
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

  Widget _buildThreeImages(BuildContext context, List<String> images) {
    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(
            flex: 2,
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
            child: Column(
              children: [
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
                SizedBox(height: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openImageGallery(context, 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SVGAvatar.image(
                        imageUrl: images[2],
                        width: 200,
                        height: 200,
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

  Widget _buildMultipleImages(BuildContext context, List<String> images) {
    return Container(
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

  void _openImageGallery(BuildContext context, int initialIndex) {
    // Get the URL of the initial image to display
    final initialImageUrl = initialIndex < message.images.length
        ? message.images[initialIndex]
        : message.images.first;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryScreen(
          messages: [message], // Pass the current message
          initialImageIndex: initialIndex,
          initialImageUrl: initialImageUrl,
        ),
      ),
    );
  }
}
