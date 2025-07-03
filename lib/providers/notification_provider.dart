import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  String _filter = 'all'; // all, unread, read

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  String get filter => _filter;

  List<NotificationModel> get filteredNotifications {
    switch (_filter) {
      case 'unread':
        return _notifications.where((notification) => !notification.isRead).toList();
      case 'read':
        return _notifications.where((notification) => notification.isRead).toList();
      default:
        return _notifications;
    }
  }

  List<NotificationModel> get unreadNotifications => 
    _notifications.where((notification) => !notification.isRead).toList();

  List<NotificationModel> get readNotifications => 
    _notifications.where((notification) => notification.isRead).toList();

  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.get('/notifications');
      _notifications = (response['notifications'] as List)
          .map((notification) => NotificationModel.fromJson(notification))
          .toList();
      _unreadCount = response['unreadCount'] ?? 0;
    } catch (e) {
      print('Error loading notifications: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await ApiService.put('/notifications/$notificationId/read', {});
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
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
        
        notifyListeners();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiService.put('/notifications/read-all', {});
      
      // Update all notifications to read
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
      notifyListeners();
    } catch (e) {
      print('Error marking all notifications as read: $e');
      throw e;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await ApiService.delete('/notifications/$notificationId');
      
      // Remove from local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        if (!_notifications[index].isRead && _unreadCount > 0) {
          _unreadCount--;
        }
        _notifications.removeAt(index);
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting notification: $e');
      throw e;
    }
  }

  NotificationModel? getNotificationById(String id) {
    try {
      return _notifications.firstWhere((notification) => notification.id == id);
    } catch (e) {
      return null;
    }
  }

  List<NotificationModel> getNotificationsByType(String type) {
    return _notifications.where((notification) => notification.type == type).toList();
  }

  List<NotificationModel> getNotificationsByClub(String clubId) {
    return _notifications.where((notification) => 
      notification.club?.id == clubId
    ).toList();
  }

  IconData getNotificationIcon(String? type) {
    switch (type) {
      case 'RSVP_REMINDER':
        return Icons.sports_cricket;
      case 'FEE_DUE':
        return Icons.payment;
      case 'MATCH_UPDATE':
        return Icons.update;
      case 'ORDER_UPDATE':
        return Icons.shopping_bag;
      case 'POLL_CREATED':
        return Icons.poll;
      case 'CLUB_ANNOUNCEMENT':
        return Icons.announcement;
      default:
        return Icons.notifications;
    }
  }

  String getNotificationTypeText(String? type) {
    switch (type) {
      case 'RSVP_REMINDER':
        return 'RSVP Reminder';
      case 'FEE_DUE':
        return 'Fee Due';
      case 'MATCH_UPDATE':
        return 'Match Update';
      case 'ORDER_UPDATE':
        return 'Order Update';
      case 'POLL_CREATED':
        return 'New Poll';
      case 'CLUB_ANNOUNCEMENT':
        return 'Club Announcement';
      default:
        return 'Notification';
    }
  }

  bool hasUnreadNotifications() {
    return _unreadCount > 0;
  }
}