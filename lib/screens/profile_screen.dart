import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, ClubProvider>(
      builder: (context, userProvider, clubProvider, child) {
        final user = userProvider.user;
        final currentClub = clubProvider.currentClub;

        if (user == null) {
          return Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Header
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.cricketGreen,
                        backgroundImage: user.profilePicture != null
                            ? NetworkImage(user.profilePicture!)
                            : null,
                        child: user.profilePicture == null
                            ? Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(height: 16),
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        user.phoneNumber,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (user.email != null) ...[
                        SizedBox(height: 4),
                        Text(
                          user.email!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EditProfileScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.edit, color: Colors.white),
                              label: Text(
                                'Edit Profile',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.cricketGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Account Stats
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Balance',
                              '₹${user.balance.toStringAsFixed(0)}',
                              Icons.account_balance_wallet,
                              Colors.green,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total Spent',
                              '₹${user.totalExpenses.toStringAsFixed(0)}',
                              Icons.receipt,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (currentClub != null) ...[
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Club Points',
                                '${currentClub.points}',
                                Icons.star,
                                AppTheme.cricketGreen,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Club Role',
                                currentClub.role,
                                Icons.person,
                                Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Profile Status
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildStatusRow(
                        'Phone Verified',
                        user.phoneNumber.isNotEmpty,
                        Icons.phone,
                      ),
                      _buildStatusRow(
                        'Profile Complete',
                        user.isProfileComplete,
                        Icons.person,
                      ),
                      _buildStatusRow(
                        'Account Verified',
                        user.isVerified,
                        Icons.verified_user,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Settings
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.notifications, color: AppTheme.cricketGreen),
                      title: Text('Notifications'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: Navigate to notifications settings
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.help, color: AppTheme.cricketGreen),
                      title: Text('Help & Support'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: Navigate to help
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.info, color: AppTheme.cricketGreen),
                      title: Text('About'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        _showAboutDialog(context);
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () => _showLogoutDialog(context),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isComplete, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: isComplete ? Colors.green : Colors.grey,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14),
            ),
          ),
          Icon(
            isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isComplete ? Colors.green : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await AuthService.logout();
              Provider.of<UserProvider>(context, listen: false).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sports_cricket, color: AppTheme.cricketGreen),
            SizedBox(width: 8),
            Text('About Duggy'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duggy - Your Cricket Club Companion',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 8),
            Text(
              'Manage your cricket club activities, matches, store orders, and more with Duggy.',
            ),
            SizedBox(height: 16),
            Text(
              'Visit duggy.app for more information.',
              style: TextStyle(
                color: AppTheme.cricketGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
