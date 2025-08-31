import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/club_message.dart';
import '../../models/link_metadata.dart';
import 'base_message_bubble.dart';

/// Link message bubble - shows thumbnail, title, and full link
class LinkMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;

  const LinkMessageBubble({
    Key? key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      content: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Link previews first
        ...message.linkMeta.map((link) => _buildLinkPreview(context, link)),

        // Optional text content below links
        if (message.content.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              fontSize: 16,
              color: isOwn
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLinkPreview(BuildContext context, LinkMetadata link) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isOwn
              ? Colors.white.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
        color: isOwn
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
      ),
      child: InkWell(
        onTap: () => _launchUrl(link.url),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail image (if available)
            if (link.image != null && link.image!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  child: Image.network(
                    link.image!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[300],
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
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.link,
                        size: 48,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),

            // Content area with title, description, and URL
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  if (link.title != null && link.title!.isNotEmpty) ...[
                    Text(
                      link.title!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isOwn
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                  ],

                  // Description
                  if (link.description != null &&
                      link.description!.isNotEmpty) ...[
                    Text(
                      link.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isOwn
                            ? Colors.white.withOpacity(0.8)
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.grey[600]),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                  ],

                  // Full URL
                  Row(
                    children: [
                      // Favicon (if available)
                      if (link.favicon != null && link.favicon!.isNotEmpty) ...[
                        Container(
                          width: 16,
                          height: 16,
                          margin: EdgeInsets.only(right: 6),
                          child: Image.network(
                            link.favicon!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.language, size: 16),
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.language,
                          size: 16,
                          color: isOwn
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey[500],
                        ),
                        SizedBox(width: 6),
                      ],

                      Expanded(
                        child: Text(
                          _formatUrl(link.url),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOwn
                                ? Colors.white.withOpacity(0.7)
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.grey[500]),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: isOwn
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[500],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host + (uri.path.isNotEmpty ? uri.path : '');
    } catch (e) {
      return url;
    }
  }

  void _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
