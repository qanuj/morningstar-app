import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/matches_list_widget.dart';
import '../../services/match_service.dart';
import 'create_match_screen.dart';

class MatchesScreen extends StatefulWidget {
  final Club? clubFilter;
  final bool isFromHome;

  const MatchesScreen({super.key, this.clubFilter, this.isFromHome = false});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final GlobalKey<MatchesListWidgetState> _matchesListKey = GlobalKey();
  bool _canCreateMatches = false;
  bool _isCheckingPermissions = false;

  @override
  void initState() {
    super.initState();
    if (widget.clubFilter != null) {
      _checkCreatePermissions();
    }
  }

  Future<void> _checkCreatePermissions() async {
    if (widget.clubFilter == null) return;

    setState(() => _isCheckingPermissions = true);

    try {
      final canCreate = await MatchService.canCreateMatches(
        widget.clubFilter!.id,
      );
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateMatchScreen(
          onMatchCreated: (_) {
            // Refresh the matches list
            _matchesListKey.currentState?.refreshMatches();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we should show create button
    final showCreateButton = widget.clubFilter != null 
        ? (_canCreateMatches && !_isCheckingPermissions)  // For club matches, check permissions
        : true; // For home matches, always show

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DuggyAppBar(
        subtitle: widget.clubFilter != null
            ? '${widget.clubFilter!.name} Matches'
            : 'Matches',
        actions: [
          if (showCreateButton)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateMatchDialog,
              tooltip: 'Create Match',
            ),
        ],
      ),
      body: MatchesListWidget(
        key: _matchesListKey,
        clubFilter: widget.clubFilter,
        showHeader: false,
        isFromHome: widget.isFromHome,
        customEmptyMessage: widget.clubFilter != null 
            ? 'No matches scheduled for ${widget.clubFilter!.name} yet'
            : 'No matches found for your clubs',
      ),
    );
  }
}
