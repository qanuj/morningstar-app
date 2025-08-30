import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/duggy_logo.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);
  
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_hasNextPage && !_isLoadingMore) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get('/notifications?page=1');
      setState(() {
        _notifications = (response['notifications'] as List)
            .map((notification) => NotificationModel.fromJson(notification))
            .toList();
        _unreadCount = response['unreadCount'] ?? 0;
        _currentPage = 1;
        _hasNextPage = response['hasNextPage'] ?? false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.get('/notifications?page=$nextPage');
      final newNotifications = (response['notifications'] as List)
          .map((notification) => NotificationModel.fromJson(notification))
          .toList();
      
      setState(() {
        _notifications.addAll(newNotifications);
        _currentPage = nextPage;
        _hasNextPage = response['hasNextPage'] ?? false;
      });
    } catch (e) {
      // Silently fail for pagination
    }

    setState(() => _isLoadingMore = false);
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await ApiService.put('/notifications/$notificationId/read', {});
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            title: _notifications[index].title,
            message: _notifications[index].message,
            type: _notifications[index].type,
            actionUrl: _notifications[index].actionUrl,
            isRead: true,
            createdAt: _notifications[index].createdAt,
            updatedAt: _notifications[index].updatedAt,
            club: _notifications[index].club,
          );
          if (_unreadCount > 0) {
            _unreadCount--;
          }
        }
      });
    } catch (e) {
      // Silently fail for mark as read
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final response = await ApiService.put('/notifications/read-all', {});
      setState(() {
        _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          actionUrl: n.actionUrl,
          isRead: true,
          createdAt: n.createdAt,
          updatedAt: n.updatedAt,
          club: n.club,
        )).toList();
        _unreadCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All notifications marked as read (${response['updatedCount']} updated)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await ApiService.delete('/notifications/$notificationId');
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          if (!_notifications[index].isRead && _unreadCount > 0) {
            _unreadCount--;
          }
          _notifications.removeAt(index);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification: $e')),
        );
      }
    }
  }

  Map<String, List<NotificationModel>> _groupNotificationsByDate(List<NotificationModel> notifications) {
    final Map<String, List<NotificationModel>> groupedNotifications = {};
    
    for (final notification in notifications) {
      final dateKey = DateFormat('yyyy-MM-dd').format(notification.createdAt);
      if (!groupedNotifications.containsKey(dateKey)) {
        groupedNotifications[dateKey] = [];
      }
      groupedNotifications[dateKey]!.add(notification);
    }
    
    return groupedNotifications;
  }
  
  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));
    final yesterday = today.subtract(Duration(days: 1));
    final notificationDate = DateTime(date.year, date.month, date.day);
    
    if (notificationDate == today) {
      return 'Today';
    } else if (notificationDate == tomorrow) {
      return 'Tomorrow';
    } else if (notificationDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
  
  Widget _buildDateHeader(String dateKey) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.1)
            : Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatDateHeader(dateKey),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.8)
              : Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  void _showNotificationDetail(NotificationModel notification) {
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Header
                  Row(
                    children: [
                      if (notification.club?.logo != null)
                        Container(
                          width: 40,
                          height: 40,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              notification.club!.logo!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return DuggyLogoVariant.medium();
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 40,
                          height: 40,
                          child: DuggyLogoVariant.medium(),
                        ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.titleLarge?.color,
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(notification.createdAt),
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  
                  // Message content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Handle action URL navigation
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'View Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailAppBar(
        pageTitle: 'Notifications',
        customActions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark All Read ($_unreadCount)',
                style: TextStyle(
                  color: Theme.of(context).appBarTheme.foregroundColor,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).primaryColor,
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_none_outlined,
                          size: 64,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You\'ll be notified about club updates here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: Theme.of(context).primaryColor,
                  child: _buildNotificationList(),
                ),
    );
  }

  Widget _buildNotificationList() {
    final groupedNotifications = _groupNotificationsByDate(_notifications);
    final sortedDateKeys = groupedNotifications.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Latest first

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              int currentIndex = 0;
              
              for (final dateKey in sortedDateKeys) {
                final notifications = groupedNotifications[dateKey]!;
                
                // Date header
                if (index == currentIndex) {
                  return _buildDateHeader(dateKey);
                }
                currentIndex++;
                
                // Notification cards for this date
                for (int i = 0; i < notifications.length; i++) {
                  if (index == currentIndex) {
                    return _buildNotificationCard(notifications[i]);
                  }
                  currentIndex++;
                }
              }
              
              // Loading more indicator
              if (index == currentIndex && _isLoadingMore) {
                return Container(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                );
              }
              
              return SizedBox.shrink();
            },
            childCount: _getChildCount(),
          ),
        ),
      ],
    );
  }

  int _getChildCount() {
    final groupedNotifications = _groupNotificationsByDate(_notifications);
    int count = 0;
    
    // Date headers + notifications count
    for (final entry in groupedNotifications.entries) {
      count += 1; // Date header
      count += entry.value.length; // Notifications
    }
    
    // Add loading indicator if loading more
    if (_isLoadingMore) {
      count += 1;
    }
    
    return count;
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 8, left: 12, right: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 16),
        child: Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Delete Notification'),
              content: Text('Are you sure you want to delete this notification?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        ) ?? false;
      },
      onDismissed: (direction) {
        _deleteNotification(notification.id);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: 12, right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showNotificationDetail(notification),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Club Logo with Notification Badge
                  Stack(
                    children: [
                      // Club Logo (main picture)
                      Container(
                        width: 40,
                        height: 40,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: notification.club?.logo != null
                              ? Image.network(
                                  notification.club!.logo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return DuggyLogoVariant.medium();
                                  },
                                )
                              : DuggyLogoVariant.medium(),
                        ),
                      ),
                      // Notification Type Badge
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _getNotificationTypeColor(notification.type),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF1e1e1e)
                                  : Theme.of(context).cardColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _getNotificationIcon(notification.type),
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                      // Unread indicator
                      if (!notification.isRead)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF1e1e1e)
                                    : Theme.of(context).cardColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 12),
                  
                  // Notification Info (Center)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w500,
                            fontSize: 14,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                            height: 1.2,
                          ),
                        ),
                        if (notification.club != null) ...[
                          SizedBox(height: 2),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.15)
                                  : Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notification.club!.name,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.9)
                                    : Theme.of(context).primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Date and Time (Right)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(notification.createdAt),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getNotificationTypeColor(String? type) {
    switch (type) {
      case 'RSVP_REMINDER':
        return Colors.green;
      case 'FEE_DUE':
        return Colors.orange;
      case 'MATCH_UPDATE':
        return Colors.blue;
      case 'ORDER_UPDATE':
        return Colors.purple;
      case 'ANNOUNCEMENT':
        return Colors.red;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'RSVP_REMINDER':
        return Icons.sports_cricket;
      case 'FEE_DUE':
        return Icons.payment;
      case 'MATCH_UPDATE':
        return Icons.update;
      case 'ORDER_UPDATE':
        return Icons.shopping_bag;
      default:
        return Icons.notifications;
    }
  }
}