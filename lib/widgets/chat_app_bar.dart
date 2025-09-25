import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/club.dart';
import '../services/message_storage_service.dart';

/// Custom AppBar widget for the club chat screen
/// Handles both normal and selection modes with context-aware actions
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Club club;
  final String? userRole;
  final bool isSelectionMode;
  final Set<String> selectedMessageIds;
  final AnimationController refreshAnimationController;
  final VoidCallback onBackPressed;
  final VoidCallback onShowClubInfo;
  final VoidCallback? onManageClub;
  final VoidCallback onExitSelectionMode;
  final VoidCallback onDeleteSelectedMessages;
  final VoidCallback onRefreshMessages;
  final Function(String) onMoreOptionSelected;

  const ChatAppBar({
    super.key,
    required this.club,
    this.userRole,
    required this.isSelectionMode,
    required this.selectedMessageIds,
    required this.refreshAnimationController,
    required this.onBackPressed,
    required this.onShowClubInfo,
    this.onManageClub,
    required this.onExitSelectionMode,
    required this.onDeleteSelectedMessages,
    required this.onRefreshMessages,
    required this.onMoreOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false, // Don't add top safe area padding
      child: AppBar(
        backgroundColor: isDarkMode
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primary,
        elevation: 0,
        toolbarHeight: 48.0, // Match the preferredSize height
        titleSpacing: 0, // Remove extra spacing around title
        automaticallyImplyLeading:
            false, // Remove automatic leading widget spacing
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode
                ? Theme.of(context).colorScheme.onSurface
                : Colors.white,
          ),
          onPressed: onBackPressed,
        ),
        title: isSelectionMode ? _buildSelectionTitle() : _buildNormalTitle(),
        actions: isSelectionMode
            ? _buildSelectionActions()
            : _buildNormalActions(),
      ),
    );
  }

  Widget _buildSelectionTitle() {
    return Builder(
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Text(
          '${selectedMessageIds.length} message${selectedMessageIds.length == 1 ? '' : 's'} selected',
          style: TextStyle(
            color: isDarkMode
                ? Theme.of(context).colorScheme.onSurface
                : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }

  Widget _buildNormalTitle() {
    return Row(
      children: [
        // Club Logo
        Builder(
          builder: (context) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                      : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: club.logo != null && club.logo!.isNotEmpty
                    ? _buildClubLogo()
                    : _buildDefaultClubLogo(),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        // Club Name and Status
        Expanded(
          child: GestureDetector(
            onTap: () {
              // Check if user is admin or owner
              if (userRole?.toLowerCase() == 'admin' ||
                  userRole?.toLowerCase() == 'owner') {
                // Show manage club if callback is provided
                onManageClub?.call();
              } else {
                // Show club info for regular members
                onShowClubInfo();
              }
            },
            child: Builder(
              builder: (context) {
                final isDarkMode =
                    Theme.of(context).brightness == Brightness.dark;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: TextStyle(
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getSubtitleText(),
                      style: TextStyle(
                        color: isDarkMode
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.8)
                            : Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClubLogo() {
    // Check if the URL is an SVG
    if (club.logo!.toLowerCase().contains('.svg') ||
        club.logo!.toLowerCase().contains('svg?')) {
      return SvgPicture.network(
        club.logo!,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildDefaultClubLogo(),
      );
    } else {
      // Regular image (PNG, JPG, etc.)
      return Image.network(
        club.logo!,
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
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Center(
            child: Text(
              club.name.isNotEmpty
                  ? club.name.substring(0, 1).toUpperCase()
                  : 'C',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSelectionActions() {
    return [
      Builder(
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return IconButton(
            icon: Icon(
              Icons.close,
              color: isDarkMode
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.white,
            ),
            onPressed: onExitSelectionMode,
            tooltip: 'Cancel selection',
          );
        },
      ),
      Builder(
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return IconButton(
            icon: Icon(
              Icons.delete,
              color: isDarkMode
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.white,
            ),
            onPressed: selectedMessageIds.isNotEmpty
                ? onDeleteSelectedMessages
                : null,
            tooltip: 'Delete selected messages',
          );
        },
      ),
    ];
  }

  List<Widget> _buildNormalActions() {
    return [
      // Offline mode indicator and refresh button
      FutureBuilder<bool>(
        future: MessageStorageService.isOfflineMode(club.id),
        builder: (context, snapshot) {
          final isOfflineMode = snapshot.data ?? false;
          return Stack(
            children: [
              Builder(
                builder: (context) {
                  final isDarkMode =
                      Theme.of(context).brightness == Brightness.dark;
                  return IconButton(
                    icon: AnimatedBuilder(
                      animation: refreshAnimationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle:
                              refreshAnimationController.value * 2.0 * 3.14159,
                          child: Icon(
                            Icons.refresh,
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.white,
                          ),
                        );
                      },
                    ),
                    onPressed: onRefreshMessages,
                    tooltip: isOfflineMode
                        ? 'Refresh from server (Offline mode is ON)'
                        : 'Refresh messages',
                  );
                },
              ),
              if (isOfflineMode)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      Builder(
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.white,
            ),
            onSelected: onMoreOptionSelected,
            tooltip: 'More options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: isDarkMode
                ? Theme.of(context).colorScheme.surface
                : Colors.white,
            elevation: 8,
            itemBuilder: (BuildContext menuContext) {
              final iconColor = Theme.of(menuContext).colorScheme.primary;

              // Build menu items based on role
              final List<PopupMenuEntry<String>> items = [];

              // Add Members - Only for admin/owner
              if (userRole?.toLowerCase() == 'admin' ||
                  userRole?.toLowerCase() == 'owner') {
                items.add(
                  PopupMenuItem<String>(
                    value: 'add_members',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, color: iconColor),
                        SizedBox(width: 12),
                        Text('Add Members'),
                      ],
                    ),
                  ),
                );
              }

              // Manage Club
              items.add(
                PopupMenuItem<String>(
                  value: 'manage_club',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: iconColor),
                      SizedBox(width: 12),
                      Text('Manage Club'),
                    ],
                  ),
                ),
              );

              // Matches
              items.add(
                PopupMenuItem<String>(
                  value: 'matches',
                  child: Row(
                    children: [
                      Icon(Icons.sports_cricket, color: iconColor),
                      SizedBox(width: 12),
                      Text('Matches'),
                    ],
                  ),
                ),
              );

              // Transactions
              items.add(
                PopupMenuItem<String>(
                  value: 'transactions',
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: iconColor),
                      SizedBox(width: 12),
                      Text('Transactions'),
                    ],
                  ),
                ),
              );

              // Teams
              items.add(
                PopupMenuItem<String>(
                  value: 'teams',
                  child: Row(
                    children: [
                      Icon(Icons.groups, color: iconColor),
                      SizedBox(width: 12),
                      Text('Teams'),
                    ],
                  ),
                ),
              );

              // Divider before clear messages - custom for better dark mode visibility
              items.add(
                PopupMenuItem<String>(
                  enabled: false,
                  height: 16,
                  padding: EdgeInsets.zero,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(
                        menuContext,
                      ).colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                ),
              );

              // Clear Messages
              items.add(
                PopupMenuItem<String>(
                  value: 'clear_messages',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.red),
                      SizedBox(width: 12),
                      Text(
                        'Clear Messages',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );

              return items;
            },
          );
        },
      ),
    ];
  }

  String _getSubtitleText() {
    if (userRole?.toLowerCase() == 'admin' ||
        userRole?.toLowerCase() == 'owner') {
      return 'tap here to manage club';
    } else {
      return 'tap here for club info';
    }
  }

  @override
  Size get preferredSize {
    // Return just the toolbar height without any status bar padding
    return const Size.fromHeight(48.0);
  }
}
