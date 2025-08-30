import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import '../utils/dialogs.dart';
import 'login.dart';
import 'edit_profile.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: Consumer2<UserProvider, ClubProvider>(
        builder: (context, userProvider, clubProvider, child) {
          final user = userProvider.user;
          final currentClub = clubProvider.currentClub;

          if (user == null) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.cricketGreen,
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header
                Container(
                  decoration: AppTheme.elevatedCardDecoration,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: AppTheme.cricketGreen,
                            backgroundImage: user.profilePicture != null
                                ? NetworkImage(user.profilePicture!)
                                : null,
                            child: user.profilePicture == null
                                ? Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: AppTheme.surfaceColor,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cricketGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            user.phoneNumber,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.cricketGreen,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        if (user.email != null) ...[
                          SizedBox(height: 8),
                          Text(
                            user.email!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(),
                                ),
                              );
                            },
                            icon: Icon(Icons.edit, size: 18),
                            label: Text('Edit Profile'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cricketGreen,
                              foregroundColor: AppTheme.surfaceColor,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Account Stats
                Container(
                  decoration: AppTheme.softCardDecoration,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.cricketGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.analytics,
                                color: AppTheme.cricketGreen,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Account Overview',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Total Balance',
                                '₹${user.balance.toStringAsFixed(0)}',
                                Icons.account_balance_wallet,
                                AppTheme.successGreen,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Total Spent',
                                '₹${user.totalExpenses.toStringAsFixed(0)}',
                                Icons.receipt,
                                AppTheme.warningOrange,
                              ),
                            ),
                          ],
                        ),
                        if (currentClub != null) ...[
                          SizedBox(height: 16),
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
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Club Role',
                                  currentClub.role,
                                  Icons.person,
                                  AppTheme.lightBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Profile Status
                Container(
                  decoration: AppTheme.softCardDecoration,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.cricketGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.verified_user,
                                color: AppTheme.cricketGreen,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Profile Status',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
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

                SizedBox(height: 20),

                // Settings
                Container(
                  decoration: AppTheme.softCardDecoration,
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        onTap: () {
                          // TODO: Navigate to notifications settings
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.dividerColor.withOpacity(0.3),
                      ),
                      _buildSettingsItem(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {
                          // TODO: Navigate to help
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.dividerColor.withOpacity(0.3),
                      ),
                      _buildSettingsItem(
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () {
                          AppDialogs.showAboutDialog(context);
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppTheme.dividerColor.withOpacity(0.3),
                      ),
                      _buildSettingsItem(
                        icon: Icons.logout,
                        title: 'Logout',
                        titleColor: AppTheme.errorRed,
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
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isComplete, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete
            ? AppTheme.successGreen.withOpacity(0.1)
            : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isComplete
              ? AppTheme.successGreen.withOpacity(0.3)
              : AppTheme.dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isComplete
                  ? AppTheme.successGreen.withOpacity(0.2)
                  : AppTheme.dividerColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isComplete
                  ? AppTheme.successGreen
                  : AppTheme.secondaryTextColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
          Icon(
            isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isComplete
                ? AppTheme.successGreen
                : AppTheme.secondaryTextColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: titleColor != null
                      ? titleColor.withOpacity(0.1)
                      : AppTheme.cricketGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: titleColor ?? AppTheme.cricketGreen,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: titleColor ?? AppTheme.primaryTextColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.secondaryTextColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

}
