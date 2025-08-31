import 'package:duggy/models/message_image.dart';
import 'package:flutter/material.dart';
import '../../../models/club_message.dart';
import 'message_image_gallery_widget.dart';
import 'message_document_list_widget.dart';
import 'message_link_preview_widget.dart';

class MessageContentWidget extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;

  const MessageContentWidget({
    Key? key,
    required this.message,
    required this.isOwn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GIF message
        if (message.gifUrl != null)
          _buildGifMessage(message.gifUrl!, isOwn, context),

        // Text content (only if no images)
        if (message.content.isNotEmpty && message.pictures.isEmpty)
          _buildMessageContent(message, isOwn, context),

        // Images
        if (message.pictures.isNotEmpty) ...[
          MessageImageGalleryWidget(images: message.pictures, message: message),
          // Show captions below images in chat bubble
          ..._buildImageCaptions(message.pictures, message, context),
        ],

        // Documents
        if (message.documents.isNotEmpty)
          MessageDocumentListWidget(documents: message.documents),

        // Link previews
        if (message.linkMeta.isNotEmpty)
          MessageLinkPreviewWidget(linkMeta: message.linkMeta),
      ],
    );
  }

  Widget _buildGifMessage(String gifUrl, bool isOwn, BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: 300,
      ),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          gifUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: Color(0xFF06aeef),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageContent(
    ClubMessage message,
    bool isOwn,
    BuildContext context,
  ) {
    if (message.deleted) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Text(
              'This message was deleted',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Check if message is only emojis
    if (_isEmojiOnly(message.content)) {
      return _buildEmojiMessage(message.content, isOwn, context);
    }

    return _buildFormattedMessage(message.content, isOwn, context);
  }

  Widget _buildEmojiMessage(String content, bool isOwn, BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        content,
        style: TextStyle(fontSize: _getEmojiFontSize(content)),
      ),
    );
  }

  Widget _buildFormattedMessage(
    String content,
    bool isOwn,
    BuildContext context,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: SelectableText(
        content,
        style: TextStyle(
          fontSize: 16,
          color: isOwn
              ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87)
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87),
        ),
      ),
    );
  }

  List<Widget> _buildImageCaptions(
    List<MessageImage> pictures,
    ClubMessage message,
    BuildContext context,
  ) {
    List<Widget> captions = [];

    for (int i = 0; i < pictures.length; i++) {
      final image = pictures[i];
      if (image.caption != null && image.caption!.isNotEmpty) {
        captions.add(
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              image.caption!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black87,
              ),
            ),
          ),
        );
      }
    }

    return captions;
  }

  bool _isEmojiOnly(String text) {
    // Remove all whitespace
    final cleanText = text.replaceAll(RegExp(r'\s'), '');
    if (cleanText.isEmpty) return false;

    // Simple emoji detection - this is a basic implementation
    final emojiRegex = RegExp(
      r'[\u{1f300}-\u{1f5ff}]|[\u{1f900}-\u{1f9ff}]|[\u{1f600}-\u{1f64f}]|[\u{1f680}-\u{1f6ff}]|[\u{2600}-\u{26ff}]|[\u{2700}-\u{27bf}]|[\u{1f1e6}-\u{1f1ff}]|[\u{1f191}-\u{1f251}]|[\u{1f004}]|[\u{1f0cf}]|[\u{1f170}-\u{1f171}]|[\u{1f17e}-\u{1f17f}]|[\u{1f18e}]|[\u{3030}]|[\u{2b50}]|[\u{2b55}]|[\u{2934}-\u{2935}]|[\u{2b05}-\u{2b07}]|[\u{2b1b}-\u{2b1c}]|[\u{3297}]|[\u{3299}]|[\u{303d}]|[\u{00a9}]|[\u{00ae}]|[\u{2122}]|[\u{23f3}]|[\u{24c2}]|[\u{23e9}-\u{23ef}]|[\u{25b6}]|[\u{23f8}-\u{23fa}]',
      unicode: true,
    );

    // Count emojis in the text
    final matches = emojiRegex.allMatches(cleanText);
    final emojiCount = matches.length;

    // If the text consists only of emojis (and the emoji count matches the length)
    return emojiCount > 0 &&
        cleanText.length <= emojiCount * 2; // Account for multi-byte emojis
  }

  double _getEmojiFontSize(String content) {
    final emojiCount = content.replaceAll(RegExp(r'\s'), '').length;
    if (emojiCount == 1) return 48;
    if (emojiCount == 2) return 36;
    if (emojiCount <= 4) return 28;
    return 24;
  }
}
