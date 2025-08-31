import 'package:flutter/material.dart';
import '../../../models/club.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Club club;
  final int? onlineCount;
  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onCancelSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onShowClubInfo;
  final VoidCallback onShowPinnedMessages;

  const ChatAppBar({
    Key? key,
    required this.club,
    this.onlineCount,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onCancelSelection,
    required this.onDeleteSelected,
    required this.onShowClubInfo,
    required this.onShowPinnedMessages,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isSelectionMode) {
      return _buildSelectionAppBar(context);
    }
    return _buildNormalAppBar(context);
  }

  Widget _buildNormalAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Color(0xFF003f9b),
      foregroundColor: Colors.white,
      elevation: 2,
      title: GestureDetector(
        onTap: onShowClubInfo,
        child: Row(
          children: [
            _buildClubAvatar(),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    club.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (onlineCount != null && onlineCount! > 0)
                    Text(
                      '$onlineCount members online',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: onShowPinnedMessages,
          icon: Icon(Icons.push_pin),
          tooltip: 'Pinned Messages',
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuSelection(context, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Club Info'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(width: 12),
                  Text('Search Messages'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 12),
                  Text('Chat Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Color(0xFF003f9b),
      foregroundColor: Colors.white,
      elevation: 2,
      leading: IconButton(
        onPressed: onCancelSelection,
        icon: Icon(Icons.close),
      ),
      title: Text(
        '$selectedCount selected',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          onPressed: selectedCount > 0 ? onDeleteSelected : null,
          icon: Icon(Icons.delete),
          tooltip: 'Delete Messages',
        ),
      ],
    );
  }

  Widget _buildClubAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
      ),
      child: club.logo != null
          ? ClipOval(
              child: Image.network(
                club.logo!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultClubLogo();
                },
              ),
            )
          : _buildDefaultClubLogo(),
    );
  }

  Widget _buildDefaultClubLogo() {
    return Center(
      child: Text(
        club.name.isNotEmpty ? club.name[0].toUpperCase() : 'C',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'info':
        onShowClubInfo();
        break;
      case 'search':
        _showSearchDialog(context);
        break;
      case 'settings':
        _showSettingsDialog(context);
        break;
    }
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Messages'),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Enter search term...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chat Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Notifications'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text('Read Receipts'),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
