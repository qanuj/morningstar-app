import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/match_details.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../widgets/svg_avatar.dart';
import '../../providers/user_provider.dart';

class PracticeMatchDetailScreen extends StatefulWidget {
  final String matchId;
  final String? initialType;

  const PracticeMatchDetailScreen({super.key, required this.matchId, this.initialType});

  @override
  State<PracticeMatchDetailScreen> createState() => _PracticeMatchDetailScreenState();
}

class _PracticeMatchDetailScreenState extends State<PracticeMatchDetailScreen> {
  MatchDetailData? _detail;
  bool _isLoading = false;
  String? _error;
  int _selectedTabIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadPracticeDetail();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPracticeDetail() async {
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

  /// Find the current user's RSVP in the practice RSVP list
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
        title: const Text('Practice'),
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
            label: 'Attendees',
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
        children: [placeholder, placeholder],
      );
    }

    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _selectedTabIndex = index);
      },
      children: [_buildInfoTab(_detail!), _buildAttendeesTab(_detail!)],
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
              'Unable to load practice details',
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
              onPressed: _loadPracticeDetail,
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
      onRefresh: _loadPracticeDetail,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildPracticeHeader(detail),
          const SizedBox(height: 12),
          // Show user RSVP if exists
          if (userRsvp != null) _buildUserRsvp(userRsvp),
        ],
      ),
    );
  }

  Widget _buildAttendeesTab(MatchDetailData detail) {
    final attendees = _sortedAttendees(detail.team?.squad ?? const []);
    final reserves = _sortedAttendees(detail.team?.members ?? const []);

    return RefreshIndicator(
      onRefresh: _loadPracticeDetail,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _buildPracticeInfo(detail),
          const SizedBox(height: 16),
          _buildSectionBadge('Confirmed attendees'),
          const SizedBox(height: 8),
          _buildAttendeesList(attendees),
          if (reserves.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSectionBadge('Maybe attending'),
            const SizedBox(height: 8),
            _buildAttendeesList(reserves),
          ],
        ],
      ),
    );
  }

  Widget _buildPracticeHeader(MatchDetailData detail) {
    final theme = Theme.of(context);
    final practiceDate = detail.matchDate.toLocal();
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
                text: 'Practice Session',
                background: onPrimary.withOpacity(0.2),
                textColor: onPrimary,
              ),
              const SizedBox(width: 8),
              _buildHeaderChip(
                text: DateFormat('EEE, MMM d').format(practiceDate),
                background: onPrimary.withOpacity(0.1),
                textColor: onPrimary,
              ),
              const Spacer(),
              if (detail.isCancelled)
                _buildHeaderChip(
                  text: 'Cancelled',
                  background: Colors.redAccent.withOpacity(0.3),
                  textColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: onPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sports_cricket,
                  color: onPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.team?.name ?? 'Club Practice',
                      style: TextStyle(
                        color: onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail.team?.club?.name != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail.team!.club!.name!,
                        style: TextStyle(
                          color: onPrimary.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildHeaderInfoRow(
            icon: Icons.access_time,
            label: 'Start time',
            value: DateFormat('hh:mm a').format(practiceDate),
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

  Widget _buildPracticeInfo(MatchDetailData detail) {
    final theme = Theme.of(context);
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
              'Practice Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Expected Attendees: ${(detail.team?.squad ?? []).length}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeesList(List<MatchDetailPlayer> attendees) {
    final theme = Theme.of(context);
    final borderColor = _panelBorderColor(theme);
    final containerColor = _panelColor(theme);

    if (attendees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          color: containerColor,
        ),
        child: Center(
          child: Text(
            'No attendees listed yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        color: containerColor,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: attendees.length,
        separatorBuilder: (context, index) => Divider(
          color: borderColor,
          height: 1,
          thickness: 0.5,
        ),
        itemBuilder: (context, index) => _buildAttendeeItem(attendees[index]),
      ),
    );
  }

  Widget _buildAttendeeItem(MatchDetailPlayer player) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          SVGAvatar(
            imageUrl: player.profilePicture,
            size: 36,
            fallbackText: player.name,
            fallbackTextStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            iconColor: theme.colorScheme.primary,
            fallbackIcon: Icons.person_outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (player.selectedRole != null && player.selectedRole!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    player.selectedRole!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (player.isCaptain || player.isWicketKeeper) ...[
            const SizedBox(width: 8),
            Wrap(
              spacing: 4,
              children: [
                if (player.isCaptain)
                  _Badge(label: 'C', color: Colors.blueAccent),
                if (player.isWicketKeeper)
                  _Badge(label: 'WK', color: Colors.green),
              ],
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


  List<MatchDetailPlayer> _sortedAttendees(List<MatchDetailPlayer> attendees) {
    final sorted = List<MatchDetailPlayer>.from(attendees);
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
        return 'Attending';
      case 'NO':
        return 'Not attending';
      case 'MAYBE':
        return 'Maybe';
      default:
        return 'Pending';
    }
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
