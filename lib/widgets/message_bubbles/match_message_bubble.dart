import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club_message.dart';
import '../../services/match_service.dart';
import '../../services/notification_service.dart';
import '../svg_avatar.dart';
import 'base_message_bubble.dart';

/// A specialized message bubble for displaying match announcements
class MatchMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;
  final Function()? onViewMatch;
  final Function()? onRSVP;

  const MatchMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.isSelected,
    this.showSenderInfo = false,
    this.onReactionRemoved,
    this.onViewMatch,
    this.onRSVP,
  });

  @override
  State<MatchMessageBubble> createState() => _MatchMessageBubbleState();
}

class _MatchMessageBubbleState extends State<MatchMessageBubble> {
  String?
  _currentRSVPStatus; // Track current RSVP status: 'YES', 'NO', 'MAYBE', or null
  Map<String, dynamic>? _resolvedMatchDetails;
  bool _isLoadingMatchDetails = false;
  String? _matchDetailsError;
  String? _registeredMatchId;

  @override
  void initState() {
    super.initState();
    // Initialize RSVP status from message data if available
    _resolvedMatchDetails = widget.message.matchDetails;
    _currentRSVPStatus = _extractRSVPStatus();

    if (_isValidMatchId(widget.message.matchId)) {
      _registerForMatchUpdates();
      _loadMatchDetails();
    }
  }

  @override
  void didUpdateWidget(covariant MatchMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldMatchId = oldWidget.message.matchId;
    final newMatchId = widget.message.matchId;

    final matchIdChanged = oldMatchId != newMatchId;
    final messageChanged = oldWidget.message.id != widget.message.id;
    final detailsChanged = oldWidget.message.matchDetails != widget.message.matchDetails;

    if (matchIdChanged || messageChanged || detailsChanged) {
      _resolvedMatchDetails = widget.message.matchDetails;
      _currentRSVPStatus = _extractRSVPStatus();
      _matchDetailsError = null;

      if (matchIdChanged) {
        _unregisterMatchUpdates(oldMatchId);
        if (_isValidMatchId(newMatchId)) {
          _registerForMatchUpdates();
          _loadMatchDetails();
        }
      } else if (_isValidMatchId(newMatchId)) {
        // Refresh counts if match details changed
        _loadMatchDetails();
      }
    }
  }

  String? _extractRSVPStatus() {
    // Try to extract RSVP status from matchDetails if available
    final matchDetails = widget.message.matchDetails;
    if (matchDetails != null && matchDetails['userRsvp'] != null) {
      final status = matchDetails['userRsvp']['status'];
      if (status is String && status.isNotEmpty) {
        return status.toUpperCase();
      }
    }
    return null;
  }

  Future<void> _loadMatchDetails() async {
    if (_isLoadingMatchDetails) return;

    final matchId = widget.message.matchId;
    if (!_isValidMatchId(matchId)) {
      return;
    }

    setState(() {
      _isLoadingMatchDetails = true;
      _matchDetailsError = null;
    });

    Map<String, dynamic>? detailedMatch;
    Map<String, dynamic>? clubMatch;
    final resolvedMatchId = matchId!.trim();

    try {
      detailedMatch = await MatchService.getMatchDetail(resolvedMatchId);
      if (detailedMatch != null && detailedMatch.isEmpty) {
        detailedMatch = null;
      }
    } catch (e) {
      debugPrint('❌ MatchMessageBubble: error fetching match detail: $e');
    }

    try {
      clubMatch = await MatchService.getClubMatch(
        clubId: widget.message.clubId,
        matchId: resolvedMatchId,
      );
    } catch (e) {
      debugPrint('❌ MatchMessageBubble: error fetching club match: $e');
    }

    if (!mounted) {
      return;
    }

    if ((detailedMatch == null || detailedMatch.isEmpty) &&
        (clubMatch == null || clubMatch.isEmpty)) {
      setState(() {
        _isLoadingMatchDetails = false;
        _matchDetailsError = 'Unable to load match details right now.';
      });
      return;
    }

    final mergedDetails = _composeMatchDetails(
      detail: detailedMatch,
      clubMatch: clubMatch,
    );

    setState(() {
      _resolvedMatchDetails = mergedDetails;
      final status =
          (mergedDetails['userRsvp'] as Map<String, dynamic>?)?['status'];
      if (status is String && status.isNotEmpty) {
        _currentRSVPStatus = status.toUpperCase();
      }
      _isLoadingMatchDetails = false;
      _matchDetailsError = null;
    });
  }

