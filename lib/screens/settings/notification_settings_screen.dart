import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/notification_service.dart';
import '../../utils/theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  NotificationSettingsScreenState createState() => NotificationSettingsScreenState();
}

class NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = false;
  bool _notificationsEnabled = false;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final enabled = await NotificationService.areNotificationsEnabled();
      final token = NotificationService.fcmToken;
      
      setState(() {
        _notificationsEnabled = enabled;
        _fcmToken = token;
      });
    } catch (e) {
      print('Error loading notification status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.requestNotificationPermission();
      if (granted) {
        setState(() => _notificationsEnabled = true);
        _showSnackBar('Notifications enabled successfully', isError: false);
      } else {
        setState(() => _notificationsEnabled = false);
        _showSnackBar('Notification permission denied', isError: true);
      }
    } else {
      setState(() => _notificationsEnabled = false);
      _showSnackBar('Please disable notifications in system settings', isError: false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
      ),
    );
  }

  Future<void> _testNotification() async {
    _showSnackBar('Test notification feature would be implemented with server integration', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.back,
            color: CupertinoColors.systemBlue,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          'Notification Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
      ),
      child: _isLoading
          ? Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 20),
                  
                  // Notifications Status Card
                  _buildNotificationStatusCard(),
                  
                  SizedBox(height: 20),
                  
                  // Notification Types Card
                  _buildNotificationTypesCard(),
                  
                  SizedBox(height: 20),
                  
                  // FCM Token Info (for debugging)
                  if (_fcmToken != null) _buildTokenInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationStatusCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _notificationsEnabled ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
                  color: _notificationsEnabled ? AppTheme.successGreen : AppTheme.errorRed,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                        ),
                      ),
                      Text(
                        _notificationsEnabled 
                          ? 'Enabled - You\'ll receive club updates'
                          : 'Disabled - You won\'t receive notifications',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeColor: AppTheme.primaryBlue,
                ),
              ],
            ),
          ),
          if (_notificationsEnabled) ...[
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(16),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _testNotification,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.bell_circle, size: 20, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      'Test Notification',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationTypesCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Notification Types',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
          ),
          _buildNotificationTypeItem(
            icon: CupertinoIcons.sportscourt,
            title: 'Match Updates',
            description: 'Match schedules, results, and reminders',
            enabled: _notificationsEnabled,
          ),
          _buildNotificationTypeItem(
            icon: CupertinoIcons.bag,
            title: 'Order Updates',
            description: 'Order status and delivery updates',
            enabled: _notificationsEnabled,
          ),
          _buildNotificationTypeItem(
            icon: CupertinoIcons.money_dollar_circle,
            title: 'Payment Reminders',
            description: 'Due payments and transaction updates',
            enabled: _notificationsEnabled,
          ),
          _buildNotificationTypeItem(
            icon: CupertinoIcons.speaker_2,
            title: 'Club Announcements',
            description: 'Important club news and updates',
            enabled: _notificationsEnabled,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTypeItem({
    required IconData icon,
    required String title,
    required String description,
    required bool enabled,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled 
                    ? AppTheme.primaryBlue.withOpacity(0.1)
                    : CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: enabled ? AppTheme.primaryBlue : CupertinoColors.systemGrey,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: enabled ? CupertinoColors.label : CupertinoColors.systemGrey,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled 
                          ? CupertinoColors.secondaryLabel 
                          : CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: enabled ? AppTheme.successGreen : CupertinoColors.systemGrey4,
                size: 20,
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 64),
      ],
    );
  }

  Widget _buildTokenInfoCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.device_phone_portrait, 
                     color: CupertinoColors.systemGrey, size: 20),
                SizedBox(width: 8),
                Text(
                  'Device Token',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _fcmToken!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: CupertinoColors.secondaryLabel,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This token identifies your device for push notifications',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}