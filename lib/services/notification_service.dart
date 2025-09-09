import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static String? _fcmToken;
  
  // Notification channel details
  static const String _channelId = 'duggy_notifications';
  static const String _channelName = 'Duggy Notifications';
  static const String _channelDescription = 'Notifications from Duggy cricket club app';

  /// Initialize push notifications
  static Future<void> initialize() async {
    print('🔔 Initializing NotificationService...');
    
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request notification permissions
      await _requestPermissions();
      
      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();
      
      // Get and save FCM token
      await _getFCMToken();
      
      // Setup message handlers
      _setupMessageHandlers();
      
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize NotificationService: $e');
    }
  }

  /// Initialize local notifications plugin
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
    }
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      // Request iOS notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('⚠️ iOS notification permission denied');
        return;
      }
    }
    
    if (Platform.isAndroid) {
      // Request Android notification permission (API 33+)
      final status = await Permission.notification.request();
      if (status.isDenied) {
        print('⚠️ Android notification permission denied');
      }
    }
  }

  /// Initialize Firebase messaging
  static Future<void> _initializeFirebaseMessaging() async {
    // Enable auto initialization
    await _firebaseMessaging.setAutoInitEnabled(true);
    
    // Set foreground notification presentation options for iOS
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Get FCM token and send to server
  static Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        print('📱 FCM Token: $_fcmToken');
        await _sendTokenToServer(_fcmToken!);
      }
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _sendTokenToServer(newToken);
      });
    } catch (e) {
      print('❌ Failed to get FCM token: $e');
    }
  }

  /// Send FCM token to server
  static Future<void> _sendTokenToServer(String token) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user['user']?['id'] != null) {
        await ApiService.post('/notifications/register-token', {
          'userId': user['user']['id'],
          'fcmToken': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'appVersion': '1.0.0', // TODO: Get from package info
        });
        print('✅ FCM token sent to server');
      }
    } catch (e) {
      print('❌ Failed to send FCM token to server: $e');
    }
  }

  /// Setup message handlers
  static void _setupMessageHandlers() {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Received foreground message: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // Handle message opened from terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Message opened app: ${message.messageId}');
      _handleNotificationTapped(message.data);
    });

    // Check for initial message (app opened from terminated state)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 Initial message: ${message.messageId}');
        _handleNotificationTapped(message.data);
      }
    });
  }

  /// Handle foreground messages by showing local notification
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: const Color(0xFF003f9b),
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: data.isNotEmpty ? data.toString() : null,
      );
    }
  }

  /// Handle notification tapped from local notifications
  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      // Parse payload and handle navigation
      _handleNotificationTapped(_parsePayload(response.payload!));
    }
  }

  /// Parse payload string back to map
  static Map<String, dynamic> _parsePayload(String payload) {
    try {
      // Simple parsing - in production you'd use JSON
      // For now, just return empty map
      return <String, dynamic>{};
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  /// Handle notification tapped - navigate to appropriate screen
  static void _handleNotificationTapped(Map<String, dynamic> data) {
    print('📱 Handling notification tap with data: $data');
    
    final type = data['type'] as String?;
    final clubId = data['clubId'] as String?;
    final matchId = data['matchId'] as String?;
    final orderId = data['orderId'] as String?;
    
    // TODO: Implement navigation based on notification type
    switch (type) {
      case 'match_reminder':
        print('🏏 Navigate to match: $matchId');
        break;
      case 'order_update':
        print('🛒 Navigate to order: $orderId');
        break;
      case 'club_announcement':
        print('📢 Navigate to club: $clubId');
        break;
      case 'payment_reminder':
        print('💳 Navigate to transactions');
        break;
      default:
        print('📱 Open app home screen');
    }
  }

  /// Get current FCM token
  static String? get fcmToken => _fcmToken;

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isIOS) {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } else {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
  }

  /// Show permission request dialog
  static Future<bool> requestNotificationPermission() async {
    if (Platform.isIOS) {
      NotificationSettings settings = await _firebaseMessaging.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } else {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Failed to subscribe to topic $topic: $e');
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Failed to unsubscribe from topic $topic: $e');
    }
  }

  /// Subscribe to club-specific topics
  static Future<void> subscribeToClubTopics(String clubId) async {
    await subscribeToTopic('club_$clubId');
    await subscribeToTopic('club_${clubId}_matches');
    await subscribeToTopic('club_${clubId}_orders');
    await subscribeToTopic('club_${clubId}_announcements');
  }

  /// Unsubscribe from club-specific topics
  static Future<void> unsubscribeFromClubTopics(String clubId) async {
    await unsubscribeFromTopic('club_$clubId');
    await unsubscribeFromTopic('club_${clubId}_matches');
    await unsubscribeFromTopic('club_${clubId}_orders');
    await unsubscribeFromTopic('club_${clubId}_announcements');
  }
}

/// Background message handler (must be top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message received: ${message.messageId}');
  print('📨 Title: ${message.notification?.title}');
  print('📨 Body: ${message.notification?.body}');
  print('📨 Data: ${message.data}');
}