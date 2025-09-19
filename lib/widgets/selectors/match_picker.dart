import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/match.dart';
import '../../services/match_service.dart';
import '../../widgets/svg_avatar.dart';

/// Shared match picker component that can be used from any context
/// Can either pick existing matches or trigger creation of new matches
class MatchPicker extends StatefulWidget {
  final String clubId;
  final ValueChanged<MatchListItem> onExistingMatchSelected;
  final VoidCallback onCreateNewMatch;
  final String title;
  final String createNewText;
  final String createNewDescription;

  const MatchPicker({
    super.key,
    required this.clubId,
    required this.onExistingMatchSelected,
    required this.onCreateNewMatch,
    this.title = 'Send Match to Chat',
    this.createNewText = 'Create New Match',
    this.createNewDescription = 'Open the match creation screen to set up a new fixture.',
  });

  @override
  State<MatchPicker> createState() => _MatchPickerState();
}

class _MatchPickerState extends State<MatchPicker> {
  final List<MatchListItem> _matches = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final matches = await MatchService.getMatches(
        clubId: widget.clubId,
        upcomingOnly: true,
      );
      if (mounted) {
        setState(() {
          _matches
            ..clear()
            ..addAll(matches);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load matches';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadMatches,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCreateNewCard(theme),
              const SizedBox(height: 24),
              Text(
                'Existing Matches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildMatchesContent(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateNewCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pop();
          widget.onCreateNewMatch();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.createNewText,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.createNewDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchesContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadMatches,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_matches.isEmpty) {
      return Center(
        child: Text(
          'No upcoming matches found for this club.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
        ),
      );
    }

    return ListView.separated(
      itemCount: _matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final match = _matches[index];
        return _MatchListTile(
          match: match,
          onTap: () {
            Navigator.of(context).pop();
            widget.onExistingMatchSelected(match);
          },
        );
      },
    );
  }
}

class _MatchListTile extends StatelessWidget {
  final MatchListItem match;
  final VoidCallback onTap;

  const _MatchListTile({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localDate = match.matchDate.toLocal();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TeamLogo(
                    logoUrl: match.team?.logo,
                    fallbackColor: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _TeamLogo(
                    logoUrl: match.opponentTeam?.logo,
                    fallbackColor: theme.colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${DateFormat('EEE, MMM d').format(localDate)} · ${DateFormat('h:mma').format(localDate).toLowerCase()}',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Text(
                match.location.isNotEmpty ? match.location : 'Venue TBD',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (match.team?.name != null || match.opponentTeam?.name != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${match.team?.name ?? match.club.name} vs ${match.opponentTeam?.name ?? match.opponent ?? 'TBD'}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String? logoUrl;
  final Color fallbackColor;

  const _TeamLogo({this.logoUrl, required this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: fallbackColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SVGAvatar(
                imageUrl: logoUrl!,
                size: 48,
                backgroundColor: Colors.transparent,
                iconColor: fallbackColor,
                fallbackIcon: Icons.sports_cricket,
                showBorder: false,
                fit: BoxFit.cover,
              ),
            )
          : Icon(
              Icons.shield_outlined,
              color: fallbackColor,
              size: 24,
            ),
    );
  }
}