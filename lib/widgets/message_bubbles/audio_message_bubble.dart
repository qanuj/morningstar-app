import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import 'base_message_bubble.dart';
import '../audio_player_widget.dart';

/// Audio message bubble - just shows audio player with URL to play
class AudioMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;

  const AudioMessageBubble({
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
    if (message.audio == null) {
      return _buildErrorState(context);
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
        minWidth: 200,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio player
          AudioPlayerWidget(
            audioPath: message.audio!.url,
            isFromCurrentUser: isOwn,
          ),
          
          // Optional text content below audio
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
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Audio not available',
            style: TextStyle(
              fontSize: 14,
              color: isOwn
                  ? Colors.white.withOpacity(0.8)
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}