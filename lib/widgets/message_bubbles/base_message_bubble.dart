import 'package:duggy/widgets/quick_reaction_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../providers/user_provider.dart';
import '../svg_avatar.dart';
import '../inline_reaction_picker.dart';

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
  final bool isLastFromSender;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;

  // Message action callbacks
  final Function(ClubMessage message, String emoji)? onReactionAdded;
  final Function(ClubMessage message)? onReplyToMessage;
  final Function(ClubMessage message)? onToggleStarMessage;
  final Function(ClubMessage message)? onTogglePinMessage;
  final Function(ClubMessage message)? onDeleteMessage;
  final Function(ClubMessage message)? onShowMessageInfo;
  final bool canPinMessages;
  final bool canDeleteMessages;

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
    this.isLastFromSender = false,
    this.onReactionRemoved,
    this.onReactionAdded,
    this.onReplyToMessage,
    this.onToggleStarMessage,
    this.onTogglePinMessage,
    this.onDeleteMessage,
    this.onShowMessageInfo,
    this.canPinMessages = false,
    this.canDeleteMessages = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // onTap: () => _handleMessageTap(context),
      // onLongPress: () => _showMessageOptions(context),
      child: Column(
        crossAxisAlignment: isOwn
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Main message bubble with tail
          // Main bubble
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: isTransparent
                ? null
                : BoxDecoration(
                    color: _getBubbleColor(context),
                    borderRadius: _getBorderRadius(),
                    boxShadow: [
                      // WhatsApp-style shadow
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(
                                0.8,
                              ) // Very strong black shadow for dark mode
                            : Color(
                                0xFF000000,
                              ).withOpacity(0.08), // WhatsApp light mode shadow
                        blurRadius:
                            Theme.of(context).brightness == Brightness.dark
                            ? 2.5 // Slightly more blur for visibility in dark mode
                            : 1.5, // Very tight blur like WhatsApp for light mode
                        offset: Theme.of(context).brightness == Brightness.dark
                            ? Offset(
                                0,
                                2,
                              ) // Larger offset for better visibility in dark mode
                            : Offset(
                                0,
                                1,
                              ), // Small vertical offset for light mode
                        spreadRadius: 0,
                      ),
                      // Secondary shadow for depth (WhatsApp style)
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(
                                0.5,
                              ) // Strong secondary shadow for dark mode
                            : Color(0xFF000000).withOpacity(
                                0.04,
                              ), // Very subtle secondary shadow
                        blurRadius:
                            Theme.of(context).brightness == Brightness.dark
                            ? 4 // More blur for ambient effect in dark mode
                            : 3, // Standard blur for light mode
                        offset: Theme.of(context).brightness == Brightness.dark
                            ? Offset(
                                0,
                                3,
                              ) // Larger offset for depth in dark mode
                            : Offset(0, 2), // Standard offset for light mode
                        spreadRadius: 0,
                      ),
                    ],
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
          if (message.reactions.isNotEmpty && !message.deleted)
            Transform.translate(
              offset: Offset(0, -14), // Overlap with bubble
              child: Container(
                margin: EdgeInsets.only(
                  right: isOwn ? 12 : 0,
                  left: isOwn ? 0 : 12,
                  bottom: 0, // No bottom margin
                ),
                alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
                child: _buildReactionsDisplay(context),
              ),
            ),
        ],
      ),
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

    return isOwn
        ? (Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF0066CC) // Brighter blue for sender in dark mode
              : Color(0xFFd3f6fd)) // Light cyan background for sender
        : (Theme.of(context).brightness == Brightness.dark
              ? Color(
                  0xFF2A2A2A,
                ) // Lighter grey for received messages in dark mode
              : Colors.white);
  }

  BorderRadius _getBorderRadius() {
    // Use standard border radius for all messages
    // The tail is now handled by CustomPaint overlay
    return BorderRadius.circular(12);
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
          // Star icon (first) - show for any starred message
          if (message.starred.isStarred) ...[
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
    IconData? icon;
    Color finalIconColor = iconColor;

    switch (message.status) {
      case MessageStatus.preparing:
        icon = Icons.schedule;
        break;
      case MessageStatus.compressing:
        icon = Icons.compress;
        break;
      case MessageStatus.uploading:
        icon = Icons.cloud_upload;
        break;
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
        finalIconColor = Colors.green;
        break;
      case MessageStatus.failed:
        // No icon for failed messages - error icon will be shown outside the bubble
        return SizedBox.shrink();
    }

    if (message.id == 'cmezzje2t0001nwzh0x8qrcd5') {
      // Debug logging for status icon display
      debugPrint(
        '🎨 Message ${message.id}: status=${message.status}, deliveredAt=${message.deliveredAt}, readAt=${message.readAt}, isOwn=$isOwn, showing icon: $icon',
      );
    }

    return Icon(icon, size: 10, color: finalIconColor);
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

    // Group reactions by emoji and collect user information with emoji data
    Map<String, List<Map<String, String>>> groupedReactions = {};
    int calculatedCount = 0;

    for (var reaction in message.reactions) {
      // Handle new format with users array
      if (reaction.users.isNotEmpty) {
        calculatedCount += reaction.users.length;
        List<Map<String, String>> userList = [];
        for (var user in reaction.users) {
          final userInfo = {
            'userId': user.userId,
            'name': user.name,
            'profilePicture': user.profilePicture ?? '',
            'emoji': reaction.emoji,
          };
          userList.add(userInfo);
        }
        groupedReactions[reaction.emoji] = userList;
      } else {
        // Handle old format for backward compatibility
        calculatedCount += 1;
        final userName = reaction.userName.isNotEmpty
            ? reaction.userName
            : 'Unknown User';
        final userInfo = {
          'userId': reaction.userId,
          'name': userName,
          'profilePicture': '',
          'emoji': reaction.emoji,
        };

        if (groupedReactions.containsKey(reaction.emoji)) {
          groupedReactions[reaction.emoji]!.add(userInfo);
        } else {
          groupedReactions[reaction.emoji] = [userInfo];
        }
      }
    }

    // Use API reactionsCount if available, otherwise use calculated count
    final totalCount = message.reactionsCount ?? calculatedCount;

    // Get all unique emojis
    final uniqueEmojis = groupedReactions.keys.toList();

    return GestureDetector(
      onLongPress: () {
        debugPrint('Reaction long pressed! Total reactions: $totalCount');
        _showReactionDetails(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF2A2A2A) // Updated to match received message bubbles
              : Colors.white, // Same as received text bubbles
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF404040) // Lighter border for dark mode
                : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display emojis with individual counts if needed
            ...uniqueEmojis.asMap().entries.map((entry) {
              final emoji = entry.value;
              final emojiUsers = groupedReactions[emoji]!;

              // Check if current user has reacted with this emoji
              final currentUserId = context.read<UserProvider>().user?.id;
              final hasCurrentUserReacted =
                  currentUserId != null &&
                  emojiUsers.any((user) => user['userId'] == currentUserId);

              Widget emojiWidget = GestureDetector(
                onTap: () => _showReactionDetails(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize:
                          22, // Increased from 18 to 22 for better visibility
                      // Highlight emoji if current user has reacted
                      color: hasCurrentUserReacted ? Color(0xFF003f9b) : null,
                    ),
                  ),
                ),
              );

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  emojiWidget,
                  // Add spacing between different emojis (except for the last one)
                  if (entry.key < uniqueEmojis.length - 1) SizedBox(width: 4),
                ],
              );
            }),
            // Show total count at the end if there are more than 1 reactions total
            if (totalCount > 1) ...[
              if (uniqueEmojis.isNotEmpty)
                SizedBox(width: 4), // Add spacing before total count
              GestureDetector(
                onTap: () => _showReactionDetails(context),
                child: Text(
                  totalCount.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    // Convert to local timezone
    final localTime = dateTime.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localTime);

    if (difference.inDays > 0) {
      return '${localTime.day}/${localTime.month} ${localTime.hour}:${localTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${localTime.hour}:${localTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showReactionDetails(BuildContext context) {
    if (message.reactions.isEmpty) return;

    // Unfocus any text fields to prevent keyboard from appearing
    FocusScope.of(context).unfocus();

    // Group reactions by emoji and collect user information with emoji data
    Map<String, List<Map<String, String>>> groupedReactions = {};
    int totalReactions = 0;

    for (var reaction in message.reactions) {
      // Handle new format with users array
      if (reaction.users.isNotEmpty) {
        totalReactions += reaction.users.length;
        List<Map<String, String>> userList = [];
        for (var user in reaction.users) {
          final userInfo = {
            'userId': user.userId,
            'name': user.name,
            'profilePicture': user.profilePicture ?? '',
            'emoji': reaction.emoji,
          };
          userList.add(userInfo);
        }
        groupedReactions[reaction.emoji] = userList;
      } else {
        // Handle old format for backward compatibility
        totalReactions += 1;
        final userName = reaction.userName.isNotEmpty
            ? reaction.userName
            : 'Unknown User';
        final userInfo = {
          'userId': reaction.userId,
          'name': userName,
          'profilePicture': '',
          'emoji': reaction.emoji,
        };

        if (groupedReactions.containsKey(reaction.emoji)) {
          groupedReactions[reaction.emoji]!.add(userInfo);
        } else {
          groupedReactions[reaction.emoji] = [userInfo];
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF1C1C1C) // Updated dark background for reaction sheet
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ReactionDetailsSheet(
        message: message,
        groupedReactions: groupedReactions,
        totalReactions: totalReactions,
        onReactionRemoved: onReactionRemoved,
        onReactionAdded: onReactionAdded,
      ),
    );
  }
}

class ReactionDetailsSheet extends StatefulWidget {
  final ClubMessage message;
  final Map<String, List<Map<String, String>>> groupedReactions;
  final int totalReactions;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;
  final Function(ClubMessage message, String emoji)? onReactionAdded;

  const ReactionDetailsSheet({
    Key? key,
    required this.message,
    required this.groupedReactions,
    required this.totalReactions,
    this.onReactionRemoved,
    this.onReactionAdded,
  }) : super(key: key);

  @override
  State<ReactionDetailsSheet> createState() => _ReactionDetailsSheetState();
}

class _ReactionDetailsSheetState extends State<ReactionDetailsSheet> {
  String?
  _selectedEmojiFilter; // null means showing all, string means specific emoji

  @override
  void initState() {
    super.initState();
    _selectedEmojiFilter = null; // Start with showing all reactions
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[600]
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          SizedBox(height: 16),

          // Filter buttons row
          Container(
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Add reaction button (first button)
                      _buildFilterButton(
                        context,
                        emoji: null, // Special case for add button
                        count: 0,
                        isSelected: false,
                        isAddButton: true,
                      ),

                      SizedBox(width: 8),

                      // Individual emoji filter buttons (no "All" button)
                      ...widget.groupedReactions.keys.map((emoji) {
                        final count =
                            widget.groupedReactions[emoji]?.length ?? 0;
                        return Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: _buildFilterButton(
                            context,
                            emoji: emoji,
                            count: count,
                            isSelected: _selectedEmojiFilter == emoji,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Filtered user list
          Expanded(child: _buildFilteredUserList(context)),
        ],
      ),
    );
  }

  void _removeReactionAndUpdateUI(
    BuildContext context,
    String? emoji,
    String userId,
  ) async {
    if (emoji == null) return;

    // Verify user permission
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.user;

    if (currentUser == null || userId != currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can only remove your own reactions'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Let the parent component handle the removal with the same API pattern as long press
    if (widget.onReactionRemoved != null) {
      widget.onReactionRemoved!(widget.message.id, emoji, userId);
    }

    // Wait a moment for the API call to complete, then refresh the dialog
    await Future.delayed(Duration(milliseconds: 300));

    // Close current dialog and reopen with fresh data
    if (context.mounted) {
      Navigator.pop(context);
      // Slight delay to ensure the dialog close animation completes
      await Future.delayed(Duration(milliseconds: 100));
      if (context.mounted) {
        _showReactionDetailsAgain(context);
      }
    }
  }

  void _showReactionPicker(BuildContext context) {
    // Close current sheet first
    Navigator.pop(context);

    // Add a small delay to ensure the previous modal is fully closed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (context.mounted) {
        _showEmojiInputDialog(context);
      }
    });
  }

  void _showEmojiInputDialog(BuildContext context) {
    _showDirectEmojiKeyboard(context);
  }

  void _showDirectEmojiKeyboard(BuildContext context) {
    final TextEditingController emojiController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // Position off-screen but still accessible to keyboard
        top: -100,
        left: 0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 1,
            height: 1,
            child: TextField(
              controller: emojiController,
              focusNode: focusNode,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '😀', // Hint to suggest emoji input
              ),
              onChanged: (text) {
                if (text.isNotEmpty) {
                  // Extract first emoji character
                  final firstEmoji = text.characters.first;

                  // Remove overlay
                  overlayEntry?.remove();

                  // Add the reaction
                  if (widget.onReactionAdded != null) {
                    widget.onReactionAdded!(widget.message, firstEmoji);
                  }
                }
              },
              onTapOutside: (event) {
                // Close when user taps outside
                overlayEntry?.remove();
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // Auto-focus to open keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  void _showReactionDetailsAgain(BuildContext context) {
    // Re-show the reaction details with fresh data
    if (widget.message.reactions.isEmpty) return;

    // Unfocus any text fields to prevent keyboard from appearing
    FocusScope.of(context).unfocus();

    // Group reactions by emoji and collect user information with emoji data
    Map<String, List<Map<String, String>>> groupedReactions = {};
    int totalReactions = 0;

    for (var reaction in widget.message.reactions) {
      // Handle new format with users array
      if (reaction.users.isNotEmpty) {
        totalReactions += reaction.users.length.toInt();
        List<Map<String, String>> userList = [];
        for (var user in reaction.users) {
          final userInfo = {
            'userId': user.userId,
            'name': user.name,
            'profilePicture': user.profilePicture ?? '',
            'emoji': reaction.emoji,
          };
          userList.add(userInfo);
        }
        groupedReactions[reaction.emoji] = userList;
      } else {
        // Handle old format for backward compatibility
        totalReactions += 1;
        final userName = reaction.userName.isNotEmpty
            ? reaction.userName
            : 'Unknown User';
        final userInfo = {
          'userId': reaction.userId,
          'name': userName,
          'profilePicture': '',
          'emoji': reaction.emoji,
        };

        if (groupedReactions.containsKey(reaction.emoji)) {
          groupedReactions[reaction.emoji]!.add(userInfo);
        } else {
          groupedReactions[reaction.emoji] = [userInfo];
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF1C1C1C) // Updated dark background for reaction sheet
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ReactionDetailsSheet(
        message: widget.message,
        groupedReactions: groupedReactions,
        totalReactions: totalReactions,
        onReactionRemoved: widget.onReactionRemoved,
        onReactionAdded: widget.onReactionAdded,
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context, {
    String? emoji,
    required int count,
    required bool isSelected,
    bool isAddButton = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (isAddButton) {
          _showReactionPicker(context);
        } else {
          setState(() {
            // Toggle filter: if already selected, show all; otherwise filter by this emoji
            _selectedEmojiFilter = isSelected ? null : emoji;
          });
        }
      },
      child: Container(
        width: isAddButton ? 44 : null, // Perfect circle for add button
        height: isAddButton ? 44 : null, // Perfect circle for add button
        padding: isAddButton
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                    ? Colors.lightBlueAccent.withOpacity(0.2)
                    : Color(0xFF003f9b).withOpacity(0.1))
              : (isDarkMode ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(
            isAddButton ? 22 : 20,
          ), // Perfect circle for add button
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? Colors.lightBlueAccent : Color(0xFF003f9b))
                : (isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: isAddButton
            ? Center(
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji!, style: TextStyle(fontSize: 18)),
                  SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (isDarkMode
                                ? Colors.lightBlueAccent
                                : Color(0xFF003f9b))
                          : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilteredUserList(BuildContext context) {
    List<Map<String, String>> users;

    if (_selectedEmojiFilter == null) {
      // Show all users from all emoji reactions
      users = [];
      widget.groupedReactions.forEach((emoji, userList) {
        for (var user in userList) {
          // Add emoji info to each user for All view
          final userWithEmoji = Map<String, String>.from(user);
          userWithEmoji['emoji'] = emoji;
          users.add(userWithEmoji);
        }
      });
    } else {
      // Show users for specific emoji filter
      users = widget.groupedReactions[_selectedEmojiFilter] ?? [];
    }

    // Sort users to put current user first
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.user;
    users.sort((a, b) {
      final aUserId = a['userId'] ?? '';
      final bUserId = b['userId'] ?? '';
      final aUserName = a['name'] ?? '';
      final bUserName = b['name'] ?? '';

      final aIsCurrentUser =
          currentUser != null &&
          (aUserId == currentUser.id || aUserName == currentUser.name);
      final bIsCurrentUser =
          currentUser != null &&
          (bUserId == currentUser.id || bUserName == currentUser.name);

      if (aIsCurrentUser && !bIsCurrentUser) return -1;
      if (!aIsCurrentUser && bIsCurrentUser) return 1;
      return 0;
    });

    // Show empty state if no users
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No reactions found',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final userInfo = users[index];
        final userName = userInfo['name'] ?? 'Unknown User';
        final profilePicture = userInfo['profilePicture'] ?? '';
        final userId = userInfo['userId'] ?? '';
        final userEmoji = userInfo['emoji'] ?? '';

        // Get current user from provider
        final userProvider = context.watch<UserProvider>();
        final currentUser = userProvider.user;
        final isCurrentUser =
            currentUser != null &&
            (userId == currentUser.id || userName == currentUser.name);

        return GestureDetector(
          onTap: isCurrentUser
              ? () {
                  // Use the user's specific emoji for All view, or current filter emoji
                  final emojiToRemove = _selectedEmojiFilter == null
                      ? userEmoji
                      : _selectedEmojiFilter!;

                  // Remove the reaction directly without closing the dialog
                  _removeReactionAndUpdateUI(context, emojiToRemove, userId);
                }
              : null,
          child: Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                // Avatar with SVG support and proper fallback
                SVGAvatar(
                  imageUrl: profilePicture.isNotEmpty ? profilePicture : null,
                  size: 44,
                  backgroundColor: Color(0xFF003f9b),
                  fallbackText: userName.isNotEmpty
                      ? userName[0].toUpperCase()
                      : '?',
                ),

                SizedBox(width: 16),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentUser
                            ? 'You'
                            : (userName.isNotEmpty ? userName : 'Unknown User'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black87,
                        ),
                      ),
                      if (isCurrentUser)
                        Text(
                          'Tap to remove',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),

                // Reaction emoji on the right
                Text(
                  _selectedEmojiFilter == null
                      ? userEmoji
                      : _selectedEmojiFilter!,
                  style: TextStyle(fontSize: 28),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
