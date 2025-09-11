// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/svg_avatar.dart';
import '../clubs/clubs.dart';
import '../matches/matches.dart';
import '../wallet/transactions.dart';
import '../settings/profile.dart';
import '../news/conversations.dart';
import '../debug/share_test_screen.dart';

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
    ConversationsScreen(), // News (using conversations for announcements)
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
      fallbackIcon: isActive ? Icons.person : Icons.person_outline,
      iconSize: 18,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
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
                icon: Icon(Icons.home_outlined, size: 32),
                activeIcon: Icon(Icons.home, size: 32),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group_outlined, size: 32),
                activeIcon: Icon(Icons.group, size: 32),
                label: 'Clubs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.sports_cricket_outlined, size: 32),
                activeIcon: Icon(Icons.sports_cricket, size: 32),
                label: 'Matches',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 32),
                activeIcon: Icon(Icons.account_balance_wallet, size: 32),
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
      // Admin tools floating action button
      floatingActionButton: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          // Only show for Admin users
          if (userProvider.user?.role.toUpperCase() != 'ADMIN') {
            return SizedBox.shrink();
          }
          
          return FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ShareTestScreen(),
                ),
              );
            },
            backgroundColor: const Color(0xFF003f9b),
            tooltip: 'Admin Tools',
            child: const Icon(Icons.build, color: Colors.white),
          );
        },
      ),
    );
  }
}