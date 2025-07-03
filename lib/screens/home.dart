// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import '../services/auth_service.dart';
import 'clubs.dart';
import 'matches.dart';
import 'transactions.dart';
import 'store.dart';
import 'polls.dart';
import 'profile.dart';
import 'login.dart';
import 'notifications.dart';
import '../utils/theme.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  final ScrollController _scrollController = ScrollController();
  Widget _currentScreen = MatchesScreen();
  String _currentTitle = 'Matches';

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _headerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));

    _scrollController.addListener(() {
      if (_scrollController.offset > 50) {
        _headerAnimationController.forward();
      } else {
        _headerAnimationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToScreen(Widget screen, String title) {
    setState(() {
      _currentScreen = screen;
      _currentTitle = title;
    });
    Navigator.of(context).pop(); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor,
      drawer: _buildSideDrawer(),
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: AppTheme.cricketGreen,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 72, bottom: 16),
                title: AnimatedBuilder(
                  animation: _headerAnimation,
                  builder: (context, child) {
                    return Consumer<ClubProvider>(
                      builder: (context, clubProvider, child) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (clubProvider.currentClub?.club.logo != null)
                              Container(
                                width: 32 * _headerAnimation.value,
                                height: 32 * _headerAnimation.value,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    clubProvider.currentClub!.club.logo!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.white,
                                        child: Icon(
                                          Icons.sports_cricket,
                                          color: AppTheme.cricketGreen,
                                          size: 20 * _headerAnimation.value,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Text(
                                clubProvider.currentClub?.club.name ?? 'Duggy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18 * _headerAnimation.value,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NotificationsScreen()),
                    );
                  },
                ),
                SizedBox(width: 8),
              ],
              leading: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ];
        },
        body: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: _currentScreen,
          ),
        ),
      ),
    );
  }

  Widget _buildSideDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Consumer2<UserProvider, ClubProvider>(
        builder: (context, userProvider, clubProvider, child) {
          final user = userProvider.user;
          final currentClub = clubProvider.currentClub;
          
          return Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.cricketGreen, AppTheme.darkGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: user?.profilePicture != null
                            ? Image.network(
                                user!.profilePicture!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppTheme.cricketGreen.withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: AppTheme.cricketGreen,
                                      size: 40,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: AppTheme.cricketGreen.withOpacity(0.1),
                                child: Icon(
                                  Icons.person,
                                  color: AppTheme.cricketGreen,
                                  size: 40,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      user?.name ?? 'User',
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
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    if (currentClub != null) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          currentClub.role,
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
              
              // Menu Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Main Features
                    _buildSectionHeader('Main'),
                    _buildDrawerItem(
                      icon: Icons.sports_cricket_outlined,
                      title: 'Matches',
                      isSelected: _currentTitle == 'Matches',
                      onTap: () => _navigateToScreen(MatchesScreen(), 'Matches'),
                    ),
                    _buildDrawerItem(
                      icon: Icons.store_outlined,
                      title: 'Store',
                      isSelected: _currentTitle == 'Store',
                      onTap: () => _navigateToScreen(StoreScreen(), 'Store'),
                    ),
                    _buildDrawerItem(
                      icon: Icons.poll_outlined,
                      title: 'Polls',
                      isSelected: _currentTitle == 'Polls',
                      onTap: () => _navigateToScreen(PollsScreen(), 'Polls'),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Club & Account
                    _buildSectionHeader('Club & Account'),
                    _buildDrawerItem(
                      icon: Icons.groups_outlined,
                      title: 'My Clubs',
                      isSelected: _currentTitle == 'My Clubs',
                      onTap: () => _navigateToScreen(ClubsScreen(), 'My Clubs'),
                    ),
                    _buildDrawerItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Transactions',
                      isSelected: _currentTitle == 'Transactions',
                      onTap: () => _navigateToScreen(TransactionsScreen(), 'Transactions'),
                    ),
                    _buildDrawerItem(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      isSelected: _currentTitle == 'Profile',
                      onTap: () => _navigateToScreen(ProfileScreen(), 'Profile'),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Settings
                    _buildSectionHeader('Settings'),
                    _buildDrawerItem(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {
                        Navigator.of(context).pop();
                        // TODO: Navigate to help
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.info_outline,
                      title: 'About',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showAboutDialog();
                      },
                    ),
                  ],
                ),
              ),
              
              // Logout Button
              Container(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showLogoutDialog(),
                    icon: Icon(Icons.logout, color: Colors.red),
                    label: Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.secondaryTextColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected 
          ? AppTheme.cricketGreen.withOpacity(0.1)
          : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected 
              ? AppTheme.cricketGreen.withOpacity(0.2)
              : AppTheme.cricketGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isSelected 
              ? AppTheme.cricketGreen
              : AppTheme.cricketGreen.withOpacity(0.7),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected 
              ? AppTheme.cricketGreen
              : AppTheme.primaryTextColor,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        trailing: isSelected 
          ? Icon(
              Icons.chevron_right,
              color: AppTheme.cricketGreen,
              size: 20,
            )
          : null,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cricketGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.sports_cricket,
                color: AppTheme.cricketGreen,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text('About Duggy'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duggy - Your Cricket Club Companion',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Text('Version 1.0.0'),
            SizedBox(height: 12),
            Text(
              'Manage your cricket club activities, matches, store orders, and more with Duggy.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cricketGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    color: AppTheme.cricketGreen,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Visit duggy.app for more information',
                    style: TextStyle(
                      color: AppTheme.cricketGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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