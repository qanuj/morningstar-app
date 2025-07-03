// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import 'clubs.dart';
import 'matches.dart';
import 'transactions.dart';
import 'store.dart';
import 'polls.dart';
import 'profile.dart';
import 'notifications.dart';
import '../utils/theme.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    ClubsScreen(),
    MatchesScreen(),
    TransactionsScreen(),
    StoreScreen(),
    PollsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<ClubProvider>(
          builder: (context, clubProvider, child) {
            if (clubProvider.currentClub != null) {
              return Row(
                children: [
                  if (clubProvider.currentClub!.club.logo != null)
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(clubProvider.currentClub!.club.logo!),
                    ),
                  SizedBox(width: 8),
                  Text(clubProvider.currentClub!.club.name),
                ],
              );
            }
            return Text('Duggy');
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NotificationsScreen()),
              );
            },
          ),
        ],
        backgroundColor: AppTheme.cricketGreen,
        foregroundColor: Colors.white,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.cricketGreen,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'My Clubs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_cricket),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Store',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.poll),
            label: 'Polls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}