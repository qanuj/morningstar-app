import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../widgets/matches_list_widget.dart';
import '../../widgets/create_match_dialog.dart';
import '../../widgets/svg_avatar.dart';
import '../../services/match_service.dart';

class ClubMatchesScreen extends StatefulWidget {
  final Club club;

  const ClubMatchesScreen({super.key, required this.club});

  @override
  State<ClubMatchesScreen> createState() => _ClubMatchesScreenState();
}

class _ClubMatchesScreenState extends State<ClubMatchesScreen> {
  final GlobalKey<MatchesListWidgetState> _matchesListKey = GlobalKey();
  bool _canCreateMatches = false;
  bool _isCheckingPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkCreatePermissions();
  }

  Future<void> _checkCreatePermissions() async {
    try {
      final canCreate = await MatchService.canCreateMatches(widget.club.id);
      if (mounted) {
        setState(() {
          _canCreateMatches = canCreate;
          _isCheckingPermissions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _canCreateMatches = false;
          _isCheckingPermissions = false;
        });
      }
    }
  }

  void _showCreateMatchDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateMatchDialog(
        club: widget.club,
        onMatchCreated: () {
          // Refresh the matches list
          _matchesListKey.currentState?.refreshMatches();
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    _matchesListKey.currentState?.showFilterBottomSheet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003f9b), // Brand blue
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
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
                child: SVGAvatar(
                  imageUrl: widget.club.logo,
                  size: 36,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  fallbackIcon: Icons.groups,
                  iconSize: 20,
                  iconColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Club Name and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.club.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Matches',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Filter Icon
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filter matches',
          ),
          // Create Match Icon (if user has permissions)
          if (_canCreateMatches && !_isCheckingPermissions)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _showCreateMatchDialog,
              tooltip: 'Create Match',
            ),
        ],
      ),
      body: MatchesListWidget(
        key: _matchesListKey,
        clubFilter: widget.club,
        showHeader: false,
        customEmptyMessage: 'No matches scheduled for ${widget.club.name} yet',
      ),
    );
  }
}
