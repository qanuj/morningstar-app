import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/club_message.dart';

class PinnedMessagesSection extends StatefulWidget {
  final List<ClubMessage> messages;
  final Function(String messageId) onScrollToMessage;
  final Function(ClubMessage message) onTogglePin;
  final Function() canPinMessages;
  final String clubId;

  const PinnedMessagesSection({
    super.key,
    required this.messages,
    required this.onScrollToMessage,
    required this.onTogglePin,
    required this.canPinMessages,
    required this.clubId,
  });

  @override
  _PinnedMessagesSectionState createState() => _PinnedMessagesSectionState();
}

class _PinnedMessagesSectionState extends State<PinnedMessagesSection> {
  Timer? _pinnedRefreshTimer;
  Set<String>? _lastKnownPinnedIds;
  int _currentPinnedIndex = 0;

  @override
  void initState() {
    super.initState();
    _startPinnedRefreshTimer();
  }

  @override
  void dispose() {
    _pinnedRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(PinnedMessagesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages) {
      _updatePinnedIndex();
    }
  }

  void _updatePinnedIndex() {
    final pinnedMessages = widget.messages
        .where((m) => _isCurrentlyPinned(m))
        .toList();
    if (_currentPinnedIndex >= pinnedMessages.length) {
      _currentPinnedIndex = 0;
    }
  }

  // Helper method to check if a message is currently pinned
  bool _isCurrentlyPinned(ClubMessage message) {
    return message.pin.isPinned;
  }

