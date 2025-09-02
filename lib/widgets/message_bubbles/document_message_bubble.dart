import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import 'base_message_bubble.dart';

/// Document message bubble - clean and simple document display
class DocumentMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final VoidCallback? onRetryUpload;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;

  const DocumentMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
    this.showSenderInfo = false,
    this.onRetryUpload,
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
      content: _buildContent(context),
      onReactionRemoved: onReactionRemoved,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Single document card
        if (message.document != null)
          _buildDocumentCard(message.document!)
        else
          _buildUploadingCard(),

        // Text content
        if (message.content.trim().isNotEmpty) _buildTextContent(),

        // Retry button for failed uploads
        if (message.status == MessageStatus.failed && onRetryUpload != null)
          _buildRetryButton(),
      ],
    );
  }

  Widget _buildDocumentCard(document) {
    final canOpen = message.status != MessageStatus.failed;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canOpen ? () => _openDocument(document.url) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildFileIcon(document.type),
                const SizedBox(width: 12),
                Expanded(child: _buildFileInfo(document)),
                _buildStatusIcon(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingCard() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildFileIcon(''),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.status == MessageStatus.failed
                        ? 'Upload failed'
                        : 'Uploading...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textColor(),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.status == MessageStatus.failed
                        ? 'Tap retry to try again'
                        : 'Please wait',
                    style: TextStyle(
                      fontSize: 12,
                      color: _secondaryTextColor(),
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(String type) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getFileTypeColor(type),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(_getFileTypeIcon(type), color: Colors.white, size: 20),
    );
  }

  Widget _buildFileInfo(document) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          document.filename,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textColor(),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${_getFileTypeDisplayName(document.type)}${document.size != null ? ' • ${document.size}' : ''}',
          style: TextStyle(fontSize: 12, color: _secondaryTextColor()),
        ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    const size = 16.0;

    if (message.status == MessageStatus.sending) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_secondaryTextColor()),
        ),
      );
    } else if (message.status == MessageStatus.failed) {
      return Icon(Icons.error_outline, size: size, color: Colors.red);
    } else {
      return Icon(Icons.download, size: size, color: _secondaryTextColor());
    }
  }

  Widget _buildTextContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        message.content,
        style: TextStyle(fontSize: 16, color: _textColor(), height: 1.3),
      ),
    );
  }

  Widget _buildRetryButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onRetryUpload,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 16, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              'Retry upload',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Styling helpers
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: isOwn ? Colors.white.withOpacity(0.2) : Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: message.status == MessageStatus.failed
            ? Colors.red.withOpacity(0.5)
            : (isOwn ? Colors.white.withOpacity(0.3) : Colors.grey[300]!),
        width: 1,
      ),
    );
  }

  Color _textColor() => isOwn ? Colors.black87 : Colors.black87;
  Color _secondaryTextColor() =>
      isOwn ? Colors.black87.withOpacity(0.8) : Colors.grey[600]!;

  Color _getFileTypeColor(String type) {
    // Using brand colors - Light Blue (#06aeef) as primary brand color
    switch (type.toLowerCase()) {
      case 'pdf':
        return const Color(0xFF06aeef); // Brand Light Blue
      case 'doc':
      case 'docx':
        return const Color(0xFF2196F3);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF4CAF50);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFFF9800);
      case 'txt':
        return const Color(0xFF607D8B);
      default:
        return const Color(0xFF06aeef); // Default to brand color
    }
  }

  IconData _getFileTypeIcon(String type) {
    switch (type.toLowerCase()) {
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
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileTypeDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'Word';
      case 'xls':
      case 'xlsx':
        return 'Excel';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint';
      case 'txt':
        return 'Text';
      default:
        return 'Document';
    }
  }

  Future<void> _openDocument(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening document: $e');
    }
  }
}
