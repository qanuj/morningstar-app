import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/match_details.dart';
import '../../models/match_fee.dart';
import '../../services/api_service.dart';
import '../../services/match_fee_service.dart';
import '../../utils/theme.dart';
import '../../widgets/svg_avatar.dart';
import '../../providers/user_provider.dart';
import 'match_fee_payment_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;
  final String? initialType;

  const MatchDetailScreen({super.key, required this.matchId, this.initialType});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchDetailData? _detail;
  MatchFeesResponse? _feesData;
  bool _isLoading = false;
  bool _isLoadingFees = false;
  String? _error;
  String? _feesError;
  int _selectedTabIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadMatchDetail();
    _loadMatchFees();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  Future<void> _loadMatchFees() async {
    setState(() {
      _isLoadingFees = true;
      _feesError = null;
    });

    try {
      final response = await MatchFeeService.getMatchFees(widget.matchId);
      setState(() {
        _feesData = response;
      });
    } catch (e) {
      setState(() {
        _feesError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingFees = false);
      }
    }
  }

  /// Find the current user's RSVP in the match RSVP list
  MatchRSVP? _getCurrentUserRsvp(MatchDetailData detail) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.user?.id;

    if (currentUserId == null) return null;

    try {
      return detail.rsvps.firstWhere(
        (rsvp) => rsvp.user?.id == currentUserId,
      );
    } catch (e) {
      // No RSVP found for current user
      return null;
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
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
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
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Fees',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_detail == null) {
      final placeholder = _error != null ? _buildError() : _buildLoading();
      return PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedTabIndex = index);
        },
        children: [placeholder, placeholder, placeholder],
      );
    }

    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _selectedTabIndex = index);
      },
      children: [
        _buildInfoTab(_detail!),
        _buildSquadTab(_detail!),
        _buildFeesTab(_detail!)
      ],
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
    final userRsvp = _getCurrentUserRsvp(detail);

    return RefreshIndicator(
      onRefresh: _loadMatchDetail,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildMatchHeader(detail),
          const SizedBox(height: 12),
          // Show user RSVP if exists
          if (userRsvp != null) _buildUserRsvp(userRsvp),
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
    final locationText = detail.location == null
        ? 'Venue TBA'
        : [
            detail.location!.name,
            if (detail.location!.city != null) detail.location!.city,
          ].whereType<String>().take(2).join(', ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Date and Time - Most Important
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(matchDate),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('h:mm a').format(matchDate),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Teams Row
            Row(
              children: [
                // Home Team
                Expanded(
                  child: _buildSimpleTeamInfo(
                    team: detail.team,
                    fallback: 'Home Team',
                    alignRight: false,
                  ),
                ),

                // VS and Match Type
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getReadableMatchType(detail.type),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Away Team
                Expanded(
                  child: _buildSimpleTeamInfo(
                    team: detail.opponentTeam,
                    fallback: detail.opponent ?? 'Opponent',
                    alignRight: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Venue
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    locationText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Status badges
            if (detail.isCancelled) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Match Cancelled',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (detail.cancellationReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    detail.cancellationReason!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserRsvp(MatchRSVP rsvp) {
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

  Widget _buildSimpleTeamInfo({
    required MatchDetailTeam? team,
    required String fallback,
    required bool alignRight,
  }) {
    final theme = Theme.of(context);
    final teamName = team?.name ?? fallback;
    final clubName = team?.club?.name;

    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Team Logo
        SVGAvatar(
          imageUrl: team?.logo,
          size: 48,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          iconColor: theme.colorScheme.primary,
          fallbackIcon: Icons.shield_outlined,
          fallbackText: teamName,
          fallbackTextStyle: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),

        // Team Name
        Text(
          teamName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Club Name (if different from team name)
        if (clubName != null && clubName != teamName) ...[
          const SizedBox(height: 2),
          Text(
            clubName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildFeesTab(MatchDetailData detail) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadMatchFees();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoadingFees)
            const Center(child: CircularProgressIndicator())
          else if (_feesError != null)
            _buildFeesError()
          else if (_feesData != null)
            _buildFeesContent(detail, _feesData!)
          else
            _buildNoFeesData(),
        ],
      ),
    );
  }

  Widget _buildFeesError() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text('Failed to load fees information'),
            const SizedBox(height: 8),
            Text(
              _feesError!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMatchFees,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFeesData() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.payments_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 8),
            Text('No fees information available'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeesContent(MatchDetailData detail, MatchFeesResponse feesData) {
    final isAdmin = feesData.canManageFees;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User's Fee Status (if applicable)
        if (feesData.userFeeStatus != null)
          _buildUserFeeStatus(feesData.userFeeStatus!),

        const SizedBox(height: 16),

        // Admin Controls (if user is admin)
        if (isAdmin) ...[
          _buildAdminControls(detail, feesData),
          const SizedBox(height: 16),
        ],

        // All Players Fee Status
        _buildAllPlayersFeesSection(feesData),
      ],
    );
  }

  Widget _buildUserFeeStatus(UserFeeStatus userFeeStatus) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!userFeeStatus.isPaid) {
      statusColor = Colors.red;
      statusIcon = Icons.payment;
      statusText = 'Payment Required';
    } else if (!userFeeStatus.isConfirmed) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
      statusText = 'Pending Confirmation';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Payment Confirmed';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Your Fee Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount: ${MatchFeeService.formatCurrency(userFeeStatus.amount)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (userFeeStatus.paymentMethod != null) ...[
                      const SizedBox(height: 4),
                      Text('Method: ${userFeeStatus.paymentMethod}'),
                    ],
                  ],
                ),
                if (!userFeeStatus.isPaid)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MatchFeePaymentScreen(
                            matchId: widget.matchId,
                            amount: userFeeStatus.amount,
                            clubName: _feesData!.match.club.name,
                            clubUpiId: _feesData!.match.club.upiId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cricketGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Pay Now'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminControls(MatchDetailData detail, MatchFeesResponse feesData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: AppTheme.cricketGreen),
                const SizedBox(width: 8),
                Text(
                  'Admin Controls',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Navigate to fee management screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fee management screen coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Manage Fees'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cricketGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Navigate to pending confirmations
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pending confirmations screen coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.pending_actions),
                    label: const Text('Confirmations'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllPlayersFeesSection(MatchFeesResponse feesData) {
    if (feesData.transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.group_outlined, color: Colors.grey, size: 48),
              const SizedBox(height: 8),
              Text(
                'No fees assigned yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Club admin will assign match fees to players',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Players (${feesData.transactions.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...feesData.transactions.map((transaction) =>
              _buildPlayerFeeCard(transaction)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerFeeCard(MatchFeeTransaction transaction) {
    Color statusColor;
    IconData statusIcon;

    if (!transaction.isPaid) {
      statusColor = Colors.red;
      statusIcon = Icons.payment;
    } else if (!transaction.isConfirmed) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: transaction.user?.profilePicture != null
                ? NetworkImage(transaction.user!.profilePicture!)
                : null,
            child: transaction.user?.profilePicture == null
                ? Text(
                    transaction.user?.name.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.user?.name ?? 'Unknown Player',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${MatchFeeService.formatCurrency(transaction.amount)} • ${transaction.paymentStatusText}',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
                if (transaction.paymentMethod != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'via ${transaction.paymentMethodText}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(statusIcon, color: statusColor, size: 20),
        ],
      ),
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
