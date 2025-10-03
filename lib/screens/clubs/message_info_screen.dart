import 'package:duggy/services/chat_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club_message.dart';
import '../../models/club.dart';
import '../../widgets/svg_avatar.dart';
import '../../widgets/message_bubbles/message_bubble_factory.dart';
import '../../widgets/custom_app_bar.dart';

class MessageInfoScreen extends StatefulWidget {
  final ClubMessage message;
  final List<Map<String, dynamic>> clubMembers;
  final Club? club;

  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.clubMembers,
    this.club,
  });

  @override
  State<MessageInfoScreen> createState() => _MessageInfoScreenState();
}

class _MessageInfoScreenState extends State<MessageInfoScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveredTo = [];
  List<Map<String, dynamic>> _readBy = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMessageStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessageStatus() async {
    try {
      final data = await ChatApiService.getMessageStatus(
        widget.message.clubId,
        widget.message.id,
      );

      setState(() {
        _deliveredTo = (data['delivered'] as List? ?? [])
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _readBy = (data['read'] as List? ?? [])
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _isLoading = false;

        // Debug logging to understand the data structure
        if (_deliveredTo.isNotEmpty) {
          debugPrint('First delivered user data: ${_deliveredTo.first}');
        }
        if (_readBy.isNotEmpty) {
          debugPrint('First read user data: ${_readBy.first}');
        }
      });
    } catch (e) {
      debugPrint('Error fetching message status: $e');
      setState(() {
        _errorMessage = 'Failed to load message info: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1a1d21) : Colors.white,
      appBar: const DetailAppBar(
        pageTitle: 'Message Info',
        showNotifications: false,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _fetchMessageStatus();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final readUsers = _readBy;
    final deliveredUsers = _deliveredTo;

    return Column(
      children: [
        // Message content section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1a1d21) : const Color(0xFFf8f9fa),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF3a3f45) : const Color(0xFFdee2e6),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatMessageDate(widget.message.createdAt),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                child: MessageBubbleFactory(
                  message: widget.message,
                  club: widget.club ?? Club(
                    id: 'temp',
                    name: 'Club',
                    description: 'Temporary club for display',
                    isVerified: false,
                    membershipFee: 0.0,
                    membershipFeeCurrency: 'INR',
                    upiIdCurrency: 'INR',
                  ),
                  isOwn: true,
                  isPinned: false,
                  isDeleted: widget.message.deleted,
                  isSelected: false,
                  showSenderInfo: false,
                  isLastFromSender: true,
                  canPinMessages: false,
                  canDeleteMessages: false,
                  isSelectionMode: false,
                ),
              ),
            ],
          ),
        ),

        // Tab bar
        Container(
          color: isDark ? const Color(0xFF1a1d21) : Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: isDark
                ? Colors.lightBlueAccent
                : const Color(0xFF003f9b),
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
            indicatorColor: isDark
                ? Colors.lightBlueAccent
                : const Color(0xFF003f9b),
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
            tabs: [
              Tab(text: 'Seen (${readUsers.length})'),
              Tab(text: 'Delivered (${deliveredUsers.length})'),
            ],
          ),
        ),

        // Tab Bar View
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUserList(readUsers, 'seen', isDark),
              _buildUserList(deliveredUsers, 'delivered', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users,
    String type,
    bool isDark,
  ) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'seen'
                  ? Icons.check_circle_outline
                  : Icons.check_outlined,
              size: 48,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'seen'
                  ? 'No one has seen this message yet'
                  : 'Message not delivered to anyone yet',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user, type, isDark);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, String type, bool isDark) {
    // Try multiple possible keys for user name
    String name = user['name'] ??
                  user['userName'] ??
                  user['displayName'] ??
                  user['fullName'] ??
                  user['user']?['name'] ??
                  user['user']?['userName'] ??
                  'User';

    // If we still have 'User' and we have an ID, try to find the user in club members
    if (name == 'User' && user['id'] != null) {
      try {
        final matchingMember = widget.clubMembers.firstWhere(
          (member) => member['id'] == user['id'] || member['_id'] == user['id'],
        );
        name = matchingMember['name'] ??
               matchingMember['userName'] ??
               matchingMember['displayName'] ??
               'Club Member';
      } catch (e) {
        // Member not found in club members list
        name = 'Club Member';
      }
    }

    final profilePicture = user['profilePicture'] ??
                          user['avatar'] ??
                          user['profileImage'] ??
                          user['user']?['profilePicture'];
    final timestamp = user['at'] ?? user['timestamp'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2a2f32) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Avatar with SVG support and proper fallback
          SVGAvatar(
            imageUrl: profilePicture != null && profilePicture.isNotEmpty
                ? profilePicture
                : null,
            size: 44,
            backgroundColor: const Color(0xFF003f9b),
            iconColor: Colors.white,
            fallbackIcon: Icons.person,
            fallbackText: name.isNotEmpty ? name[0].toUpperCase() : '?',
            fallbackTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Club Member',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black87,
                  ),
                ),
                if (timestamp != null)
                  Text(
                    _formatTimestamp(timestamp, type),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  )
                else
                  Text(
                    'Member',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),

          // Status icon
          Icon(
            type == 'seen' ? Icons.check_circle : Icons.check,
            color: type == 'seen' ? Colors.green : const Color(0xFF06aeef),
            size: 24,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp, String type) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      String timeAgo;
      if (difference.inMinutes < 1) {
        timeAgo = 'just now';
      } else if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        timeAgo = '${difference.inDays}d ago';
      } else {
        timeAgo = '${(difference.inDays / 7).floor()}w ago';
      }

      return '${type == 'seen' ? 'Seen' : 'Delivered'} $timeAgo';
    } catch (e) {
      return type == 'seen' ? 'Seen' : 'Delivered';
    }
  }

  String _formatMessageDate(DateTime messageDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(messageDate.year, messageDate.month, messageDate.day);
    final difference = today.difference(messageDay).inDays;

    if (messageDay == today) {
      return 'Today';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else if (difference <= 6) {
      // Show weekday for messages within the last week
      return DateFormat('EEEE').format(messageDate);
    } else if (messageDate.year == now.year) {
      // Show date without year for messages from this year
      return DateFormat('MMMM d').format(messageDate);
    } else {
      // Show full date for messages from previous years
      return DateFormat('MMMM d, yyyy').format(messageDate);
    }
  }

}