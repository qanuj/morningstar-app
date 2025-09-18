import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../widgets/matches_list_widget.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/match_service.dart';
import '../matches/create_match_screen.dart';

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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ClubAppBar(
        clubName: widget.club.name,
        clubLogo: widget.club.logo,
        subtitle: 'Matches',
        actions: [
          // Create Match Icon (if user has permissions)
          if (_canCreateMatches && !_isCheckingPermissions)
            IconButton(
              icon: const Icon(Icons.add),
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
