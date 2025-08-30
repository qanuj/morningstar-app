import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/user_provider.dart';
import '../models/conversation.dart';
import '../utils/theme.dart';
import '../widgets/custom_app_bar.dart';
import 'chat_detail.dart';

class ConversationsScreen extends StatefulWidget {
  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Fetch conversations when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().fetchConversations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 48),
        child: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          title: Row(
            children: [
              Text(
                'Duggy Conversations',
                style: TextStyle(
                  color: Theme.of(context).appBarTheme.foregroundColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: _showSearchDialog,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Announcements'),
              Tab(text: 'Groups'),
            ],
          ),
        ),
      ),
      body: Consumer<ConversationProvider>(
        builder: (context, conversationProvider, child) {
          if (conversationProvider.isLoading && conversationProvider.conversations.isEmpty) {
            return _buildLoadingState();
          }

          if (conversationProvider.error != null && conversationProvider.conversations.isEmpty) {
            return _buildErrorState(conversationProvider.error!);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildConversationsList(conversationProvider.searchConversations(_searchQuery)),
              _buildConversationsList(
                conversationProvider.getConversationsByType(ConversationType.announcement)
                  .where((c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
                  .toList(),
              ),
              _buildConversationsList(
                conversationProvider.getConversationsByType(ConversationType.group)
                  .where((c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
                  .toList(),
              ),
            ],
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
      onRefresh: () => context.read<ConversationProvider>().refreshConversations(),
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
                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                                color: Theme.of(context).textTheme.titleLarge?.color,
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
                                  : Theme.of(context).textTheme.bodySmall?.color,
                                fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
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
                                  ? Theme.of(context).textTheme.titleMedium?.color
                                  : Theme.of(context).textTheme.bodyMedium?.color,
                                fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Unread badge
                          if (isUnread) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
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
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTypeColor(conversation.type).withOpacity(0.1),
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
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
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
              onPressed: () => context.read<ConversationProvider>().fetchConversations(),
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
}