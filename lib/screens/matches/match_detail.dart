import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/match_details.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../widgets/svg_avatar.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;
  final String? initialType;

  const MatchDetailScreen({super.key, required this.matchId, this.initialType});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchDetailData? _detail;
  bool _isLoading = false;
  String? _error;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMatchDetail();
  }

  Future<void> _loadMatchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.get('/matches/${widget.matchId}');
      setState(() {
        _detail = MatchDetailData.fromJson(response);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).appBarTheme.backgroundColor
            : AppTheme.cricketGreen,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).appBarTheme.foregroundColor
            : Colors.white,
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.background
          : const Color(0xFFF2F2F2),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedTabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Info',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Squad',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_detail == null) {
      final placeholder = _error != null ? _buildError() : _buildLoading();
      return IndexedStack(
        index: _selectedTabIndex,
        children: [placeholder, placeholder],
      );
    }

    return IndexedStack(
      index: _selectedTabIndex,
      children: [_buildInfoTab(_detail!), _buildSquadTab(_detail!)],
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              'Unable to load match details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMatchDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(MatchDetailData detail) {
    return RefreshIndicator(
      onRefresh: _loadMatchDetail,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildMatchHeader(detail),
          const SizedBox(height: 12),
          _buildQuickFacts(detail),
          if (detail.userRsvp != null) ...[
            const SizedBox(height: 12),
            _buildUserRsvp(detail.userRsvp!),
          ],
          if (detail.matchPreferences.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPreferenceCards(detail),
          ],
        ],
      ),
    );
  }

  Widget _buildSquadTab(MatchDetailData detail) {
    final homeColor = Theme.of(context).colorScheme.primary;
    final awayColor = Theme.of(context).colorScheme.secondary;
    final homeSquad = _sortedSquad(detail.team?.squad ?? const []);
    final awaySquad = _sortedSquad(detail.opponentTeam?.squad ?? const []);

    return RefreshIndicator(
      onRefresh: _loadMatchDetail,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _buildSquadHeader(detail, homeColor, awayColor),
          const SizedBox(height: 10),
          _buildSectionBadge('Playing squad'),
          const SizedBox(height: 8),
          _buildPlayersColumns(homeSquad, awaySquad, homeColor, awayColor),
          const SizedBox(height: 14),
          _buildSectionBadge('Reserves'),
          const SizedBox(height: 8),
          _buildReservesSection(detail, homeColor, awayColor),
        ],
      ),
    );
  }

  Widget _buildMatchHeader(MatchDetailData detail) {
    final theme = Theme.of(context);
    final matchDate = detail.matchDate.toLocal();
    final onPrimary = theme.colorScheme.onPrimary;
    final gradientStart = theme.colorScheme.primary;
    final gradientEnd = theme.colorScheme.primary.withOpacity(
      theme.brightness == Brightness.dark ? 0.55 : 0.85,
    );
    final locationText = detail.location == null
        ? 'Venue TBA'
        : [
            detail.location!.name,
            if (detail.location!.city != null) detail.location!.city,
            if (detail.location!.address != null) detail.location!.address,
          ].whereType<String>().join(', ');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildHeaderChip(
                text: _getReadableMatchType(detail.type),
                background: onPrimary.withOpacity(0.2),
                textColor: onPrimary,
              ),
              const SizedBox(width: 8),
              _buildHeaderChip(
                text: DateFormat('EEE, MMM d').format(matchDate),
                background: onPrimary.withOpacity(0.1),
                textColor: onPrimary,
              ),
              const Spacer(),
              if (detail.isCancelled)
                _buildHeaderChip(
                  text: 'Cancelled',
                  background: Colors.redAccent.withOpacity(0.3),
                  textColor: Colors.white,
                )
              else if (detail.type.toUpperCase() == 'TOURNAMENT')
                _buildHeaderChip(
                  text: 'Tournament',
                  background: onPrimary.withOpacity(0.15),
                  textColor: onPrimary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTeamIdentity(
                  detail.team,
                  fallback: 'Home Team',
                  textColor: onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Text(
                    'vs',
                    style: TextStyle(
                      color: onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail.type.toUpperCase() == 'TOURNAMENT')
                    Icon(
                      Icons.emoji_events,
                      color: onPrimary.withOpacity(0.85),
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTeamIdentity(
                  detail.opponentTeam,
                  fallback: detail.opponent ?? 'Opponent',
                  textColor: onPrimary,
                  alignRight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildHeaderInfoRow(
            icon: Icons.access_time,
            label: 'Start time',
            value: DateFormat('hh:mm a').format(matchDate),
            color: onPrimary,
          ),
          const SizedBox(height: 6),
          _buildHeaderInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Venue',
            value: locationText,
            color: onPrimary,
          ),
          if (detail.isCancelled && detail.cancellationReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                detail.cancellationReason!,
                style: TextStyle(color: onPrimary, height: 1.3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderChip({
    required String text,
    required Color background,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTeamIdentity(
    MatchDetailTeam? team, {
    required String fallback,
    required Color textColor,
    bool alignRight = false,
  }) {
    final name = team?.name ?? fallback;
    final club = team?.club?.name;
    final alignment = alignRight
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        SVGAvatar(
          imageUrl: team?.logo,
          size: 30,
          backgroundColor: Colors.white.withOpacity(0.15),
          iconColor: textColor,
          fallbackIcon: Icons.shield_outlined,
          fallbackText: name,
          fallbackTextStyle: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        if (club != null) ...[
          const SizedBox(height: 2),
          Text(
            club,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: TextStyle(color: textColor.withOpacity(0.8)),
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(value, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFacts(MatchDetailData detail) {
    final theme = Theme.of(context);
    final facts = <_FactItem>[
      _FactItem(
        icon: Icons.remove_red_eye_outlined,
        label: 'Visibility',
        value: detail.matchPreferences.any((pref) => pref.hideUntilRsvp)
            ? 'Hidden until RSVP'
            : 'Visible to members',
      ),
      _FactItem(
        icon: Icons.notifications_active_outlined,
        label: 'Notifications',
        value: detail.matchPreferences.any((pref) => pref.notifyMembers)
            ? 'Enabled'
            : 'Disabled',
      ),
      _FactItem(
        icon: Icons.timer_outlined,
        label: 'Created',
        value: DateFormat('MMM d, yyyy').format(detail.createdAt.toLocal()),
      ),
    ];

    final panelColor = _panelColor(theme);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick facts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: facts
                  .map(
                    (fact) => _FactChip(
                      icon: fact.icon,
                      label: fact.label,
                      value: fact.value,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRsvp(MatchDetailUserRsvp rsvp) {
    final color = _getRSVPColor(rsvp.status);
    final panelColor = _panelColor(Theme.of(context));
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getRSVPIcon(rsvp.status), color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your RSVP',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getRSVPText(rsvp.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                  if (rsvp.selectedRole != null) ...[
                    const SizedBox(height: 3),
                    Text('Role: ${rsvp.selectedRole}'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceCards(MatchDetailData detail) {
    final theme = Theme.of(context);

    MatchDetailTeam? teamForClub(String clubId) {
      if (detail.team?.clubId == clubId) return detail.team;
      if (detail.opponentTeam?.clubId == clubId) return detail.opponentTeam;
      return null;
    }

    final cards = detail.matchPreferences.map((pref) {
      final team = teamForClub(pref.clubId);
      return _PreferenceCard(preference: pref, team: team);
    }).toList();

    final panelColor = _panelColor(theme);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team allocations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: cards
                  .map(
                    (card) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: card,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<MatchDetailPlayer> _sortedSquad(List<MatchDetailPlayer> squad) {
    final sorted = List<MatchDetailPlayer>.from(squad);
    sorted.sort((a, b) {
      if (a.isCaptain != b.isCaptain) {
        return a.isCaptain ? -1 : 1;
      }
      if (a.isWicketKeeper != b.isWicketKeeper) {
        return a.isWicketKeeper ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  Widget _buildSquadHeader(
    MatchDetailData detail,
    Color homeColor,
    Color awayColor,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildTeamPanel(
              team: detail.team,
              fallback: 'Home Team',
              accent: homeColor,
              alignRight: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildTeamPanel(
              team: detail.opponentTeam,
              fallback: detail.opponent ?? 'Opponent',
              accent: awayColor,
              alignRight: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamPanel({
    required MatchDetailTeam? team,
    required String fallback,
    required Color accent,
    required bool alignRight,
  }) {
    final theme = Theme.of(context);
    final name = team?.name ?? fallback;
    final displayName = _formatTeamName(name);
    final club = team?.club?.name;
    final textAlign = alignRight ? TextAlign.right : TextAlign.left;
    final avatar = SVGAvatar(
      imageUrl: team?.logo,
      size: 32,
      backgroundColor: accent.withOpacity(0.1),
      iconColor: accent,
      fallbackIcon: Icons.shield_outlined,
      fallbackText: displayName,
      fallbackTextStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    );

    final titleWidget = displayName == name
        ? Text(
            displayName,
            textAlign: textAlign,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          )
        : Tooltip(
            message: name,
            child: Text(
              displayName,
              textAlign: textAlign,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          );

    final content = Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        titleWidget,
        if (club != null) ...[
          const SizedBox(height: 4),
          Text(
            club,
            textAlign: textAlign,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );

    final panelColor = _panelColor(theme);
    final borderColor = _panelBorderColor(theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: alignRight
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: content),
                const SizedBox(width: 8),
                avatar,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 8),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _buildSectionBadge(String label, {Color? color}) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.primary;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: badgeColor,
          ),
        ),
      ),
    );
  }

  Color _panelColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.35)
        : Colors.white;
  }

  Color _panelBorderColor(ThemeData theme) {
    final opacity = theme.brightness == Brightness.dark ? 0.35 : 0.12;
    return theme.colorScheme.outline.withOpacity(opacity);
  }

  Widget _buildPlayersColumns(
    List<MatchDetailPlayer> squad1,
    List<MatchDetailPlayer> squad2,
    Color homeColor,
    Color awayColor,
  ) {
    final targetLength = math.max(squad1.length, squad2.length);
    final paddedSquad1 = List<MatchDetailPlayer?>.from(squad1)
      ..addAll(
        List<MatchDetailPlayer?>.filled(targetLength - squad1.length, null),
      );
    final paddedSquad2 = List<MatchDetailPlayer?>.from(squad2)
      ..addAll(
        List<MatchDetailPlayer?>.filled(targetLength - squad2.length, null),
      );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPlayerCells(
            players: paddedSquad1,
            accent: homeColor,
            alignRight: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPlayerCells(
            players: paddedSquad2,
            accent: awayColor,
            alignRight: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCells({
    required List<MatchDetailPlayer?> players,
    required Color accent,
    required bool alignRight,
  }) {
    final theme = Theme.of(context);
    final borderColor = _panelBorderColor(theme);
    final containerColor = _panelColor(theme);
    final cells = <Widget>[];
    final hasAnyPlayer = players.any((player) => player != null);

    if (!hasAnyPlayer) {
      cells.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Text(
            'No players listed yet.',
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    } else {
      for (var i = 0; i < players.length; i++) {
        cells.add(
          _buildPlayerCell(
            player: players[i],
            accent: accent,
            alignRight: alignRight,
          ),
        );
        if (i != players.length - 1) {
          cells.add(Divider(color: borderColor, height: 0.5, thickness: 0.5));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        color: containerColor,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: cells),
    );
  }

  Widget _buildPlayerCell({
    required MatchDetailPlayer? player,
    required Color accent,
    required bool alignRight,
  }) {
    final theme = Theme.of(context);
    final textAlign = alignRight ? TextAlign.right : TextAlign.left;
    if (player == null) {
      return const SizedBox(height: 44);
    }

    final avatar = SVGAvatar(
      imageUrl: player.profilePicture,
      size: 34,
      fallbackText: player.name,
      fallbackTextStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: accent.withOpacity(0.1),
      iconColor: accent,
      fallbackIcon: Icons.person_outline,
    );

    final nameWidget = Text(
      player.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    final roleWidget =
        player.selectedRole != null && player.selectedRole!.isNotEmpty
        ? Text(
            player.selectedRole!,
            textAlign: textAlign,
            style: theme.textTheme.bodySmall,
          )
        : null;

    final badges = <Widget>[];
    if (player.isCaptain) {
      badges.add(_Badge(label: 'C', color: Colors.blueAccent));
    }
    if (player.isWicketKeeper) {
      badges.add(_Badge(label: 'WK', color: Colors.green));
    }

    final content = Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        nameWidget,
        if (roleWidget != null) ...[const SizedBox(height: 2), roleWidget],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 3),
          Wrap(
            alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
            spacing: 3,
            children: badges,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: alignRight
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(child: content),
                const SizedBox(width: 8),
                avatar,
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 8),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _buildReservesSection(
    MatchDetailData detail,
    Color homeColor,
    Color awayColor,
  ) {
    final homeReserves = _sortedMembers(detail.team?.members ?? const []);
    final awayReserves = _sortedMembers(
      detail.opponentTeam?.members ?? const [],
    );
    final hasReserves = homeReserves.isNotEmpty || awayReserves.isNotEmpty;

    if (!hasReserves) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          'No reserves listed yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    return _buildPlayersColumns(
      homeReserves,
      awayReserves,
      homeColor,
      awayColor,
    );
  }

  List<MatchDetailPlayer> _sortedMembers(List<MatchDetailPlayer> members) {
    final sorted = List<MatchDetailPlayer>.from(members);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  Color _getRSVPColor(String status) {
    switch (status.toUpperCase()) {
      case 'YES':
        return Colors.green;
      case 'NO':
        return Colors.redAccent;
      case 'MAYBE':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getRSVPIcon(String status) {
    switch (status.toUpperCase()) {
      case 'YES':
        return Icons.check_circle;
      case 'NO':
        return Icons.cancel;
      case 'MAYBE':
        return Icons.help_outline;
      default:
        return Icons.hourglass_bottom;
    }
  }

  String _getRSVPText(String status) {
    switch (status.toUpperCase()) {
      case 'YES':
        return 'Going';
      case 'NO':
        return 'Not going';
      case 'MAYBE':
        return 'Maybe';
      default:
        return 'Pending';
    }
  }

  String _getReadableMatchType(String type) {
    switch (type.toLowerCase()) {
      case 'game':
        return 'Match';
      case 'practice':
        return 'Practice';
      case 'tournament':
        return 'Tournament';
      case 'friendly':
        return 'Friendly';
      case 'league':
        return 'League';
      default:
        return type.isNotEmpty
            ? '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}'
            : 'Match';
    }
  }

  String _formatTeamName(String name) {
    if (name.length <= 20) {
      return name;
    }

    final words = name
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.length >= 2) {
      final abbreviation = words.map((word) => word[0].toUpperCase()).join();
      if (abbreviation.length >= 2 && abbreviation.length <= 6) {
        return abbreviation;
      }
    }

    return name.substring(0, 3).toUpperCase();
  }
}

class _FactItem {
  final IconData icon;
  final String label;
  final String value;

  _FactItem({required this.icon, required this.label, required this.value});
}

class _FactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FactChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.6)
        : Colors.white;
    final borderColor = theme.colorScheme.outline.withOpacity(
      isDark ? 0.4 : 0.12,
    );
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  final MatchPreference preference;
  final MatchDetailTeam? team;

  const _PreferenceCard({required this.preference, required this.team});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withOpacity(
      theme.brightness == Brightness.dark ? 0.4 : 0.12,
    );
    final backgroundColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
        : Colors.white;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  team?.club?.name ?? 'Club ${preference.clubId}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text('${preference.spots} spots'),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PreferenceStat(
                label: 'Total expensed',
                value: '₹${preference.totalExpensed.toStringAsFixed(0)}',
              ),
              _PreferenceStat(
                label: 'Paid',
                value: '₹${preference.paidAmount.toStringAsFixed(0)}',
              ),
              _PreferenceStat(
                label: 'Squad released',
                value: preference.isSquadReleased ? 'Yes' : 'No',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceStat extends StatelessWidget {
  final String label;
  final String value;

  const _PreferenceStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.darken(),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

extension on Color {
  Color darken([double amount = .2]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
