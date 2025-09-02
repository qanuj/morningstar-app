import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/club.dart';
import '../services/message_storage_service.dart';

/// Custom AppBar widget for the club chat screen
/// Handles both normal and selection modes with context-aware actions
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Club club;
  final bool isSelectionMode;
  final Set<String> selectedMessageIds;
  final AnimationController refreshAnimationController;
  final VoidCallback onBackPressed;
  final VoidCallback onShowClubInfo;
  final VoidCallback onExitSelectionMode;
  final VoidCallback onDeleteSelectedMessages;
  final VoidCallback onRefreshMessages;
  final VoidCallback onShowMoreOptions;

  const ChatAppBar({
    super.key,
    required this.club,
    required this.isSelectionMode,
    required this.selectedMessageIds,
    required this.refreshAnimationController,
    required this.onBackPressed,
    required this.onShowClubInfo,
    required this.onExitSelectionMode,
    required this.onDeleteSelectedMessages,
    required this.onRefreshMessages,
    required this.onShowMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF003f9b),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBackPressed,
      ),
      title: isSelectionMode ? _buildSelectionTitle() : _buildNormalTitle(),
      actions: isSelectionMode
          ? _buildSelectionActions()
          : _buildNormalActions(),
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
            onTap: onShowClubInfo,
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
                  'tap here for club info',
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
      IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onPressed: onShowMoreOptions,
        tooltip: 'More options',
      ),
    ];
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