  Map<String, dynamic> _composeMatchDetails({
    Map<String, dynamic>? detail,
    Map<String, dynamic>? clubMatch,
  }) {
    String? asString(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final existing = Map<String, dynamic>.from(
      _resolvedMatchDetails ?? widget.message.matchDetails ?? <String, dynamic>{},
    );
    final existingHome = existing['homeTeam'] as Map<String, dynamic>? ?? {};
    final existingOpponent =
        existing['opponentTeam'] as Map<String, dynamic>? ?? {};
    final existingVenue = existing['venue'] as Map<String, dynamic>? ?? {};

    final detailTeam = detail?['team'] as Map<String, dynamic>?;
    final detailOpponentTeam = detail?['opponentTeam'] as Map<String, dynamic>?;
    final clubMatchTeam = clubMatch?['team'] as Map<String, dynamic>?;
    final clubMatchOpponent = clubMatch?['opponentTeam'] as Map<String, dynamic>?;

    final homeName =
        asString(detailTeam?['name']) ??
        asString(clubMatchTeam?['name']) ??
        asString(detail?['club']?['name']) ??
        asString(existingHome['name']) ??
        'Home Team';
    final homeLogo =
        asString(detailTeam?['logo']) ??
        asString(clubMatchTeam?['logo']) ??
        asString(detail?['club']?['logo']) ??
        asString(existingHome['logo']);

    final opponentName =
        asString(detailOpponentTeam?['name']) ??
        asString(clubMatchOpponent?['name']) ??
        asString(clubMatch?['opponent']) ??
        asString(detail?['opponent']) ??
        asString(existingOpponent['name']) ??
        'Opponent Team';
    final opponentLogo =
        asString(detailOpponentTeam?['logo']) ??
        asString(clubMatchOpponent?['logo']) ??
        asString(existingOpponent['logo']);

    final matchDateIso = asString(detail?['matchDate']) ??
        asString(clubMatch?['matchDate']) ??
        asString(existing['dateTime']);

    final venueName = asString(clubMatch?['location']) ??
        asString(detail?['location']) ??
        asString(existingVenue['name']) ??
        'Venue TBD';

    String? venueAddress = asString(existingVenue['address']);
    final detailCity = asString(detail?['city']);
    if ((venueAddress == null || venueAddress == venueName) &&
        detailCity != null && detailCity.isNotEmpty) {
      venueAddress = detailCity;
    }

    final userRsvp = (detail?['userRsvp'] as Map<String, dynamic>?) ??
        (clubMatch?['userRsvp'] as Map<String, dynamic>?) ??
        (existing['userRsvp'] as Map<String, dynamic>?);

    final result = Map<String, dynamic>.from(existing)
      ..['homeTeam'] = {
        'name': homeName,
        if (homeLogo != null) 'logo': homeLogo,
      }
      ..['opponentTeam'] = {
        'name': opponentName,
        if (opponentLogo != null) 'logo': opponentLogo,
      }
      ..['venue'] = {
        'name': venueName,
        if (venueAddress != null && venueAddress.isNotEmpty)
          'address': venueAddress,
      };

    if (matchDateIso != null) {
      result['dateTime'] = matchDateIso;
    }

    if (userRsvp != null) {
      result['userRsvp'] = userRsvp;
    }

    if (detail != null) {
      final detailCounts = detail['counts'];
      if (detailCounts is Map) {
        result['counts'] = Map<String, dynamic>.from(detailCounts);
      }

      if (detail['rsvps'] != null) {
        result['rsvps'] = detail['rsvps'];
      }
    }

    if (clubMatch != null) {
      final clubCounts = clubMatch['counts'];
      if (clubCounts is Map && result['counts'] == null) {
        result['counts'] = Map<String, dynamic>.from(clubCounts);
      }

      if (clubMatch['rsvps'] != null && result['rsvps'] == null) {
        result['rsvps'] = clubMatch['rsvps'];
      }
    }

    result['statusCounts'] = _extractStatusCounts(result);

    return result;
  }

  void _registerForMatchUpdates() {
    final matchId = widget.message.matchId;
    if (!_isValidMatchId(matchId)) {
      return;
    }

    if (_registeredMatchId == matchId) {
      return;
    }

    final resolvedMatchId = matchId!.trim();
    NotificationService.addMatchUpdateCallback(resolvedMatchId, _handleMatchUpdatePush);
    _registeredMatchId = resolvedMatchId;
  }

  void _unregisterMatchUpdates([String? matchId]) {
    final targetMatchId = matchId ?? _registeredMatchId;
    if (targetMatchId == null) {
      return;
    }

    final resolvedTarget = targetMatchId.trim();
    NotificationService.removeMatchUpdateCallback(resolvedTarget, _handleMatchUpdatePush);
    if (resolvedTarget == _registeredMatchId) {
      _registeredMatchId = null;
    }
  }

  Map<String, int> _extractStatusCounts(Map<String, dynamic> details) {
    final counts = <String, int>{
      'YES': 0,
      'NO': 0,
      'MAYBE': 0,
    };

    final aggregate = details['counts'];
    if (aggregate is Map<String, dynamic>) {
      counts['YES'] = ((aggregate['confirmed'] as num?)?.toInt() ?? 0) +
          ((aggregate['waitlisted'] as num?)?.toInt() ?? 0);
      counts['NO'] = (aggregate['declined'] as num?)?.toInt() ?? 0;
      counts['MAYBE'] = (aggregate['maybe'] as num?)?.toInt() ?? 0;
    }

    if (counts.values.every((value) => value == 0)) {
      final rsvps = details['rsvps'];
      if (rsvps is List) {
        for (final rsvp in rsvps) {
          if (rsvp is Map<String, dynamic>) {
            final status =
                (rsvp['status']?.toString().toUpperCase() ?? '').trim();
            if (counts.containsKey(status)) {
              counts[status] = (counts[status] ?? 0) + 1;
            }
          }
        }
      }
    }

    counts.updateAll((key, value) => value < 0 ? 0 : value);

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: widget.message,
      isOwn: widget.isOwn,
      isPinned: widget.isPinned,
      isSelected: widget.isSelected,
      showMetaOverlay: true,
      showShadow: true,
      onReactionRemoved: widget.onReactionRemoved,
      content: _buildMatchContent(context),
    );
  }

