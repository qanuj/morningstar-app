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
    return SafeArea(
      top: false, // Don't add top safe area padding
      child: AppBar(
        backgroundColor: const Color(0xFF003f9b),
        elevation: 0,
        toolbarHeight: 48.0, // Match the preferredSize height
        titleSpacing: 0, // Remove extra spacing around title
        automaticallyImplyLeading:
            false, // Remove automatic leading widget spacing
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
    return Text(
      '${selectedMessageIds.length} message${selectedMessageIds.length == 1 ? '' : 's'} selected',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildNormalTitle() {
    return Row(
      children: [
        // Club Logo
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: club.logo != null && club.logo!.isNotEmpty
                ? _buildClubLogo()
                : _buildDefaultClubLogo(),
          ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getSubtitleText(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
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
      builder: (context) => Container(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Center(
          child: Text(
            club.name.isNotEmpty
                ? club.name.substring(0, 1).toUpperCase()
                : 'C',
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

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: onExitSelectionMode,
        tooltip: 'Cancel selection',
      ),
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.white),
        onPressed: selectedMessageIds.isNotEmpty
            ? onDeleteSelectedMessages
            : null,
        tooltip: 'Delete selected messages',
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
              IconButton(
                icon: AnimatedBuilder(
                  animation: refreshAnimationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: refreshAnimationController.value * 2.0 * 3.14159,
                      child: const Icon(Icons.refresh, color: Colors.white),
                    );
                  },
                ),
                onPressed: onRefreshMessages,
                tooltip: isOfflineMode
                    ? 'Refresh from server (Offline mode is ON)'
                    : 'Refresh messages',
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
        builder: (context) => PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: onMoreOptionSelected,
          tooltip: 'More options',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF2A2A2A)
              : Colors.white,
          elevation: 8,
          itemBuilder: (BuildContext menuContext) {
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
                      Icon(Icons.person_add, color: Color(0xFF003f9b)),
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
                    Icon(Icons.settings, color: Color(0xFF003f9b)),
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
                    Icon(Icons.sports_cricket, color: Color(0xFF003f9b)),
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
                    Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFF003f9b),
                    ),
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
                    Icon(Icons.groups, color: Color(0xFF003f9b)),
                    SizedBox(width: 12),
                    Text('Teams'),
                  ],
                ),
              ),
            );

            // Divider before clear messages
            items.add(PopupMenuDivider());

            // Clear Messages
            items.add(
              PopupMenuItem<String>(
                value: 'clear_messages',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Clear Messages', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );

            return items;
          },
        ),
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
