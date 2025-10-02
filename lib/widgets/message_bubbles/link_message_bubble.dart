import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../models/club_message.dart';
import '../../models/link_metadata.dart';
import '../../providers/theme_provider.dart';
import '../../services/open_graph_service.dart';
import '../../services/message_storage_service.dart';
import '../svg_avatar.dart';
import 'base_message_bubble.dart';

/// Link message bubble - shows thumbnail, title, and full link
/// Handles lazy OpenGraph fetching for received messages based on user settings
class LinkMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final Function(String messageId, String emoji, String userId)? onReactionRemoved;

  const LinkMessageBubble({
    Key? key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
    this.onReactionRemoved,
  }) : super(key: key);

  @override
  State<LinkMessageBubble> createState() => _LinkMessageBubbleState();
}

class _LinkMessageBubbleState extends State<LinkMessageBubble> {
  LinkMetadata? _lazyLoadedMetadata;
  bool _isLoadingMetadata = false;
  String? _detectedUrl;

  @override
  void initState() {
    super.initState();
    _initializeLinkData();
  }

  void _initializeLinkData() {
    // For sent messages (isOwn), use existing metadata from MessageInput
    if (widget.isOwn && widget.message.linkMeta.isNotEmpty) {
      return; // Already has metadata from sending
    }

    // For received messages, check if metadata is already cached
    if (!widget.isOwn) {
      _detectedUrl = _extractUrlFromContent(widget.message.content);

      // Check if we already have cached metadata for this message
      if (widget.message.linkMeta.isNotEmpty) {
        print('🔗 [LinkBubble] Found cached linkMeta for message: ${widget.message.linkMeta.first.url}');
        setState(() {
          _lazyLoadedMetadata = widget.message.linkMeta.first;
        });
        return; // Use cached metadata
      }

      // If no cached metadata and URL detected, always load it for local storage
      // (Display will still respect user's link preview setting)
      if (_detectedUrl != null) {
        print('🔗 [LinkBubble] No cached metadata, fetching for URL: $_detectedUrl');
        _loadMetadataIfEnabled();
      }
    }
  }

  String? _extractUrlFromContent(String content) {
    final urlPattern = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(content);
    return match?.group(0);
  }

