import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import '../screens/profile.dart';
import '../screens/matches.dart';
import '../screens/store.dart';
import '../screens/my_orders.dart';
import '../screens/transactions.dart';
import '../screens/polls.dart';
import '../screens/notifications.dart';

class AppDrawer extends StatelessWidget {
  final Function(Widget, String)? onNavigate;

  const AppDrawer({
    super.key,
    this.onNavigate,
  });

  void _navigateToScreen(BuildContext context, Widget screen, String screenName) {
    Navigator.of(context).pop(); // Close drawer first
    if (onNavigate != null) {
      onNavigate!(screen, screenName);
    } else {
      // Default navigation if no callback provided
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
      child: Consumer2<UserProvider, ClubProvider>(
        builder: (context, userProvider, clubProvider, child) {
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
                                    fontSize: 12,
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
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(
                      context,
                      icon: Icons.sports_cricket,
                      title: 'Matches',
                      onTap: () => _navigateToScreen(context, MatchesScreen(), 'Matches'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.store,
                      title: 'Store',
                      onTap: () => _navigateToScreen(context, StoreScreen(), 'Store'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      title: 'My Orders',
                      onTap: () => _navigateToScreen(context, MyOrdersScreen(), 'Orders'),
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
                    _buildDrawerItem(
                      context,
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () => _navigateToScreen(context, NotificationsScreen(), 'Notifications'),
                    ),
                    Divider(
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      height: 32,
                      indent: 16,
                      endIndent: 16,
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () {
                        // Navigate to settings when available
                        Navigator.of(context).pop();
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {
                        // Navigate to help when available
                        Navigator.of(context).pop();
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

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).iconTheme.color,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      dense: true,
    );
  }
}