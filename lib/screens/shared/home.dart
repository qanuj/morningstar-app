// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/svg_avatar.dart';
import '../clubs/clubs.dart';
import '../matches/matches.dart';
import '../wallet/transactions.dart';
import '../settings/profile.dart';
import '../social/social_feed_screen.dart';
import '../debug/share_test_screen.dart';
import '../qr_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize conversation data when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().fetchConversations();
    });
  }

  List<Widget> get _screens => [
    SocialFeedScreen(), // Home (social feed)
    ClubsScreen(), // Clubs
    MatchesScreen(), // Matches
    TransactionsScreen(), // Wallet (transactions)
    ProfileScreen(), // Settings (profile)
  ];

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    HapticFeedback.lightImpact();
  }

  Widget _buildProfileIcon(UserProvider userProvider, bool isActive) {
    final user = userProvider.user;

    return SVGAvatar(
      imageUrl: user?.profilePicture,
      size: 32,
      backgroundColor: isActive
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : Theme.of(context).colorScheme.surfaceVariant,
      iconColor: isActive
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
      fallbackIcon: LucideIcons.user,
      iconSize: 18,
    );
  }

  Widget _buildAdminSpeedDial() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ShareTestScreen(),
              ),
            );
          },
          backgroundColor: Colors.grey[700],
          tooltip: 'Admin Tools',
          heroTag: "admin_tools",
          child: const Icon(LucideIcons.settings, color: Colors.white, size: 20),
        ),
        SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const QRScannerScreen(),
              ),
            );
          },
          backgroundColor: const Color(0xFF003f9b),
          tooltip: 'Scan QR Code',
          heroTag: "qr_scanner",
          child: const Icon(LucideIcons.qrCode, color: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return BottomNavigationBar(
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
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
            elevation: 10,
            items: [
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.home, size: 24),
                activeIcon: Icon(LucideIcons.home, size: 24),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.users, size: 24),
                activeIcon: Icon(LucideIcons.users, size: 24),
                label: 'Clubs',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.trophy, size: 24),
                activeIcon: Icon(LucideIcons.trophy, size: 24),
                label: 'Matches',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.wallet, size: 24),
                activeIcon: Icon(LucideIcons.wallet, size: 24),
                label: 'Kitty',
              ),
              BottomNavigationBarItem(
                icon: _buildProfileIcon(userProvider, false),
                activeIcon: _buildProfileIcon(userProvider, true),
                label: 'You',
              ),
            ],
          );
        },
      ),
      // QR Scanner and Admin tools floating action button
      floatingActionButton: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final isAdmin = userProvider.user?.role.toUpperCase() == 'ADMIN';
          
          // For admin users, show speed dial with both options
          if (isAdmin) {
            return _buildAdminSpeedDial();
          }
          
          // For regular users, show QR scanner button
          return FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const QRScannerScreen(),
                ),
              );
            },
            backgroundColor: const Color(0xFF003f9b),
            tooltip: 'Scan QR Code',
            child: const Icon(LucideIcons.qrCode, color: Colors.white),
          );
        },
      ),
    );
  }
}
