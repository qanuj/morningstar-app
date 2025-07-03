import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get('/notifications');
      setState(() {
        _notifications = (response as List)
            .map((notification) => NotificationModel.fromJson(notification))
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load notifications: $e')),
      );
    }

    setState(() => _isLoading = false);
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
          );
        }
      });
    } catch (e) {
      // Silently fail for mark as read
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.put('/notifications/read-all', {});
      setState(() {
        _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          actionUrl: n.actionUrl,
          isRead: true,
          createdAt: n.createdAt,
        )).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all as read: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        backgroundColor: AppTheme.cricketGreen,
        foregroundColor: Colors.white,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark All Read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: notification.isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: notification.isRead 
                ? Colors.grey[200] 
                : AppTheme.cricketGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: notification.isRead ? Colors.grey : AppTheme.cricketGreen,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(notification.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.cricketGreen,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          if (!notification.isRead) {
            _markAsRead(notification.id);
          }
          // TODO: Handle action URL if present
        },
        isThreeLine: true,
      ),
    );
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
