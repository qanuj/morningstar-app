import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/news/notifications.dart';
import '../screens/clubs/clubs.dart';
import 'duggy_logo.dart';

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
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => ClubsScreen()));
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

class DetailAppBar extends CustomAppBar {
  const DetailAppBar({
    super.key,
    required String pageTitle,
    super.onBackTap,
    super.showNotifications = false,
    super.customActions,
    bool showBackButton = true,
  }) : super(title: pageTitle, showBackButton: showBackButton);
}

class ClubAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String clubName;
  final String? clubLogo;
  final String subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;

  const ClubAppBar({
    super.key,
    required this.clubName,
    this.clubLogo,
    required this.subtitle,
    this.actions,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF003f9b),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          // Club Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: clubLogo != null && clubLogo!.isNotEmpty
                  ? _buildClubLogo()
                  : _buildDefaultClubLogo(),
            ),
          ),
          const SizedBox(width: 12),
          // Club Name and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildClubLogo() {
    // Check if the URL is an SVG
    if (clubLogo!.toLowerCase().contains('.svg') ||
        clubLogo!.toLowerCase().contains('svg?')) {
      return SvgPicture.network(
        clubLogo!,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildDefaultClubLogo(),
      );
    } else {
      // Regular image (PNG, JPG, etc.)
      return Image.network(
        clubLogo!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultClubLogo();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildDefaultClubLogo();
        },
      );
    }
  }

  Widget _buildDefaultClubLogo() {
    return Builder(
      builder: (context) => Container(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Center(
          child: Text(
            clubName.isNotEmpty ? clubName.substring(0, 1).toUpperCase() : 'C',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    if (actions == null || actions!.isEmpty) return [];

    return actions!.map((action) {
      // Style IconButtons with white color
      if (action is IconButton) {
        return IconButton(
          onPressed: action.onPressed,
          icon: Icon((action.icon as Icon).icon, color: Colors.white, size: 24),
          tooltip: action.tooltip,
        );
      }
      return action;
    }).toList();
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class DuggyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String subtitle;
  final List<Widget>? actions;

  const DuggyAppBar({super.key, required this.subtitle, this.actions});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false, // Don't add top safe area padding
      child: Container(
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
          toolbarHeight: 48.0, // Match the preferredSize height
          titleSpacing: 0, // Remove extra spacing around title
          automaticallyImplyLeading: false,
          leading: Container(
            width: 36,
            height: 36,
            padding: EdgeInsets.all(6), // Reduced padding
            child: DuggyLogo(
              size: 24,
              color: Colors.white,
            ), // Reduced logo size
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min, // Use minimum space
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duggy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18, // Reduced from 24 to fit in 48px height
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  height: 1.0, // Reduce line height
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11, // Reduced from 12
                  fontWeight: FontWeight.w400,
                  height: 1.0, // Reduce line height
                ),
              ),
            ],
          ),
          actions: _buildActions(),
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    if (actions == null || actions!.isEmpty) return [];

    return actions!.map((action) {
      // Style IconButtons with white color
      if (action is IconButton) {
        return IconButton(
          onPressed: action.onPressed,
          icon: Icon((action.icon as Icon).icon, color: Colors.white, size: 24),
          tooltip: action.tooltip,
          padding: EdgeInsets.all(8),
        );
      }
      return action;
    }).toList();
  }

  @override
  Size get preferredSize {
    // Return just the toolbar height without any status bar padding
    return const Size.fromHeight(48.0);
  }
}
