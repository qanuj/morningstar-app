import 'package:duggy/screens/news/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/club_provider.dart';
import '../../models/conversation.dart';
import '../../models/club.dart';
import '../../utils/theme.dart';
import '../shared/chat_detail.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ConversationsScreen extends StatefulWidget {
  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Fetch conversations when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().fetchConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _ConversationsAppBar(onSearchPressed: _showSearchDialog),
      body: Consumer<ConversationProvider>(
        builder: (context, conversationProvider, child) {
          if (conversationProvider.isLoading &&
              conversationProvider.conversations.isEmpty) {
            return _buildLoadingState();
          }

          if (conversationProvider.error != null &&
              conversationProvider.conversations.isEmpty) {
            return _buildErrorState(conversationProvider.error!);
          }

          // Show only news/announcements - no tabs
          return _buildConversationsList(
            conversationProvider
                .getConversationsByType(ConversationType.announcement)
                .where(
                  (c) => c.title.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildConversationsList(List<ConversationModel> conversations) {
    if (conversations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<ConversationProvider>().refreshConversations(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return _buildConversationCard(conversation);
        },
      ),
    );
  }

  Widget _buildConversationCard(ConversationModel conversation) {
    final userProvider = context.read<UserProvider>();
    final isUnread = conversation.unreadCount > 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        elevation: isUnread ? 4 : 2,
        child: InkWell(
          onTap: () => _openConversation(conversation),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Conversation Avatar/Icon
                _buildConversationAvatar(conversation),
                SizedBox(width: 12),

                // Conversation Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.lastMessage != null) ...[
                            SizedBox(width: 8),
                            Text(
                              _formatTime(conversation.lastMessage!.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: isUnread
                                    ? Theme.of(context).primaryColor
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                fontWeight: isUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: 4),

                      // Last message or description
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage?.content ??
                                  conversation.description ??
                                  'No messages yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: isUnread
                                    ? Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.color
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                fontWeight: isUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Unread badge
                          if (isUnread) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : conversation.unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Conversation type indicator
                      if (conversation.type != ConversationType.group) ...[
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(
                              conversation.type,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getTypeLabel(conversation.type),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getTypeColor(conversation.type),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationAvatar(ConversationModel conversation) {
    IconData icon;
    Color color;

    switch (conversation.type) {
      case ConversationType.announcement:
        icon = Icons.campaign_outlined;
        color = AppTheme.warningOrange;
        break;
      case ConversationType.group:
        icon = Icons.group_outlined;
        color = AppTheme.primaryBlue;
        break;
      case ConversationType.general:
        icon = Icons.chat_outlined;
        color = AppTheme.lightBlue;
        break;
      case ConversationType.private:
        icon = Icons.person_outline;
        color = AppTheme.successGreen;
        break;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getTypeColor(ConversationType type) {
    switch (type) {
      case ConversationType.announcement:
        return AppTheme.warningOrange;
      case ConversationType.group:
        return AppTheme.primaryBlue;
      case ConversationType.general:
        return AppTheme.lightBlue;
      case ConversationType.private:
        return AppTheme.successGreen;
    }
  }

  String _getTypeLabel(ConversationType type) {
    switch (type) {
      case ConversationType.announcement:
        return 'Announcement';
      case ConversationType.group:
        return 'Group';
      case ConversationType.general:
        return 'General';
      case ConversationType.private:
        return 'Private';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _openConversation(ConversationModel conversation) {
    HapticFeedback.lightImpact();
    context.read<ConversationProvider>().selectConversation(conversation);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(conversation: conversation),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Conversations'),
        content: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter search term...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading conversations...',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            SizedBox(height: 16),
            Text(
              'Unable to load conversations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  context.read<ConversationProvider>().fetchConversations(),
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start engaging with your club community!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubsList() {
    return Consumer<ClubProvider>(
      builder: (context, clubProvider, child) {
        if (clubProvider.isLoading) {
          return _buildLoadingState();
        }

        if (clubProvider.clubs.isEmpty) {
          return _buildEmptyClubsState();
        }

        return RefreshIndicator(
          onRefresh: () => clubProvider.loadClubs(),
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: clubProvider.clubs.length,
            itemBuilder: (context, index) {
              final clubMembership = clubProvider.clubs[index];
              return _buildClubCard(clubMembership);
            },
          ),
        );
      },
    );
  }

  Widget _buildClubCard(ClubMembership clubMembership) {
    final club = clubMembership.club;
    final isCurrentClub =
        context.read<ClubProvider>().currentClub?.club.id == club.id;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        elevation: isCurrentClub ? 4 : 2,
        child: InkWell(
          onTap: () => _selectClub(clubMembership),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isCurrentClub
                  ? Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                      width: 2,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Club Logo
                _buildClubLogo(club),
                SizedBox(width: 16),

                // Club Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              club.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isCurrentClub
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentClub) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (club.isVerified) ...[
                            SizedBox(width: 8),
                            Icon(
                              Icons.verified,
                              color: Theme.of(context).primaryColor,
                              size: 18,
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: 4),

                      // Role and location info
                      Row(
                        children: [
                          // Role badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(
                                clubMembership.role,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              clubMembership.role,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getRoleColor(clubMembership.role),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          if (club.city != null) ...[
                            SizedBox(width: 8),
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                            SizedBox(width: 2),
                            Text(
                              club.city!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (club.description != null) ...[
                        SizedBox(height: 6),
                        Text(
                          club.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(width: 12),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClubLogo(Club club) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: club.logo != null
            ? Image.network(
                club.logo!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultClubLogo(club.name);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildDefaultClubLogo(club.name);
                },
              )
            : _buildDefaultClubLogo(club.name),
      ),
    );
  }

  Widget _buildDefaultClubLogo(String clubName) {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          clubName.isNotEmpty ? clubName.substring(0, 1).toUpperCase() : 'C',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
      case 'ADMIN':
        return AppTheme.warningOrange;
      case 'CAPTAIN':
      case 'VICE_CAPTAIN':
        return AppTheme.primaryBlue;
      case 'MEMBER':
      default:
        return AppTheme.successGreen;
    }
  }

  void _selectClub(ClubMembership clubMembership) async {
    HapticFeedback.lightImpact();

    // Set as current club
    await context.read<ClubProvider>().setCurrentClub(clubMembership);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${clubMembership.club.name}'),
        duration: Duration(seconds: 2),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );

    // Refresh conversations for the new club
    context.read<ConversationProvider>().fetchConversations();
  }

  Widget _buildEmptyClubsState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            SizedBox(height: 16),
            Text(
              'No clubs found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Join a club to start chatting with other members!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final VoidCallback onSearchPressed;

  const _ConversationsAppBar({Key? key, required this.onSearchPressed})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColorDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          width: 40,
          height: 40,
          padding: EdgeInsets.all(8),
          child: SvgPicture.asset(
            'assets/images/duggy_logo.svg',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duggy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Consumer<ConversationProvider>(
              builder: (context, conversationProvider, child) {
                final unreadCount = conversationProvider.totalUnreadCount;
                if (unreadCount > 0) {
                  return Text(
                    '$unreadCount unread ${unreadCount == 1 ? 'announcement' : 'announcements'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  );
                } else {
                  return Text(
                    'Latest updates from your club',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NotificationsScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.notifications,
              color: Colors.white,
              size: 24,
            ),
            tooltip: 'Notifications',
            padding: EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
