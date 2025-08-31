import 'package:duggy/models/link_metadata.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageLinkPreviewWidget extends StatelessWidget {
  final List<LinkMetadata> linkMeta;

  const MessageLinkPreviewWidget({super.key, required this.linkMeta});

  @override
  Widget build(BuildContext context) {
    if (linkMeta.isEmpty) return SizedBox.shrink();

    return Column(
      children: linkMeta
          .map((link) => _buildLinkPreview(context, link))
          .toList(),
    );
  }

  Widget _buildLinkPreview(BuildContext context, LinkMetadata link) {
    return GestureDetector(
      onTap: () => _openLink(context, link.url),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF06aeef).withOpacity(0.3),
            width: 1,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview (if available)
            if (link.image != null && link.image!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
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
                          color: Color(0xFF06aeef),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
              ),

            // Content
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  if (link.title != null && link.title!.isNotEmpty)
                    Text(
                      link.title!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Description
                  if (link.description != null &&
                      link.description!.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      link.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // URL
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.link, size: 16, color: Color(0xFF06aeef)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getDomainFromUrl(link.url),
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF06aeef),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  String _getDomainFromUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      return uri.host.toLowerCase();
    } catch (e) {
      return url;
    }
  }

  Future<void> _openLink(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog(context, 'Cannot open this link');
      }
    } catch (e) {
      _showErrorDialog(context, 'Error opening link: ${e.toString()}');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