  void _loadMetadataIfEnabled() async {
    if (_detectedUrl == null) {
      return;
    }

    setState(() {
      _isLoadingMetadata = true;
    });

    try {
      final ogData = await OpenGraphService.fetchMetadata(_detectedUrl!);
      final metadata = LinkMetadata(
        url: ogData.url,
        title: ogData.title,
        description: ogData.description,
        image: ogData.image,
        siteName: ogData.siteName ?? Uri.parse(_detectedUrl!).host,
        favicon: ogData.favicon,
      );

      // Always update local cache with metadata (locally only, not sent to server)
      await _updateMessageCache(metadata);

      if (mounted) {
        setState(() {
          _lazyLoadedMetadata = metadata;
          _isLoadingMetadata = false;
        });
      }
    } catch (e) {
      print('❌ Failed to fetch link metadata for received message: $e');
      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
        });
      }
    }
  }

  Future<void> _updateMessageCache(LinkMetadata metadata) async {
    try {
      // Update message in cache with metadata (local only)
      final updatedMessage = widget.message.copyWith(
        linkMeta: [metadata],
        meta: metadata.toJson(),
      );

      print('🔗 [LinkBubble] Updating message cache with linkMeta: ${metadata.url}');

      // Use MessageStorageService to update the cached message
      await MessageStorageService.updateMessage(widget.message.clubId, updatedMessage);

      print('✅ [LinkBubble] Successfully updated message cache with linkMeta');
    } catch (e) {
      print('❌ Failed to update message cache with metadata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: widget.message,
      isOwn: widget.isOwn,
      isPinned: widget.isPinned,
      isSelected: widget.isSelected,
      content: _buildContent(context),
      onReactionRemoved: widget.onReactionRemoved,
    );
  }

  Widget _buildContent(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Determine which metadata to use
    List<LinkMetadata> linkMetadata = [];

    if (widget.message.linkMeta.isNotEmpty) {
      // Use cached metadata from message (works for both sent and received messages)
      linkMetadata = widget.message.linkMeta;
    } else if (!widget.isOwn && _lazyLoadedMetadata != null) {
      // Fallback to lazy-loaded metadata for received messages
      linkMetadata = [_lazyLoadedMetadata!];
    }

    // Show link preview only if user has enabled link previews
    final shouldShowPreview = themeProvider.linkPreviewEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Link previews first (if available and enabled)
        if (shouldShowPreview && linkMetadata.isNotEmpty)
          ...linkMetadata.map((link) => _buildLinkPreview(context, link)),

        // Loading state for received messages (if preview enabled)
        if (shouldShowPreview && !widget.isOwn && _isLoadingMetadata && linkMetadata.isEmpty)
          _buildLoadingPreview(context),

        // Text content with clickable links
        if (widget.message.content.isNotEmpty) ...[
          if (shouldShowPreview && (linkMetadata.isNotEmpty || _isLoadingMetadata)) SizedBox(height: 8),
          _buildTextWithClickableLinks(context),
        ],

        // Show URL only if no preview is available or loading failed, OR if previews are disabled
        if (!widget.isOwn &&
            _detectedUrl != null &&
            ((!shouldShowPreview) || (linkMetadata.isEmpty && !_isLoadingMetadata)))
          _buildSimpleLinkText(context),
      ],
    );
  }

  Widget _buildLoadingPreview(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isOwn
              ? Colors.white.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
        color: widget.isOwn
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Loading link preview...',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextWithClickableLinks(BuildContext context) {
    final content = widget.message.content;
    final urlPattern = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?',
      caseSensitive: false,
    );

    final matches = urlPattern.allMatches(content);
    if (matches.isEmpty) {
      return Text(
        content,
        style: TextStyle(
          fontSize: 16,
          color: _getTextColor(context),
        ),
      );
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      // Add text before the link
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: content.substring(lastMatchEnd, match.start),
        ));
      }

      // Add the clickable link
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: _getLinkColor(context),
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(url),
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining text after the last link
    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastMatchEnd),
      ));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 16,
          color: _getTextColor(context),
        ),
        children: spans,
      ),
    );
  }

  Widget _buildSimpleLinkText(BuildContext context) {
    return GestureDetector(
      onTap: () => _launchUrl(_detectedUrl!),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: _getLinkColor(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _getLinkColor(context).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link,
              size: 16,
              color: _getLinkColor(context),
            ),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                _detectedUrl!,
                style: TextStyle(
                  fontSize: 14,
                  color: _getLinkColor(context),
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 12,
              color: _getLinkColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTextColor(BuildContext context) {
    return widget.isOwn
        ? (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87)
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);
  }

  Color _getLinkColor(BuildContext context) {
    return widget.isOwn
        ? (Theme.of(context).brightness == Brightness.dark
            ? Colors.lightBlueAccent
            : Color(0xFF003f9b))
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.lightBlueAccent
            : Color(0xFF003f9b));
  }

  Widget _buildLinkPreview(BuildContext context, LinkMetadata link) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isOwn
              ? Colors.white.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
        color: widget.isOwn
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
      ),
      child: InkWell(
        onTap: () => _launchUrl(link.url),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail image (if available) - using SVGAvatar for caching
            if (link.image != null && link.image!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  child: SVGAvatar(
                    imageUrl: link.image!,
                    size: double.infinity,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.link,
                    backgroundColor: Colors.grey[300],
                    iconColor: Colors.grey[600],
                    isAvatarMode: false, // Not an avatar, just an image
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
                        color: widget.isOwn
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Color(0xFF003f9b))
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
                        color: widget.isOwn
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.8)
                                  : Color(0xFF003f9b).withOpacity(0.7))
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
                          color: widget.isOwn
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.7)
                                  : Color(0xFF003f9b).withOpacity(0.7))
                              : Colors.grey[500],
                        ),
                        SizedBox(width: 6),
                      ],

                      Expanded(
                        child: Text(
                          _formatUrl(link.url),
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isOwn
                                ? (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.7)
                                    : Color(0xFF003f9b).withOpacity(0.7))
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
                        color: widget.isOwn
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.7)
                                : Color(0xFF003f9b).withOpacity(0.7))
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
      // Ensure URL has proper protocol scheme
      String urlWithScheme = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        urlWithScheme = 'https://$url';
      }
      
      final uri = Uri.parse(urlWithScheme);
      debugPrint('🔗 Attempting to launch URL: $urlWithScheme');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('✅ URL launched successfully');
      } else {
        debugPrint('❌ Cannot launch URL: $urlWithScheme');
        // Fallback: try with different modes
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
