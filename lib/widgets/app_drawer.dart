import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/profile.dart';
import '../screens/matches.dart';
import '../screens/store.dart';
import '../screens/my_orders.dart';
import '../screens/transactions.dart';
import '../screens/polls.dart';
import '../screens/notifications.dart';
import '../screens/clubs.dart';
import '../utils/navigation_helper.dart';

class AppDrawer extends StatelessWidget {
  final Function(Widget, String)? onNavigate;
  final Function(int)? onTabSwitch; // For switching tabs in home screen

  const AppDrawer({
    super.key,
    this.onNavigate,
    this.onTabSwitch,
  });

  void _navigateToScreen(BuildContext context, Widget screen, String screenName) {
    // Handle bottom tab pages
    if (NavigationHelper.isBottomTabPage(screenName)) {
      final tabIndex = NavigationHelper.getTabIndex(screenName);
      if (tabIndex != null) {
        Navigator.of(context).pop(); // Close drawer first
        if (onTabSwitch != null) {
          // We're on home screen, just switch tabs
          onTabSwitch!(tabIndex);
        } else {
          // Navigate to home screen with specific tab
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
          // Note: We'll need to modify home screen to accept initial tab parameter
        }
        return;
      }
    }
    
    // Handle standalone pages
    if (onNavigate != null) {
      onNavigate!(screen, screenName);
    } else {
      // Default navigation for standalone pages
      Navigator.of(context).pop(); // Close drawer first
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Consumer3<UserProvider, ClubProvider, ThemeProvider>(
        builder: (context, userProvider, clubProvider, themeProvider, child) {
          final user = userProvider.user;
          final currentClub = clubProvider.currentClub;
          return Column(
            children: [
              // Profile Header
              GestureDetector(
                onTap: () {
                  _navigateToScreen(context, ProfileScreen(), 'Profile');
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    bottom: 24,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColorDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(0),
                      bottomRight: Radius.circular(0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // User Picture on Left
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: user?.profilePicture != null
                              ? NetworkImage(user!.profilePicture!)
                              : null,
                          child: user?.profilePicture == null
                              ? Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : null,
                        ),
                      ),
                      SizedBox(width: 16),
                      // User Info on Right
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Guest',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              user?.phoneNumber ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            if (currentClub != null) ...[
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  currentClub.club.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Arrow Icon
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.7),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              // Menu Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  children: [
                    // Navigation
                    _buildSectionHeader(context, 'Navigation'),
                    _buildDrawerItem(
                      context,
                      icon: Icons.home_outlined,
                      title: 'Home',
                      onTap: () {
                        Navigator.of(context).pop(); // Close drawer
                        if (onTabSwitch != null) {
                          onTabSwitch!(0); // Navigate to Home tab
                        }
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.sports_cricket_outlined,
                      title: 'Matches',
                      onTap: () => _navigateToScreen(context, MatchesScreen(), 'Matches'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.store_outlined,
                      title: 'Store',
                      onTap: () => _navigateToScreen(context, StoreScreen(), 'Store'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Transactions',
                      onTap: () => _navigateToScreen(context, TransactionsScreen(), 'Transactions'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.poll_outlined,
                      title: 'Polls',
                      onTap: () => _navigateToScreen(context, PollsScreen(), 'Polls'),
                    ),

                    SizedBox(height: 2),

                    // Main Features
                    _buildSectionHeader(context, 'Features'),
                    _buildDrawerItem(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      title: 'My Orders',
                      onTap: () => _navigateToScreen(context, MyOrdersScreen(), 'My Orders'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () => _navigateToScreen(context, NotificationsScreen(), 'Notifications'),
                    ),

                    SizedBox(height: 2),

                    // Club & Account
                    _buildSectionHeader(context, 'Club & Account'),
                    _buildDrawerItem(
                      context,
                      icon: Icons.groups_outlined,
                      title: 'My Clubs',
                      onTap: () => _navigateToScreen(context, ClubsScreen(), 'My Clubs'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.person_outline,
                      title: 'Profile',
                      onTap: () => _navigateToScreen(context, ProfileScreen(), 'Profile'),
                    ),

                    SizedBox(height: 20),

                    // Settings
                    _buildSectionHeader(context, 'Settings'),
                    _buildThemeSwitcher(context, themeProvider),
                    _buildDrawerItem(
                      context,
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {
                        Navigator.of(context).pop();
                        // TODO: Navigate to help when available
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.info_outline,
                      title: 'About',
                      onTap: () {
                        Navigator.of(context).pop();
                        // TODO: Show about dialog when available
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).textTheme.bodySmall?.color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListTile(
              leading: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).iconTheme.color,
                size: 20,
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSwitcher(BuildContext context, ThemeProvider themeProvider) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            themeProvider.cycleThemeMode();
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListTile(
              leading: Icon(
                themeProvider.themeModeIcon,
                color: Theme.of(context).iconTheme.color,
                size: 20,
              ),
              title: Text(
                'Theme',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w400,
                ),
              ),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  themeProvider.themeModeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            ),
          ),
        ),
      ),
    );
  }
}