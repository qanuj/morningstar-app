import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import 'base_message_bubble.dart';

/// GIF message bubble - shows GIF with optional text below
class GifMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final Function(String messageId, String emoji, String userId)? onReactionRemoved;

  const GifMessageBubble({
    Key? key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
    this.onReactionRemoved,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      content: _buildContent(context),
      onReactionRemoved: onReactionRemoved,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GIF first
        _buildGifContent(context),
        
        // Optional text content below GIF
        if (message.content.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              fontSize: 16,
              color: isOwn
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Color(0xFF003f9b)) // Dark blue for light backgrounds
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGifContent(BuildContext context) {
    if (message.gifUrl == null || message.gifUrl!.isEmpty) {
      return _buildErrorState(context);
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
        maxHeight: 300,
        minWidth: 200,
        minHeight: 150,
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message.gifUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                              : null,
                          color: isOwn ? Colors.white : Theme.of(context).primaryColor,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Loading GIF...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => _buildErrorState(context),
            ),
          ),
          
          // GIF indicator overlay
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'GIF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      height: 150,
      width: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.gif_box,
            size: 48,
            color: Colors.grey[600],
          ),
          SizedBox(height: 8),
          Text(
            'GIF not available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}