  Widget _buildMatchContent(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final matchDetails =
        _resolvedMatchDetails ?? widget.message.matchDetails ?? {};

    // Extract match information
    final homeTeam = matchDetails['homeTeam'] as Map<String, dynamic>? ?? {};
    final opponentTeam =
        matchDetails['opponentTeam'] as Map<String, dynamic>? ?? {};
    final venue = matchDetails['venue'] as Map<String, dynamic>? ?? {};
    final matchDateTime = matchDetails['dateTime'] != null
        ? DateTime.tryParse(matchDetails['dateTime'].toString())
        : null;

    if (matchDetails.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingMatchDetails)
            _buildLoadingState()
          else if (_matchDetailsError != null)
            _buildErrorState(context, _matchDetailsError!, isDarkMode)
          else if (widget.message.content.isNotEmpty)
            Text(
              widget.message.content,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.87)
                    : Colors.black.withOpacity(0.87),
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTeamsSection(context, homeTeam, opponentTeam),
          SizedBox(height: 18),
          _buildInfoSection(context, matchDateTime, venue),
          SizedBox(height: 18),
          _buildRsvpSummarySection(context, matchDetails),
        ],
      ),
    );
  }

  Widget _buildLoadingState({bool compact = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: compact ? 18 : 24,
          height: compact ? 18 : 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFF4CAF50)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String message,
    bool isDarkMode,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: Colors.redAccent),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode
                  ? Colors.redAccent.shade100
                  : Colors.redAccent.shade400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamsSection(
    BuildContext context,
    Map<String, dynamic> homeTeam,
    Map<String, dynamic> opponentTeam,
  ) {
    // Extract team names with fallbacks
    final homeTeamName =
        homeTeam['name']?.toString() ??
        homeTeam['teamName']?.toString() ??
        'Home Team';
    final opponentTeamName =
        opponentTeam['name']?.toString() ??
        opponentTeam['teamName']?.toString() ??
        'Away Team';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _buildTeamTile(
              context,
              teamName: homeTeamName,
              logoUrl: homeTeam['logo']?.toString(),
            ),
          ),
        ),
        SizedBox(width: 12),
        _buildVsChip(context),
        SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _buildTeamTile(
              context,
              teamName: opponentTeamName,
              logoUrl: opponentTeam['logo']?.toString(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamTile(
    BuildContext context, {
    required String teamName,
    required String? logoUrl,
  }) {
    final displayName = _formatTeamName(teamName);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildTeamLogo(logoUrl),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  String _formatTeamName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'TBD';
    }

    if (trimmed.length <= 20) {
      return trimmed;
    }

    final tokens = trimmed
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.length >= 2) {
      final acronym = tokens.map((token) => token[0]).join().toUpperCase();
      if (acronym.length >= 2) {
        return acronym;
      }
    }

    final condensed = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (condensed.length >= 3) {
      return condensed.substring(0, math.min(3, condensed.length)).toUpperCase();
    }

    return trimmed.substring(0, math.min(20, trimmed.length));
  }

  Widget _buildTeamLogo(String? logoUrl) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 56,
      height: 56,
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SVGAvatar(
                imageUrl: logoUrl,
                size: 56,
                backgroundColor: Colors.transparent,
                iconColor: theme.colorScheme.primary,
                fallbackIcon: Icons.sports_cricket,
                showBorder: false,
                fit: BoxFit.cover,
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.shield_outlined,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ),
    );
  }

  String _formatMatchDateLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Date & time to be announced';
    }

    final local = dateTime.toLocal();
    final day = local.day;
    final suffix = _ordinalSuffix(day);
    final dayPart = '${DateFormat('EEE').format(local)}, $day$suffix ${DateFormat('MMM').format(local)}';
    final timePart = DateFormat('h:mma').format(local).toLowerCase();
    return '$dayPart at $timePart';
  }

  String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _buildVsChip(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'VS',
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    DateTime? matchDateTime,
    Map<String, dynamic> venue,
  ) {
    final venueName = venue['name']?.toString() ?? 'Venue TBD';
    final venueAddress = venue['address']?.toString();
    final venueDisplay = (venueAddress != null &&
            venueAddress.isNotEmpty &&
            venueAddress != venueName)
        ? '$venueName • $venueAddress'
        : venueName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          context,
          icon: Icons.calendar_today,
          label: _formatMatchDateLabel(matchDateTime),
        ),
        SizedBox(height: 8),
        _buildInfoRow(
          context,
          icon: Icons.location_on,
          label: venueDisplay.isNotEmpty ? venueDisplay : 'Venue to be decided',
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ],
    );
  }

  void _handleMatchUpdatePush(Map<String, dynamic> data) {
    if (!mounted) {
      return;
    }

    final matchId = widget.message.matchId;
    if (!_isValidMatchId(matchId)) {
      return;
    }
    final resolvedMatchId = matchId!.trim();

    final incomingMatchId = data['matchId']?.toString();
    if (incomingMatchId != null && incomingMatchId.trim() != resolvedMatchId) {
      return;
    }

    // Re-fetch details to refresh counts and user RSVP status
    _loadMatchDetails();
  }


  Widget _buildRsvpSummarySection(
    BuildContext context,
    Map<String, dynamic> matchDetails,
  ) {
    final counts = _statusCountsFromRaw(matchDetails['statusCounts']) ??
        _extractStatusCounts(matchDetails);

    return Row(
      children: [
        _buildRsvpButton(
          context,
          label: 'In',
          status: 'YES',
          count: counts['YES'] ?? 0,
          color: Color(0xFF4CAF50),
        ),
        SizedBox(width: 8),
        _buildRsvpButton(
          context,
          label: 'Out',
          status: 'NO',
          count: counts['NO'] ?? 0,
          color: Color(0xFFFF5722),
        ),
        SizedBox(width: 8),
        _buildRsvpButton(
          context,
          label: 'Maybe',
          status: 'MAYBE',
          count: counts['MAYBE'] ?? 0,
          color: Color(0xFFFF9800),
        ),
      ],
    );
  }

  Map<String, int>? _statusCountsFromRaw(dynamic raw) {
    if (raw is Map) {
      final normalized = <String, int>{
        'YES': 0,
        'NO': 0,
        'MAYBE': 0,
      };

      raw.forEach((key, value) {
        final upperKey = key.toString().toUpperCase();
        if (normalized.containsKey(upperKey)) {
          if (value is num) {
            normalized[upperKey] = value.toInt();
          } else {
            final parsed = int.tryParse(value.toString());
            if (parsed != null) {
              normalized[upperKey] = parsed;
            }
          }
        }
      });

      normalized.updateAll((key, value) => value < 0 ? 0 : value);
      return normalized;
    }

    return null;
  }

  Widget _buildRsvpButton(
    BuildContext context, {
    required String label,
    required String status,
    required int count,
    required Color color,
  }) {
    final isSelected = _currentRSVPStatus == status;
    final theme = Theme.of(context);
    final backgroundColor = isSelected
        ? color
        : theme.colorScheme.surfaceVariant.withOpacity(
            theme.brightness == Brightness.dark ? 0.4 : 0.7,
          );
    final foregroundColor = isSelected
        ? Colors.white
        : theme.textTheme.labelLarge?.color ?? theme.colorScheme.onSurfaceVariant;
    final displayLabel = _buttonLabel(status, count, label);

    return Expanded(
      child: ElevatedButton(
        onPressed: () => _handleDirectRSVP(context, status),
        style: ElevatedButton.styleFrom(
          elevation: isSelected ? 2 : 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  String _buttonLabel(String status, int count, String fallback) {
    if (count > 0) {
      return '$fallback ($count)';
    }
    return fallback;
  }

  void _handleDirectRSVP(BuildContext context, String status) async {
    final matchId = widget.message.matchId;
    if (!_isValidMatchId(matchId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to RSVP: Match ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final normalizedStatus = status.toUpperCase();
    final previousStatus = _currentRSVPStatus;

    if (previousStatus != null && previousStatus == normalizedStatus) {
      return;
    }

    try {
      final resolvedMatchId = matchId!.trim();
      final response = await MatchService.rsvpToMatch(
        matchId: resolvedMatchId,
        status: normalizedStatus,
      );

      if (!context.mounted) {
        return;
      }

      final isSuccess = response['success'] == true || response['rsvp'] != null;

      if (isSuccess) {
        final updatedDetails = Map<String, dynamic>.from(
          _resolvedMatchDetails ?? widget.message.matchDetails ?? {},
        );

        final updatedUserRsvp = Map<String, dynamic>.from(
          (updatedDetails['userRsvp'] as Map<String, dynamic>?) ?? {},
        );

        final responseRsvp = response['rsvp'];
        if (responseRsvp is Map<String, dynamic>) {
          updatedUserRsvp.addAll(responseRsvp);
        }
        updatedUserRsvp['status'] = normalizedStatus;
        updatedDetails['userRsvp'] = updatedUserRsvp;

        final statusCounts = _statusCountsFromRaw(updatedDetails['statusCounts']) ??
            _extractStatusCounts(updatedDetails);

        if (previousStatus != null && statusCounts.containsKey(previousStatus)) {
          statusCounts[previousStatus] =
              (statusCounts[previousStatus] ?? 1) - 1;
          if ((statusCounts[previousStatus] ?? 0) < 0) {
            statusCounts[previousStatus] = 0;
          }
        }

        if (statusCounts.containsKey(normalizedStatus)) {
          statusCounts[normalizedStatus] =
              (statusCounts[normalizedStatus] ?? 0) + 1;
        }

        updatedDetails['statusCounts'] = statusCounts;

        setState(() {
          _currentRSVPStatus = normalizedStatus;
          _resolvedMatchDetails = updatedDetails;
        });

        widget.onRSVP?.call();

        // Refresh match details to keep venue/time data current
        _loadMatchDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update RSVP. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating RSVP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _unregisterMatchUpdates();
    super.dispose();
  }

  bool _isValidMatchId(String? matchId) {
    if (matchId == null) {
      return false;
    }
    final trimmed = matchId.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.toLowerCase() == 'placeholder_match_id') {
      return false;
    }
    return true;
  }
}