  // Start a timer to refresh pinned messages when pin periods expire and check for new pins
  void _startPinnedRefreshTimer() {
    _pinnedRefreshTimer?.cancel();

    // Check for pin expiry every minute
    _pinnedRefreshTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      if (mounted) {
        final currentPinnedIds = widget.messages
            .where((m) => _isCurrentlyPinned(m))
            .map((m) => m.id)
            .toSet();
        final previousPinnedIds = _lastKnownPinnedIds ?? <String>{};

        // If the set of pinned messages has changed, refresh the UI
        if (currentPinnedIds.length != previousPinnedIds.length ||
            !currentPinnedIds.containsAll(previousPinnedIds)) {
          setState(() {
            _lastKnownPinnedIds = currentPinnedIds;
            // Reset pinned index when pinned messages change
            _currentPinnedIndex = 0;
          });
        }
      }
    });

    // Store current pinned message IDs for comparison
    _lastKnownPinnedIds = widget.messages
        .where((m) => _isCurrentlyPinned(m))
        .map((m) => m.id)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final pinnedMessages = widget.messages
        .where((m) => _isCurrentlyPinned(m))
        .toList();

    if (pinnedMessages.isEmpty) return SizedBox.shrink();

    // Ensure current index is within bounds
    if (_currentPinnedIndex >= pinnedMessages.length) {
      _currentPinnedIndex = 0;
    }

    final currentMessage = pinnedMessages[_currentPinnedIndex];
    final hasMultiple = pinnedMessages.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1)),
      ),
      child: Column(
        children: [
          _buildPinnedMessageItem(
            currentMessage,
            pinnedMessages.length,
            _currentPinnedIndex + 1,
          ),
          if (hasMultiple)
            _buildPinnedIndicator(pinnedMessages.length, _currentPinnedIndex),
        ],
      ),
    );
  }

  /// Helper function to get appropriate display text for pinned messages
  String _getPinnedMessageDisplayText(ClubMessage message) {
    // Handle different message types
    if (message.messageType == 'audio' && message.audio != null) {
      return 'Audio';
    } else if (message.document != null) {
      return 'Document';
    } else if (message.images.isNotEmpty) {
      return message.images.length == 1
          ? 'Photo'
          : '${message.images.length} Photos';
    } else if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
      return 'GIF';
    } else if (message.linkMeta.isNotEmpty) {
      return 'Link';
    } else if (message.messageType == 'emoji') {
      // For emoji messages, show the actual emoji if content is available
      return message.content.trim().isNotEmpty
          ? message.content.trim()
          : 'Emoji';
    } else {
      // For text messages, return the content if available
      final content = message.content.trim();
      return content.isNotEmpty ? content : 'Message';
    }
  }

  Widget _buildPinnedMessageItem(
    ClubMessage message,
    int totalCount,
    int currentIndex,
  ) {
    final String displayText = _getPinnedMessageDisplayText(message);
    final String firstLine = displayText.split('\n').first;

    return GestureDetector(
      onTap: () => _cycleToPinnedMessage(message.id),
      onLongPress: () => _showPinnedMessageOptions(message),
      child: Container(
        height: 56, // Fixed height to prevent changes
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pin icon
            Icon(Icons.push_pin, size: 16, color: Color(0xFF6C757D)),
            SizedBox(width: 8),

            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Message preview
                  Text(
                    firstLine,
                    style: TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Visual indicator for different message types
            _buildPinnedMessageIndicator(message),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedMessageImages(List<String> pictures) {
    final imagesToShow = pictures.take(3).toList();

    return Container(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: imagesToShow.asMap().entries.map((entry) {
          final index = entry.key;
          final image = entry.value;
          final isLast = index == imagesToShow.length - 1;
          final remainingCount = pictures.length - 3;

          return Container(
            margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: image,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image,
                        color: Colors.grey[600],
                        size: 14,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey[600],
                        size: 14,
                      ),
                    ),
                  ),
                ),
                // Show count overlay on last image if there are more than 3
                if (isLast && remainingCount > 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '+$remainingCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds visual indicator for different message types in pinned messages
  Widget _buildPinnedMessageIndicator(ClubMessage message) {
    // Show images if available
    if (message.images.isNotEmpty) {
      return _buildPinnedMessageImages(message.images);
    }

    // Show icon indicators for other message types
    Widget? iconWidget;
    Color iconColor = Color(0xFF6C757D);

    if (message.messageType == 'audio' && message.audio != null) {
      iconWidget = Icon(Icons.audiotrack, size: 20, color: iconColor);
    } else if (message.document != null) {
      iconWidget = Icon(Icons.description, size: 20, color: iconColor);
    } else if (message.gifUrl != null && message.gifUrl!.isNotEmpty) {
      iconWidget = Icon(Icons.gif_box, size: 20, color: iconColor);
    } else if (message.linkMeta.isNotEmpty) {
      iconWidget = Icon(Icons.link, size: 20, color: iconColor);
    } else if (message.messageType == 'emoji') {
      iconWidget = Icon(Icons.emoji_emotions, size: 20, color: iconColor);
    }

    // Return icon container if we have an icon to show
    if (iconWidget != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFDEE2E6), width: 1),
        ),
        child: Center(child: iconWidget),
      );
    }

    // For regular text messages, don't show any indicator
    return SizedBox.shrink();
  }

  Widget _buildPinnedIndicator(int totalCount, int currentIndex) {
    // Show max 4 indicators as requested
    final indicatorsToShow = totalCount > 4 ? 4 : totalCount;

    return Container(
      padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
      child: Row(
        children: [
          // Current position text (e.g., "1 of 5")
          Text(
            '${currentIndex + 1} of $totalCount',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6C757D),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          // Line indicators
          Expanded(
            child: Row(
              children: List.generate(indicatorsToShow, (index) {
                bool isActive;
                if (totalCount <= 4) {
                  // Show normal indicators for 4 or fewer items
                  isActive = index == currentIndex;
                } else {
                  // For more than 4 items, show progress within the 4 indicators
                  final progress =
                      (currentIndex / (totalCount - 1)) *
                      (indicatorsToShow - 1);
                  isActive = index <= progress.round();
                }

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: index < indicatorsToShow - 1 ? 2 : 0,
                    ),
                    height: 2,
                    decoration: BoxDecoration(
                      color: isActive ? Color(0xFF003f9b) : Color(0xFFDEE2E6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _cycleToPinnedMessage(String currentMessageId) {
    final pinnedMessages = widget.messages
        .where((m) => _isCurrentlyPinned(m))
        .toList();
    if (pinnedMessages.length <= 1) {
      // If only one pinned message, just scroll to it
      widget.onScrollToMessage(currentMessageId);
      return;
    }

    // Cycle to next pinned message
    setState(() {
      _currentPinnedIndex = (_currentPinnedIndex + 1) % pinnedMessages.length;
    });

    // Scroll to the new current pinned message
    final nextMessage = pinnedMessages[_currentPinnedIndex];
    widget.onScrollToMessage(nextMessage.id);
  }

  void _showPinnedMessageOptions(ClubMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF2D3748)
              : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.navigation,
                title: 'Go to message',
                onTap: () {
                  Navigator.pop(context);
                  widget.onScrollToMessage(message.id);
                },
              ),
              // Only show unpin option if user has permission
              if (widget.canPinMessages())
                _buildOptionTile(
                  icon: Icons.push_pin_outlined,
                  title: 'Unpin',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onTogglePin(message);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.8)
            : Colors.black.withOpacity(0.8),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.9)
              : Colors.black.withOpacity(0.9),
        ),
      ),
      onTap: onTap,
    );
  }
}
