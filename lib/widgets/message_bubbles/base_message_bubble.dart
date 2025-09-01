import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/message_reaction.dart';

/// Base message bubble that provides the container and meta overlay for all message types
class BaseMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final Widget content;
  final bool isPinned;
  final bool isSelected;
  final bool isTransparent;
  final Color? customColor;
  final bool showMetaOverlay;
  final bool showShadow;
  final double? overlayBottomPosition;

  const BaseMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.content,
    required this.isPinned,
    this.isSelected = false,
    this.isTransparent = false,
    this.customColor,
    this.showMetaOverlay = true,
    this.showShadow = false,
    this.overlayBottomPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isOwn
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Main message bubble
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: isTransparent
              ? null
              : BoxDecoration(
                  color: _getBubbleColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: message.status == MessageStatus.failed
                      ? Border.all(color: Colors.red, width: 1)
                      : null,
                  boxShadow: showShadow
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
          child: Stack(
            children: [
              // Message content
              Padding(
                padding: showMetaOverlay
                    ? EdgeInsets.only(
                        bottom: 12,
                      ) // Reduced space for meta overlay
                    : EdgeInsets.zero, // No extra space if no overlay
                child: content,
              ),

              // Meta overlay (pin, star, time, tick) at bottom right
              if (showMetaOverlay)
                _shouldUseColumnLayout()
                    ? Positioned(
                        bottom: overlayBottomPosition ?? 2,
                        right: 0, // Align to right edge for small text
                        child: _buildMetaOverlay(context),
                      )
                    : Positioned(
                        bottom: overlayBottomPosition ?? 2,
                        right: 5, // Normal inline position
                        child: _buildMetaOverlay(context),
                      ),
            ],
          ),
        ),

        // Reactions display (below the bubble with overlap using transform)
        if (message.reactions.isNotEmpty)
          Transform.translate(
            offset: Offset(0, -12), // Move up to overlap the bubble
            child: Container(
              margin: EdgeInsets.only(
                right: isOwn ? 12 : 0,
                left: isOwn ? 0 : 12,
                bottom: 8, // Add some space below
              ),
              alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
              child: _buildReactionsDisplay(context),
            ),
          ),
      ],
    );
  }

  Color _getBubbleColor(BuildContext context) {
    // Transparent bubbles have no background color
    if (isTransparent) {
      return Colors.transparent;
    }

    // Custom color overrides everything except transparent
    if (customColor != null) {
      return customColor!;
    }

    // Selection state overrides other colors
    if (isSelected) {
      return Color(0xFF003f9b).withOpacity(0.3);
    }

    if (message.status == MessageStatus.failed) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.red[800]!
          : Colors.red.withOpacity(0.7);
    }

    return isOwn
        ? (Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E3A8A)
              : Color(0xFFE3F2FD))
        : (Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : Colors.white);
  }

  Widget _buildMetaOverlay(BuildContext context) {
    final iconColor = isOwn
        ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.7)
              : Colors.black.withOpacity(0.65))
        : (Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.7)
              : Colors.black.withOpacity(0.6));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Star icon (first)
          if (isOwn && message.starred.isStarred) ...[
            Icon(Icons.star, size: 10, color: iconColor),
            SizedBox(width: 4),
          ],

          // Pin icon (second)
          if (isOwn && isPinned) ...[
            Icon(Icons.push_pin, size: 10, color: iconColor),
            SizedBox(width: 4),
          ],

          // Time (third)
          Text(
            _formatMessageTime(message.createdAt),
            style: TextStyle(fontSize: 10, color: iconColor),
          ),

          // Status tick (fourth - rightmost) - only for own messages
          if (isOwn) ...[SizedBox(width: 4), _buildStatusIcon(iconColor)],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Color iconColor) {
    IconData icon;
    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        iconColor = Colors.blue;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        iconColor = Colors.red;
        break;
    }

    return Icon(icon, size: 10, color: iconColor);
  }

  bool _shouldUseColumnLayout() {
    // Check if text is small (for text messages)
    if (message.content.isNotEmpty) {
      // Use different positioning for very short text (single word or emoji-like)
      return message.content.trim().length <= 10 &&
          !message.content.contains('\n');
    }

    return false;
  }

  Widget _buildReactionsDisplay(BuildContext context) {
    if (message.reactions.isEmpty) return SizedBox.shrink();

    // Group reactions by emoji and collect user information
    Map<String, List<Map<String, String>>> groupedReactions = {};
    int totalCount = 0;
    
    for (var reaction in message.reactions) {
      // Handle new format with users array
      if (reaction.users.isNotEmpty) {
        totalCount += reaction.users.length;
        List<Map<String, String>> userList = [];
        for (var user in reaction.users) {
          userList.add({
            'userId': user.userId,
            'name': user.name,
            'profilePicture': user.profilePicture ?? '',
          });
        }
        groupedReactions[reaction.emoji] = userList;
      } else {
        // Handle old format for backward compatibility
        totalCount += 1;
        final userName = reaction.userName.isNotEmpty ? reaction.userName : 'Unknown User';
        if (groupedReactions.containsKey(reaction.emoji)) {
          groupedReactions[reaction.emoji]!.add({
            'userId': reaction.userId,
            'name': userName,
            'profilePicture': '',
          });
        } else {
          groupedReactions[reaction.emoji] = [{
            'userId': reaction.userId,
            'name': userName,
            'profilePicture': '',
          }];
        }
      }
    }

    // Get all unique emojis
    final uniqueEmojis = groupedReactions.keys.toList();

    return GestureDetector(
      onTap: () {
        print('Reaction tapped! Total reactions: $totalCount');
        _showReactionDetails(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8), // Slightly more opaque for visibility
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display emojis with individual counts if needed
            ...uniqueEmojis.asMap().entries.map((entry) {
              final emoji = entry.value;
              final emojiUserCount = groupedReactions[emoji]!.length;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: TextStyle(fontSize: 14)),
                  // Show count for this emoji if it has more than 1 reaction
                  if (emojiUserCount > 1) ...[
                    Text(
                      emojiUserCount.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.8)
                            : Colors.black.withOpacity(0.7),
                      ),
                    ),
                  ],
                  // Add spacing between different emojis (except for the last one)
                  if (entry.key < uniqueEmojis.length - 1) SizedBox(width: 2),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showReactionDetails(BuildContext context) {
    if (message.reactions.isEmpty) return;

    // Group reactions by emoji and collect user information  
    Map<String, List<Map<String, String>>> groupedReactions = {};
    int totalReactions = 0;
    
    for (var reaction in message.reactions) {
      // Handle new format with users array
      if (reaction.users.isNotEmpty) {
        totalReactions += reaction.users.length;
        List<Map<String, String>> userList = [];
        for (var user in reaction.users) {
          userList.add({
            'userId': user.userId,
            'name': user.name,
            'profilePicture': user.profilePicture ?? '',
          });
        }
        groupedReactions[reaction.emoji] = userList;
      } else {
        // Handle old format for backward compatibility
        totalReactions += 1;
        final userName = reaction.userName.isNotEmpty ? reaction.userName : 'Unknown User';
        if (groupedReactions.containsKey(reaction.emoji)) {
          groupedReactions[reaction.emoji]!.add({
            'userId': reaction.userId,
            'name': userName,
            'profilePicture': '',
          });
        } else {
          groupedReactions[reaction.emoji] = [{
            'userId': reaction.userId,
            'name': userName,
            'profilePicture': '',
          }];
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ReactionDetailsSheet(
        groupedReactions: groupedReactions,
        totalReactions: totalReactions,
      ),
    );
  }
}

class ReactionDetailsSheet extends StatefulWidget {
  final Map<String, List<Map<String, String>>> groupedReactions;
  final int totalReactions;

  const ReactionDetailsSheet({
    Key? key,
    required this.groupedReactions,
    required this.totalReactions,
  }) : super(key: key);

  @override
  State<ReactionDetailsSheet> createState() => _ReactionDetailsSheetState();
}

class _ReactionDetailsSheetState extends State<ReactionDetailsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = ['All', ...widget.groupedReactions.keys];
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _removeReaction(BuildContext context, String? emoji, String userId) {
    // TODO: Implement API call to remove reaction
    print('Removing reaction: $emoji for user: $userId');
    
    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(emoji != null 
            ? 'Removed $emoji reaction' 
            : 'Reaction removed'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
      ),
    );
    
    // Here you would typically:
    // 1. Call API to remove the reaction for specific user and emoji
    // 2. Update the message state to remove the reaction
    // 3. Refresh the UI to reflect the changes
    // 
    // Example API call:
    // await reactionService.removeReaction(
    //   messageId: widget.message.id,
    //   userId: userId,
    //   emoji: emoji,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Color(0xFF003f9b),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Color(0xFF003f9b),
            tabs: _tabs.map((tab) {
              if (tab == 'All') {
                return Tab(text: widget.totalReactions > 1 ? '$tab ${widget.totalReactions}' : tab);
              } else {
                final count = widget.groupedReactions[tab]?.length ?? 0;
                return Tab(text: count > 1 ? '$tab $count' : tab);
              }
            }).toList(),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                List<Map<String, String>> users;
                if (tab == 'All') {
                  users = widget.groupedReactions.values
                      .expand((userList) => userList)
                      .toList();
                } else {
                  users = widget.groupedReactions[tab] ?? [];
                }
                
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userInfo = users[index];
                    final userName = userInfo['name'] ?? 'Unknown User';
                    final profilePicture = userInfo['profilePicture'] ?? '';
                    final userId = userInfo['userId'] ?? '';
                    
                    // TODO: Replace with actual current user ID check
                    // For now, checking by userId or userName as fallback
                    final currentUserId = 'cmbova8yn00015bxp4060pjy1'; // TODO: Get from user provider/auth
                    final isCurrentUser = userId == currentUserId || userName == 'Anuj Pandey';
                    
                    return GestureDetector(
                      onTap: isCurrentUser ? () {
                        Navigator.pop(context); // Close the drawer
                        _removeReaction(context, tab == 'All' ? null : tab, userId);
                      } : null,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: isCurrentUser ? BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ) : null,
                        padding: isCurrentUser ? EdgeInsets.all(8) : EdgeInsets.zero,
                        child: Row(
                          children: [
                            // Avatar with profile picture or letter fallback
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFF003f9b),
                              backgroundImage: profilePicture.isNotEmpty 
                                  ? NetworkImage(profilePicture) 
                                  : null,
                              child: profilePicture.isEmpty
                                  ? Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                            
                            SizedBox(width: 12),
                            
                            // User name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName.isNotEmpty ? userName : 'Unknown User',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (isCurrentUser)
                                    Text(
                                      'Tap to remove',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red[400],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Remove icon for current user
                            if (isCurrentUser)
                              Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red[400],
                                  size: 16,
                                ),
                              ),
                            
                            // Reaction emoji for individual tabs (when not current user)
                            if (tab != 'All' && !isCurrentUser)
                              Text(
                                tab,
                                style: TextStyle(fontSize: 24),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
