import 'package:duggy/services/chat_api_service.dart';
import 'package:flutter/material.dart';
import '../models/club_message.dart';
import 'svg_avatar.dart';

class MessageInfoSheet extends StatefulWidget {
  final ClubMessage message;
  final List<Map<String, dynamic>> clubMembers;

  const MessageInfoSheet({
    super.key,
    required this.message,
    required this.clubMembers,
  });

  @override
  State<MessageInfoSheet> createState() => _MessageInfoSheetState();
}

class _MessageInfoSheetState extends State<MessageInfoSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;
  // Updated to 2 tabs: Seen and Delivered only
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

    if (_isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
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
        ),
      );
    }

    final readUsers = _readBy;
    final deliveredUsers = _deliveredTo;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[600] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
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
              Tab(text: 'Seen ${readUsers.length}'),
              Tab(text: 'Delivered ${deliveredUsers.length}'),
            ],
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
      ),
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
    final name = user['name'] ?? 'Unknown User';
    final profilePicture = user['profilePicture'];
    final timestamp = user['at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            child: profilePicture == null || profilePicture.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Unknown User',
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
}
