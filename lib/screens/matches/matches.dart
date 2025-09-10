import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/matches_list_widget.dart';
import '../../widgets/create_match_dialog.dart';
import '../../services/match_service.dart';

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
      final canCreate = await MatchService.canCreateMatches(widget.clubFilter!.id);
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
    if (widget.clubFilter == null) return;
    
    showDialog(
      context: context,
      builder: (context) => CreateMatchDialog(
        club: widget.clubFilter!,
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
      appBar: PageAppBar(
        pageName: widget.clubFilter != null
            ? '${widget.clubFilter!.name} Matches'
            : 'Matches',
        customActions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.8)
                  : Theme.of(context).primaryColor,
            ),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filter matches',
          ),
        ],
      ),
      body: MatchesListWidget(
        key: _matchesListKey,
        clubFilter: widget.clubFilter,
        showHeader: false,
      ),
      floatingActionButton: widget.clubFilter != null && !_isCheckingPermissions && _canCreateMatches
          ? FloatingActionButton.extended(
              onPressed: _showCreateMatchDialog,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              icon: Icon(Icons.add),
              label: Text('Create Match'),
            )
          : null,
    );
  }
}
