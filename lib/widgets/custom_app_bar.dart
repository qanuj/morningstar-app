import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../screens/news/notifications.dart';
import '../screens/clubs/clubs.dart';

/// Custom AppBar widget that provides consistent styling and functionality across the app.
/// 
/// This widget provides three main variants:
/// 
/// 1. **CustomAppBar** - Base widget with full customization options
/// 2. **HomeAppBar** - For the main home screen with club switch and notifications
/// 3. **PageAppBar** - For internal pages showing "Duggy [PageName]" format
/// 4. **DetailAppBar** - For detail screens with back navigation and minimal actions
/// 
/// ## Usage Examples:
/// 
/// ### Home Screen:
/// ```dart
/// appBar: HomeAppBar(
///   onDrawerTap: () => _scaffoldKey.currentState?.openDrawer(),
/// ),
/// ```
/// 
/// ### Regular Pages (Matches, Polls, Store, etc.):
/// ```dart
/// appBar: PageAppBar(
///   pageName: 'Polls',
///   onDrawerTap: () => _scaffoldKey.currentState?.openDrawer(),
/// ),
/// ```
/// 
/// ### Detail Screens (Profile, Match Details, etc.):
/// ```dart
/// appBar: DetailAppBar(
///   pageTitle: 'Profile',
///   customActions: [
///     IconButton(
///       icon: Icon(Icons.home_outlined),
///       onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
///     ),
///   ],
/// ),
/// ```
/// 
/// ### Custom Configuration:
/// ```dart
/// appBar: CustomAppBar(
///   title: 'Custom Title',
///   subtitle: 'Subtitle',
///   showNotifications: false,
///   showBackButton: true,
///   customActions: [
///     IconButton(icon: Icon(Icons.settings), onPressed: () {}),
///   ],
/// ),
/// ```

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showNotifications;
  final bool showClubSwitch;
  final bool showBackButton;
  final VoidCallback? onDrawerTap;
  final VoidCallback? onBackTap;
  final List<Widget>? customActions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showNotifications = true,
    this.showClubSwitch = false,
    this.showBackButton = false,
    this.onDrawerTap,
    this.onBackTap,
    this.customActions,
  });

  @override
  Widget build(BuildContext context) {
    // Check if we can actually go back
    final canGoBack = Navigator.of(context).canPop();
    final shouldShowBackButton = showBackButton && canGoBack;
    final shouldShowDrawer = onDrawerTap != null && !shouldShowBackButton;
    
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      centerTitle: defaultTargetPlatform == TargetPlatform.iOS,
      automaticallyImplyLeading: false,
      leading: shouldShowBackButton
          ? GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (onBackTap != null) {
                  onBackTap!();
                } else {
                  // Simple back navigation - just pop
                  Navigator.of(context).pop();
                }
              },
              child: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).appBarTheme.foregroundColor,
                size: 24,
              ),
            )
          : shouldShowDrawer
              ? GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (onDrawerTap != null) {
                      onDrawerTap!();
                    } else {
                      Scaffold.of(context).openDrawer();
                    }
                  },
                  child: Icon(
                    Icons.menu,
                    color: Theme.of(context).appBarTheme.foregroundColor,
                    size: 24,
                  ),
                )
              : null,
      title: _buildTitle(context),
      actions: _buildAllActions(context),
    );
  }

  Widget _buildTitle(BuildContext context) {
    if (subtitle != null) {
      // Show subtitle as the main title
      return Text(
        subtitle!,
        style: TextStyle(
          color: Theme.of(context).appBarTheme.foregroundColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      );
    } else {
      // Show only the title
      return Text(
        title,
        style: TextStyle(
          color: Theme.of(context).appBarTheme.foregroundColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      );
    }
  }

  List<Widget> _buildAllActions(BuildContext context) {
    List<Widget> allActions = [];
    
    // Add custom actions first if they exist
    if (customActions != null) {
      allActions.addAll(customActions!);
    }
    
    // Add default actions
    allActions.addAll(_buildDefaultActions(context));
    
    return allActions;
  }

  List<Widget> _buildDefaultActions(BuildContext context) {
    List<Widget> actions = [];

    // Notifications action
    if (showNotifications) {
      actions.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    NotificationsScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic)),
                    ),
                    child: child,
                  );
                },
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).appBarTheme.foregroundColor,
              size: 24,
            ),
          ),
        ),
      );
    }

    // Club switch action (typically for home screen)
    if (showClubSwitch) {
      actions.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => ClubsScreen()),
            );
          },
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(
              Icons.swap_horiz,
              color: Theme.of(context).appBarTheme.foregroundColor,
              size: 24,
            ),
          ),
        ),
      );
    }

    return actions;
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

// Convenience constructors for common app bar types

class HomeAppBar extends CustomAppBar {
  const HomeAppBar({
    super.key,
    super.onDrawerTap,
  }) : super(
          title: 'Home',
          showNotifications: true,
          showClubSwitch: true,
        );
}

class PageAppBar extends CustomAppBar {
  const PageAppBar({
    super.key,
    required String pageName,
    super.onDrawerTap,
    super.showNotifications = true,
    super.customActions,
  }) : super(
          title: '',
          subtitle: pageName,
        );
}

class DetailAppBar extends CustomAppBar {
  const DetailAppBar({
    super.key,
    required String pageTitle,
    super.onBackTap,
    super.showNotifications = false,
    super.customActions,
    bool showBackButton = true,
  }) : super(
          title: pageTitle,
          showBackButton: showBackButton,
        );
}

class CricketStyleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final List<Widget>? customActions;
  final VoidCallback? onSearchPressed;

  const CricketStyleAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.customActions,
    this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColorDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: leadingIcon != null 
          ? IconButton(
              icon: Icon(leadingIcon, color: Colors.white, size: 24),
              onPressed: null, // Decorative only
            )
          : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: _buildActions(context),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    List<Widget> actions = [];

    // Add custom actions first
    if (customActions != null) {
      for (Widget action in customActions!) {
        // Style IconButtons as plain white icons without backgrounds
        if (action is IconButton) {
          actions.add(
            IconButton(
              onPressed: action.onPressed,
              icon: Icon(
                (action.icon as Icon).icon,
                color: Colors.white,
                size: 24,
              ),
              tooltip: action.tooltip,
              padding: EdgeInsets.all(8),
            ),
          );
        } else {
          actions.add(action);
        }
      }
    }

    // Add search button if callback provided
    if (onSearchPressed != null) {
      actions.add(
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: onSearchPressed,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                child: Icon(Icons.search, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      );
    }

    return actions;
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}