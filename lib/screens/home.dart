// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import '../providers/theme_provider.dart';
import 'clubs.dart';
import 'matches.dart';
import 'transactions.dart';
import 'store.dart';
import 'polls.dart';
import 'profile.dart';
import 'notifications.dart';
import 'my_orders.dart';
import '../utils/theme.dart';
import '../utils/dialogs.dart';
import '../widgets/duggy_logo.dart';
import '../widgets/app_drawer.dart';
import '../widgets/custom_app_bar.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    _DashboardScreen(), // Home dashboard
    MatchesScreen(),
    StoreScreen(),
    TransactionsScreen(),
    PollsScreen(),
  ];

  final List<String> _titles = ['Home', 'Matches', 'Store', 'Transactions', 'Polls'];

  void _navigateToScreen(Widget screen, String title) {
    // For drawer navigation to screens not in bottom tabs
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
    HapticFeedback.lightImpact();
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: AppDrawer(
        onNavigate: _navigateToScreen,
        onTabSwitch: _onBottomNavTap,
      ),
      appBar: HomeAppBar(
        onDrawerTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(
          context,
        ).bottomNavigationBarTheme.backgroundColor,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).bottomNavigationBarTheme.unselectedItemColor,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        elevation: 10,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_cricket_outlined),
            activeIcon: Icon(Icons.sports_cricket),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'Store',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.poll_outlined),
            activeIcon: Icon(Icons.poll),
            label: 'Polls',
          ),
        ],
      ),
    );
  }

  Widget _buildSideDrawer() {
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
                  _navigateToScreen(ProfileScreen(), 'Profile');
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
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withOpacity(0.1),
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
                                      color: AppTheme.cricketGreen.withOpacity(
                                        0.1,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 28,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: AppTheme.cricketGreen.withOpacity(0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 28,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 16),
                      // User Info on Right
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              user?.phoneNumber ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                            if (currentClub != null) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  currentClub.role,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Chevron to indicate tap functionality
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white.withOpacity(0.6),
                        size: 24,
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
                    // Main Features
                    _buildSectionHeader('Features'),
                    _buildDrawerItem(
                      icon: Icons.store_outlined,
                      title: 'Store',
                      onTap: () => _navigateToScreen(StoreScreen(), 'Store'),
                    ),
                    _buildDrawerItem(
                      icon: Icons.shopping_bag_outlined,
                      title: 'My Orders',
                      onTap: () =>
                          _navigateToScreen(MyOrdersScreen(), 'My Orders'),
                    ),
                    _buildDrawerItem(
                      icon: Icons.poll_outlined,
                      title: 'Polls',
                      onTap: () => _navigateToScreen(PollsScreen(), 'Polls'),
                    ),

                    SizedBox(height: 2),

                    // Club & Account
                    _buildSectionHeader('Club & Account'),
                    _buildDrawerItem(
                      icon: Icons.groups_outlined,
                      title: 'My Clubs',
                      onTap: () => _navigateToScreen(ClubsScreen(), 'My Clubs'),
                    ),
                    _buildDrawerItem(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      onTap: () =>
                          _navigateToScreen(ProfileScreen(), 'Profile'),
                    ),

                    SizedBox(height: 20),

                    // Settings
                    _buildSectionHeader('Settings'),
                    _buildThemeSwitcher(),
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
                        AppDialogs.showAboutDialog(context);
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

  Widget _buildThemeSwitcher() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _showThemeBottomSheet();
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      themeProvider.themeModeIcon,
                      color: AppTheme.cricketGreen.withOpacity(0.7),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Theme',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                    ),
                    Text(
                      themeProvider.themeModeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showThemeBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        Icons.palette_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Choose Theme',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Theme options
                _buildThemeOption(
                  context,
                  themeProvider,
                  AppThemeMode.light,
                  Icons.light_mode,
                  'Light',
                  'Always use light theme',
                ),
                _buildThemeOption(
                  context,
                  themeProvider,
                  AppThemeMode.dark,
                  Icons.dark_mode,
                  'Dark',
                  'Always use dark theme',
                ),
                _buildThemeOption(
                  context,
                  themeProvider,
                  AppThemeMode.system,
                  Icons.settings_brightness,
                  'System',
                  'Follow system setting',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    AppThemeMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = themeProvider.themeMode == mode;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            themeProvider.setThemeMode(mode);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.cricketGreen.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.cricketGreen.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppTheme.cricketGreen
                      : AppTheme.secondaryTextColor,
                  size: 24,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isSelected
                              ? AppTheme.cricketGreen
                              : AppTheme.primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).textTheme.bodySmall?.color,
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
              borderRadius: BorderRadius.circular(1),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      width: 0.5,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).iconTheme.color ??
                            Theme.of(context).primaryColor.withOpacity(0.7),
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).primaryColor,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Simple Dashboard Screen placeholder
class _DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer2<UserProvider, ClubProvider>(
        builder: (context, userProvider, clubProvider, child) {
          final user = userProvider.user;
          final currentClub = clubProvider.currentClub;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColorDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        user?.name ?? 'User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (currentClub != null) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.groups,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              currentClub.club.name,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                SizedBox(height: 16),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildQuickActionCard(
                      context,
                      icon: Icons.store,
                      title: 'Store',
                      subtitle: 'Browse products',
                      color: AppTheme.lightBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StoreScreen(),
                          ),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.shopping_bag,
                      title: 'My Orders',
                      subtitle: 'Track orders',
                      color: AppTheme.warningOrange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MyOrdersScreen(),
                          ),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.poll,
                      title: 'Polls',
                      subtitle: 'Vote & participate',
                      color: AppTheme.successGreen,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PollsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.person,
                      title: 'Profile',
                      subtitle: 'Manage account',
                      color: AppTheme.primaryBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
