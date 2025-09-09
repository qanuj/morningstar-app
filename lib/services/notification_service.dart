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
  
  // Callbacks for real-time message updates by club
  static final Map<String, Function(Map<String, dynamic>)> _clubMessageCallbacks = {};
  
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

  /// Get FCM token and optionally send to server
  static Future<void> _getFCMToken() async {
    try {
      // For iOS, ensure APNS token is available first
      if (Platform.isIOS) {
        try {
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            print('🍎 APNS Token received: ${apnsToken.substring(0, 20)}...');
          } else {
            print('⚠️ APNS Token not available yet, waiting...');
            // Wait a bit for APNS token to become available
            await Future.delayed(const Duration(seconds: 2));
            apnsToken = await _firebaseMessaging.getAPNSToken();
            if (apnsToken != null) {
              print('🍎 APNS Token received after delay: ${apnsToken.substring(0, 20)}...');
            } else {
              print('❌ APNS Token still not available after delay');
            }
          }
        } catch (e) {
          print('⚠️ Failed to get APNS token: $e');
        }
      }
      
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        print('📱 FCM Token: $_fcmToken');
        // Don't send token to server during initialization - will be sent after login
      }
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        // Only send refreshed token if user is authenticated
        _sendTokenToServerIfAuthenticated(newToken);
      });
    } catch (e) {
      print('❌ Failed to get FCM token: $e');
    }
  }

  /// Send FCM token to server
  static Future<void> _sendTokenToServer(String token) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user['id'] != null) {
        await ApiService.post('/notifications/register-token', {
          'userId': user['id'],
          'fcmToken': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'appVersion': '1.0.0', // TODO: Get from package info
        });
        print('✅ FCM token sent to server successfully');
      } else {
        print('⚠️ No authenticated user found, FCM token not sent');
      }
    } catch (e) {
      print('❌ Failed to send FCM token to server: $e');
    }
  }

  /// Send FCM token to server if user is authenticated (for token refresh)
  static Future<void> _sendTokenToServerIfAuthenticated(String token) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user['id'] != null) {
        await _sendTokenToServer(token);
      } else {
        print('⚠️ User not authenticated, skipping FCM token refresh');
      }
    } catch (e) {
      // Silently ignore errors for token refresh
      print('⚠️ Failed to send refreshed FCM token: $e');
    }
  }

  /// Send FCM token to server with provided user data (avoids additional API call)
  static Future<void> _sendTokenToServerWithUserData(String token, Map<String, dynamic>? userData) async {
    try {
      if (userData != null && userData['id'] != null) {
        await ApiService.post('/notifications/register-token', {
          'userId': userData['id'],
          'fcmToken': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'appVersion': '1.0.0', // TODO: Get from package info
        });
        print('✅ FCM token sent to server successfully');
      } else {
        // Fallback to regular method if user data not provided
        await _sendTokenToServer(token);
      }
    } catch (e) {
      print('❌ Failed to send FCM token to server: $e');
    }
  }

  /// Register FCM token after user authentication with user data
  static Future<void> registerTokenAfterAuth({Map<String, dynamic>? userData}) async {
    try {
      if (_fcmToken != null) {
        await _sendTokenToServerWithUserData(_fcmToken!, userData);
      } else {
        // Try to get token if not available
        await _getFCMToken();
        if (_fcmToken != null) {
          await _sendTokenToServerWithUserData(_fcmToken!, userData);
        }
      }
    } catch (e) {
      print('❌ Failed to register FCM token after auth: $e');
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

    // Handle club message notifications specially
    if (data['type'] == 'club_message') {
      await _handleClubMessageNotification(message, inForeground: true);
      return;
    }

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

  /// Handle club message notifications
  static Future<void> _handleClubMessageNotification(RemoteMessage message, {required bool inForeground}) async {
    final data = message.data;
    print('💬 Handling club message notification: $data');

    // Always trigger the callback if registered, regardless of foreground/background state
    final clubId = data['clubId'] as String?;
    if (clubId != null && _clubMessageCallbacks.containsKey(clubId)) {
      print('🔄 Triggering real-time chat update via callback for club: $clubId');
      _clubMessageCallbacks[clubId]!(data);
    } else {
      print('ℹ️ No club message callback registered for club: $clubId');
    }

    // Show local notification (even in foreground for messages)
    final notification = message.notification;
    if (notification != null) {
      await _localNotifications.show(
        message.hashCode,
        notification.title ?? 'New Message',
        notification.body ?? 'You have a new message',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'club_messages',
            'Club Messages',
            channelDescription: 'Messages from your cricket club',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: const Color(0xFF06aeef), // Use blue color for messages
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: 'MESSAGE_CATEGORY',
          ),
        ),
        payload: data.toString(),
      );
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
      case 'club_message':
        print('💬 Navigate to club chat: $clubId');
        // TODO: Navigate to specific club chat
        break;
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

  /// Set callback for real-time club message updates
  static void setClubMessageCallback(String clubId, Function(Map<String, dynamic>) callback) {
    _clubMessageCallbacks[clubId] = callback;
    print('✅ Club message callback registered for club: $clubId');
  }

  /// Clear callback for real-time club message updates
  static void clearClubMessageCallback(String clubId) {
    _clubMessageCallbacks.remove(clubId);
    print('🗑️ Club message callback cleared for club: $clubId');
  }

  /// Clear all callbacks
  static void clearAllClubMessageCallbacks() {
    _clubMessageCallbacks.clear();
    print('🗑️ All club message callbacks cleared');
  }
}

/// Background message handler (must be top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message received: ${message.messageId}');
  print('📨 Title: ${message.notification?.title}');
  print('📨 Body: ${message.notification?.body}');
  print('📨 Data: ${message.data}');
  
  // Handle club message notifications in background
  if (message.data['type'] == 'club_message') {
    print('💬 Background club message notification received');
    // Trigger callback if registered (though it usually won't be in background)
    final clubId = message.data['clubId'] as String?;
    if (clubId != null && NotificationService._clubMessageCallbacks.containsKey(clubId)) {
      print('🔄 Triggering callback from background for club: $clubId');
      NotificationService._clubMessageCallbacks[clubId]!(message.data);
    }
  }
}