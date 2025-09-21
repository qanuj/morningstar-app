import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../screens/matches/match_detail.dart';
import '../../screens/matches/cached_match_detail_screen.dart';
import '../../screens/practices/practice_match_detail.dart';
import 'text_message_bubble.dart';
import 'audio_message_bubble.dart';
import 'document_message_bubble.dart';
import 'link_message_bubble.dart';
import 'gif_message_bubble.dart';
import 'emoji_message_bubble.dart';
import 'cached_match_message_bubble.dart';
import 'location_message_bubble.dart';
import 'poll_message_bubble.dart';
import 'base_message_bubble.dart';

/// Factory widget that creates the appropriate message bubble based on content type
class MessageBubbleFactory extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isDeleted;
  final bool isSelected;
  final bool showSenderInfo;
  final bool isLastFromSender;
  final VoidCallback? onRetryUpload;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;

  // Message interaction callbacks
  final Function(ClubMessage message)? onMessageTap;
  final Function(ClubMessage message)? onMessageLongPress;
  final Function(ClubMessage message, String emoji)? onReactionAdded;
  final Function(ClubMessage message)? onReplyToMessage;
  final Function(ClubMessage message)? onToggleStarMessage;
  final Function(ClubMessage message)? onTogglePinMessage;
  final Function(ClubMessage message)? onDeleteMessage;
  final Function(ClubMessage message)? onShowMessageInfo;
  final bool canPinMessages;
  final bool canDeleteMessages;
  final bool isSelectionMode;

  const MessageBubbleFactory({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.isDeleted,
    this.isSelected = false,
    this.showSenderInfo = false,
    this.isLastFromSender = false,
    this.onRetryUpload,
    this.onReactionRemoved,
    this.onMessageTap,
    this.onMessageLongPress,
    this.onReactionAdded,
    this.onReplyToMessage,
    this.onToggleStarMessage,
    this.onTogglePinMessage,
    this.onDeleteMessage,
    this.onShowMessageInfo,
    this.canPinMessages = false,
    this.canDeleteMessages = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Handle deleted messages first
    if (isDeleted) {
      return _buildDeletedMessage(context);
    }

    if (message.messageType == 'audio' && message.audio != null) {
      // AUDIO MESSAGE: Just audio player
      return AudioMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        onRetryUpload: onRetryUpload,
      );
    } else if (message.messageType == 'document') {
      // DOCUMENT MESSAGE: Document cards with download capability
      return DocumentMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
        onRetryUpload: onRetryUpload,
        onReactionRemoved: onReactionRemoved,
      );
    } else if (message.linkMeta.isNotEmpty) {
      // LINK MESSAGE: Thumbnail, title, full link
      return LinkMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
      );
    } else if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
      // GIF MESSAGE: GIF with optional text below
      return GifMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
      );
    } else if (message.messageType == 'emoji') {
      // EMOJI MESSAGE: Large emoji without background
      return EmojiMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
      );
    } else if (message.messageType == 'match') {
      // MATCH MESSAGE: Special match announcement with RSVP buttons (cached)
      return CachedMatchMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
        onReactionRemoved: onReactionRemoved,
        onViewMatch: () => _navigateToCachedMatchDetail(context, message),
        onRSVP: () {
          // RSVP is handled internally by the CachedMatchMessageBubble
        },
      );
    } else if (message.messageType == 'practice') {
      // PRACTICE MESSAGE: Practice session announcement with RSVP buttons (cached)
      return CachedMatchMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
        onReactionRemoved: onReactionRemoved,
        onViewMatch: () => _navigateToCachedMatchDetail(context, message), // Practice details also cached
        onRSVP: () {
          // RSVP is handled internally by the CachedMatchMessageBubble
        },
      );
    } else if (message.messageType == 'location') {
      // LOCATION MESSAGE: Location sharing with map integration
      return LocationMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
        onReactionRemoved: onReactionRemoved,
        onOpenMap: () {
          // Map opening is handled internally by the LocationMessageBubble
        },
      );
    } else if (message.messageType == 'poll') {
      // POLL MESSAGE: Interactive poll with voting functionality
      return PollMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
        onReactionRemoved: onReactionRemoved,
        onViewPoll: () {
          // Poll details viewing is handled internally by the PollMessageBubble
        },
      );
    } else {
      // TEXT MESSAGE: Images/videos first, then body below
      return TextMessageBubble(
        message: message,
        isOwn: isOwn,
        isPinned: isPinned,
        isSelected: isSelected,
        showSenderInfo: showSenderInfo,
        isLastFromSender: isLastFromSender,
        onReactionRemoved: onReactionRemoved,
      );
    }
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      customColor: Colors.grey[300],
      showMetaOverlay: false,
      showShadow: false,
      isLastFromSender: isLastFromSender,
      onReactionRemoved: onReactionRemoved,
      content: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                message.deletedBy != null && message.deletedBy!.isNotEmpty
                    ? 'Message deleted by ${message.deletedBy}'
                    : 'This message was deleted',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCachedMatchDetail(BuildContext context, ClubMessage message) {
    if (message.matchId == null) return;

    final matchData = message.meta ?? {};

    // Create a cached match detail screen that uses the message data
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CachedMatchDetailScreen(
          message: message,
          matchData: matchData,
        ),
      ),
    );
  }
}
