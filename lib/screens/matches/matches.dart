import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club.dart';
import '../../providers/club_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/matches_list_widget.dart';
import '../../widgets/club_selector_dialog.dart';
import '../../services/match_service.dart';
import 'create_match_screen.dart';

class MatchesScreen extends StatefulWidget {
  final Club? clubFilter;

  const MatchesScreen({super.key, this.clubFilter});

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
    // Direct to create match screen - let it handle club selection
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateMatchScreen(
          onMatchCreated: () {
            // Refresh the matches list
            _matchesListKey.currentState?.refreshMatches();
          },
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    _matchesListKey.currentState?.showFilterBottomSheet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CricketStyleAppBar(
        title: 'Duggy',
        subtitle: widget.clubFilter != null
            ? '${widget.clubFilter!.name} Matches'
            : 'Upcoming matches',
        leadingIcon: Icons.sports_cricket,
        customActions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showCreateMatchDialog,
            tooltip: 'Create new match',
            ),
        ],
      ),
      body: MatchesListWidget(
        key: _matchesListKey,
        clubFilter: widget.clubFilter,
        showHeader: false,
      ),
    );
  }
}
