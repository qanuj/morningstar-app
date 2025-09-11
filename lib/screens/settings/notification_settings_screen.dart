import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final enabled = await NotificationService.areNotificationsEnabled();
      
      setState(() {
        _notificationsEnabled = enabled;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Notification Settings'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryBlue,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main notification toggle
                  _buildMainToggleCard(),
                  
                  SizedBox(height: 24),
                  
                  // Information section
                  if (_notificationsEnabled) _buildInfoSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildMainToggleCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _notificationsEnabled 
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                    color: _notificationsEnabled ? AppTheme.primaryBlue : Colors.grey,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _notificationsEnabled 
                            ? 'Stay updated with club activities'
                            : 'Enable to receive important updates',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeColor: AppTheme.primaryBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You will receive notifications for:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 16),
            _buildNotificationItem(
              icon: Icons.sports_cricket,
              title: 'Match Updates',
              description: 'Match schedules, results, and team announcements',
            ),
            SizedBox(height: 12),
            _buildNotificationItem(
              icon: Icons.shopping_bag,
              title: 'Order Updates',
              description: 'Order confirmations and delivery status',
            ),
            SizedBox(height: 12),
            _buildNotificationItem(
              icon: Icons.campaign,
              title: 'Club Announcements',
              description: 'Important club news and updates',
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.lightBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can manage detailed notification preferences in your device settings.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryBlue,
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
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.check_circle,
          color: AppTheme.successGreen,
          size: 20,
        ),
      ],
    );
  }
}