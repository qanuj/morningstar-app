// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/conversation_provider.dart';
import '../models/club.dart';
import '../models/conversation.dart';
import 'clubs.dart';
import 'matches.dart';
import 'chat_detail.dart';
import 'transactions.dart';
import 'store.dart';
import 'polls.dart';
import 'profile.dart';
import 'notifications.dart';
import 'my_orders.dart';
import 'conversations.dart';
import '../utils/theme.dart';
import '../utils/dialogs.dart';
import '../widgets/duggy_logo.dart';
import '../widgets/custom_app_bar.dart';

class HomeScreen extends StatefulWidget {
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

  final List<String> _titles = ['News', 'Clubs', 'Matches', 'Wallet', 'Settings'];

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    HapticFeedback.lightImpact();
  }

  Widget _buildConversationIcon(int unreadCount, bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isActive ? Icons.chat : Icons.chat_outlined,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
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
      bottomNavigationBar: Consumer<ConversationProvider>(
        builder: (context, conversationProvider, child) {
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
                icon: _buildConversationIcon(conversationProvider.totalUnreadCount, false),
                activeIcon: _buildConversationIcon(conversationProvider.totalUnreadCount, true),
                label: 'News',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group_outlined),
                activeIcon: Icon(Icons.group),
                label: 'Clubs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.sports_cricket_outlined),
                activeIcon: Icon(Icons.sports_cricket),
                label: 'Matches',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet),
                label: 'Wallet',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          );
        },
      ),
    );
  }
}