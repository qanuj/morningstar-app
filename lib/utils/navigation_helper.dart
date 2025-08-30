import 'package:flutter/material.dart';

/// Navigation helper to handle consistent navigation across the app
class NavigationHelper {
  // Bottom tab page indices - these should navigate via home screen tabs
  static const Map<String, int> bottomTabPages = {
    'Home': 0,
    'Matches': 1,
    'Store': 2,
    'Transactions': 3,
    'Polls': 4,
  };

  /// Navigate to a page, checking if it's a bottom tab page or standalone page
  static void navigateToPage(
    BuildContext context, {
    required String pageName,
    Widget? standaloneWidget,
    Function(int)? onTabSwitch,
  }) {
    // Close drawer first
    Navigator.of(context).pop();

    // Check if it's a bottom tab page
    if (bottomTabPages.containsKey(pageName)) {
      final tabIndex = bottomTabPages[pageName]!;
      
      // If we have a tab switch callback (from home screen), use it
      if (onTabSwitch != null) {
        onTabSwitch(tabIndex);
      } else {
        // Navigate to home screen with specific tab
        _navigateToHomeWithTab(context, tabIndex);
      }
    } else {
      // For standalone pages, do regular navigation
      if (standaloneWidget != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => standaloneWidget),
        );
      }
    }
  }

  /// Navigate to home screen and switch to specific tab
  static void _navigateToHomeWithTab(BuildContext context, int tabIndex) {
    // Check if we're already on home screen
    final route = ModalRoute.of(context);
    if (route?.settings.name == '/home' || route?.isFirst == true) {
      // We're already on home, just need tab switch (but we can't access it directly)
      // This case will be handled by the onTabSwitch callback
      return;
    }

    // Navigate to home screen with tab parameter
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: {'initialTab': tabIndex},
    );
  }

  /// Get the tab index for a page name
  static int? getTabIndex(String pageName) {
    return bottomTabPages[pageName];
  }

  /// Check if a page is a bottom tab page
  static bool isBottomTabPage(String pageName) {
    return bottomTabPages.containsKey(pageName);
  }
}