import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  int get currentIndex => _currentIndex;
  PageController get pageController => _pageController;

  void setCurrentIndex(int index) {
    _currentIndex = index;
    _pageController.jumpToPage(index);
    notifyListeners();
  }

  void animateToPage(int index) {
    _currentIndex = index;
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    notifyListeners();
  }

  void onPageChanged(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  String getCurrentPageTitle() {
    switch (_currentIndex) {
      case 0:
        return 'My Clubs';
      case 1:
        return 'Matches';
      case 2:
        return 'Transactions';
      case 3:
        return 'Store';
      case 4:
        return 'Polls';
      case 5:
        return 'Profile';
      default:
        return 'Duggy';
    }
  }

  IconData getCurrentPageIcon() {
    switch (_currentIndex) {
      case 0:
        return Icons.groups;
      case 1:
        return Icons.sports_cricket;
      case 2:
        return Icons.account_balance_wallet;
      case 3:
        return Icons.store;
      case 4:
        return Icons.poll;
      case 5:
        return Icons.person;
      default:
        return Icons.home;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}