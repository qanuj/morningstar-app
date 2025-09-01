import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/message_image.dart';
import 'base_message_bubble.dart';
import '../image_gallery_screen.dart';

/// Text message bubble - renders images/videos first, then text body below
class TextMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;

  const TextMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
    this.showSenderInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      showShadow: true,
      content: _buildContent(context),
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
        if (message.pictures.isNotEmpty) ...[
          _buildImageGallery(context),
          if (message.content.trim().isNotEmpty || message.documents.isNotEmpty)
            SizedBox(height: 8),
        ],

        // Documents (if any)
        if (message.documents.isNotEmpty) ...[
          _buildDocumentList(context),
          if (message.content.trim().isNotEmpty) SizedBox(height: 8),
        ],

        // Text content below media (if any)
        if (message.content.trim().isNotEmpty) _buildTextContent(context),
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
    final images = message.pictures;

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

  Widget _buildSingleImage(BuildContext context, MessageImage image) {
    return GestureDetector(
      onTap: () => _openImageGallery(context, 0),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 300,
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            image.url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              color: Colors.grey[300],
              child: Icon(Icons.broken_image, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImages(BuildContext context, List<MessageImage> images) {
    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openImageGallery(context, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(images[0].url, fit: BoxFit.cover),
              ),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => _openImageGallery(context, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(images[1].url, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeImages(BuildContext context, List<MessageImage> images) {
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
                child: Image.network(images[0].url, fit: BoxFit.cover),
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
                      child: Image.network(images[1].url, fit: BoxFit.cover),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openImageGallery(context, 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(images[2].url, fit: BoxFit.cover),
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

  Widget _buildMultipleImages(BuildContext context, List<MessageImage> images) {
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
                    child: Image.network(
                      images[index].url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
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
              child: Image.network(
                images[index].url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentList(BuildContext context) {
    return Column(
      children: message.documents
          .map(
            (doc) => Container(
              margin: EdgeInsets.only(bottom: 4),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOwn
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getDocumentIcon(doc.filename),
                    color: isOwn
                        ? Colors.white
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
                            color: isOwn ? Colors.white : Colors.black87,
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
                                  ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : Color(0xFF003f9b).withOpacity(0.7))
                                  : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.download,
                    color: isOwn
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSenderInfo(BuildContext context) {
    return Row(
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
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 170),
      child: Text(
        message.content,
        style: TextStyle(
          fontSize: 14,
          color: isOwn
              ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Color(0xFF003f9b)) // Dark blue for light backgrounds
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
    final initialImageUrl = initialIndex < message.pictures.length
        ? message.pictures[initialIndex].url
        : message.pictures.first.url;

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
