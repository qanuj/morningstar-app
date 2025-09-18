import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club_message.dart';
import '../../services/match_service.dart';
import '../../services/notification_service.dart';
import '../../services/chat_api_service.dart';
import '../svg_avatar.dart';
import 'base_message_bubble.dart';

/// A specialized message bubble for displaying match and practice announcements
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

  bool get _isPracticeMessage => widget.message.messageType == 'practice';

  /// Get the unified match details (works for both matches and practices)
  Map<String, dynamic> get _getUnifiedMatchDetails {
    return _resolvedMatchDetails ??
        widget.message.matchDetails ??
        widget.message.practiceDetails ??
        {};
  }

  /// Get the unified match ID (works for both matches and practices)
  String? get _getUnifiedMatchId {
    return widget.message.matchId ?? widget.message.practiceId;
  }

  /// Check if this is a practice type based on the match details
  bool _isTypePractice(Map<String, dynamic> details) {
    final type = details['type']?.toString().toUpperCase();
    return type == 'PRACTICE' || widget.message.messageType == 'practice';
  }

  Map<String, dynamic>? _safeMapFromData(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    } else if (value is String && value.isNotEmpty) {
      // For practice messages, venue might be a string
      // Return a map with the string as name
      return {'name': value};
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Initialize RSVP status from message data if available
    _resolvedMatchDetails = _getUnifiedMatchDetails;
    _currentRSVPStatus = _extractRSVPStatus();

    final messageId = _getUnifiedMatchId;
    if (_isValidMatchId(messageId)) {
      _registerForMatchUpdates();
      // Load match details for both matches and practices to get latest cancellation status
      // Even practices need fresh data from the API for cancellation updates
      _loadMatchDetails();
    }
  }

  @override
  void didUpdateWidget(covariant MatchMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldMessageId =
        oldWidget.message.matchId ?? oldWidget.message.practiceId;
    final newMessageId = _getUnifiedMatchId;

    final messageIdChanged = oldMessageId != newMessageId;
    final messageChanged = oldWidget.message.id != widget.message.id;
    final detailsChanged =
        (oldWidget.message.matchDetails ?? oldWidget.message.practiceDetails) !=
        _getUnifiedMatchDetails;

    if (messageIdChanged || messageChanged || detailsChanged) {
      _resolvedMatchDetails = _getUnifiedMatchDetails;
      _currentRSVPStatus = _extractRSVPStatus();
      _matchDetailsError = null;

      if (messageIdChanged) {
        _unregisterMatchUpdates(oldMessageId);
        if (_isValidMatchId(newMessageId)) {
          _registerForMatchUpdates();
          // Load details for both matches and practices
          _loadMatchDetails();
        }
      } else if (_isValidMatchId(newMessageId)) {
        // Refresh details if message changed (for both matches and practices)
        _loadMatchDetails();
      }
    }
  }

  String? _extractRSVPStatus() {
    // Try to extract RSVP status from details if available
    final details = _getUnifiedMatchDetails;
    if (details.isNotEmpty && details['userRsvp'] != null) {
      final status = details['userRsvp']['status'];
      if (status is String && status.isNotEmpty) {
        return status.toUpperCase();
      }
    }
    // For practice messages, do not auto-join based on isJoined flag
    // User must explicitly select their RSVP status
    return null;
  }

  Future<void> _loadMatchDetails() async {
    if (_isLoadingMatchDetails) return;

    final matchId = _getUnifiedMatchId;
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

    // Debug logging for specific match ID
    if (resolvedMatchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
      print(
        '🔄 DEBUG - Loading match details for cancelled match: $resolvedMatchId',
      );
    }

    try {
      detailedMatch = await MatchService.getMatchDetail(resolvedMatchId);
      if (detailedMatch != null && detailedMatch.isEmpty) {
        detailedMatch = null;
      }

      // Debug logging for specific match ID
      if (resolvedMatchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
        print('🔄 DEBUG - getMatchDetail response: $detailedMatch');
        print(
          '🔄 DEBUG - isCancelled in detailed match: ${detailedMatch?['isCancelled']}',
        );
      }
    } catch (e) {
      debugPrint('❌ MatchMessageBubble: error fetching match detail: $e');
    }

    try {
      clubMatch = await MatchService.getClubMatch(
        clubId: widget.message.clubId,
        matchId: resolvedMatchId,
      );

      // Debug logging for specific match ID
      if (resolvedMatchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
        print('🔄 DEBUG - getClubMatch response: $clubMatch');
        print(
          '🔄 DEBUG - isCancelled in club match: ${clubMatch?['isCancelled']}',
        );
      }
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

    // Debug logging for specific match ID
    if (resolvedMatchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
      print('🔄 DEBUG - About to merge details');
      print('🔄 DEBUG - detailedMatch isCancelled: ${detailedMatch?['isCancelled']}');
      print('🔄 DEBUG - clubMatch isCancelled: ${clubMatch?['isCancelled']}');
      print('🔄 DEBUG - Merged isCancelled: ${mergedDetails['isCancelled']}');
      print('🔄 DEBUG - Merged cancellationReason: ${mergedDetails['cancellationReason']}');
    }

    setState(() {
      _resolvedMatchDetails = mergedDetails;
      final status = _safeMapFromData(mergedDetails['userRsvp'])?['status'];
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
      _resolvedMatchDetails ??
          widget.message.matchDetails ??
          <String, dynamic>{},
    );
    final existingHome = _safeMapFromData(existing['homeTeam']) ?? {};
    final existingOpponent = _safeMapFromData(existing['opponentTeam']) ?? {};
    final existingVenue = _safeMapFromData(existing['venue']) ?? {};

    final detailTeam = _safeMapFromData(detail?['team']);
    final detailOpponentTeam = _safeMapFromData(detail?['opponentTeam']);
    final clubMatchTeam = _safeMapFromData(clubMatch?['team']);
    final clubMatchOpponent = _safeMapFromData(clubMatch?['opponentTeam']);

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

    final matchDateIso =
        asString(detail?['matchDate']) ??
        asString(clubMatch?['matchDate']) ??
        asString(existing['dateTime']);

    final venueName =
        asString(clubMatch?['location']) ??
        asString(detail?['location']) ??
        asString(existingVenue['name']) ??
        'Venue TBD';

    String? venueAddress = asString(existingVenue['address']);
    final detailCity = asString(detail?['city']);
    if ((venueAddress == null || venueAddress == venueName) &&
        detailCity != null &&
        detailCity.isNotEmpty) {
      venueAddress = detailCity;
    }

    final userRsvp =
        _safeMapFromData(detail?['userRsvp']) ??
        _safeMapFromData(clubMatch?['userRsvp']) ??
        _safeMapFromData(existing['userRsvp']);

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

    // Preserve cancellation status from both sources (prioritize detail over clubMatch)
    final isCancelled = detail?['isCancelled'] ?? clubMatch?['isCancelled'];
    if (isCancelled != null) {
      result['isCancelled'] = isCancelled;
    }

    final cancellationReason = detail?['cancellationReason'] ?? clubMatch?['cancellationReason'];
    if (cancellationReason != null) {
      result['cancellationReason'] = cancellationReason;
    }

    result['statusCounts'] = _extractStatusCounts(result);

    print('🔄 DEBUG - Final result isCancelled: ${result['isCancelled']}');
    print('🔄 DEBUG - Final result cancellationReason: ${result['cancellationReason']}');

    return result;
  }

  void _registerForMatchUpdates() {
    final messageId = _getUnifiedMatchId;
    if (!_isValidMatchId(messageId)) {
      return;
    }

    if (_registeredMatchId == messageId) {
      return;
    }

    final resolvedMessageId = messageId!.trim();
    NotificationService.addMatchUpdateCallback(
      resolvedMessageId,
      _handleMatchUpdatePush,
    );
    _registeredMatchId = resolvedMessageId;
  }

  void _unregisterMatchUpdates([String? matchId]) {
    final targetMatchId = matchId ?? _registeredMatchId;
    if (targetMatchId == null) {
      return;
    }

    final resolvedTarget = targetMatchId.trim();
    NotificationService.removeMatchUpdateCallback(
      resolvedTarget,
      _handleMatchUpdatePush,
    );
    if (resolvedTarget == _registeredMatchId) {
      _registeredMatchId = null;
    }
  }

  Map<String, int> _extractStatusCounts(Map<String, dynamic> details) {
    final counts = <String, int>{'YES': 0, 'NO': 0, 'MAYBE': 0};

    final aggregate = details['counts'];
    if (aggregate is Map<String, dynamic>) {
      counts['YES'] =
          ((aggregate['confirmed'] as num?)?.toInt() ?? 0) +
          ((aggregate['waitlisted'] as num?)?.toInt() ?? 0);
      counts['NO'] = (aggregate['declined'] as num?)?.toInt() ?? 0;
      counts['MAYBE'] = (aggregate['maybe'] as num?)?.toInt() ?? 0;
    }

    if (counts.values.every((value) => value == 0)) {
      final rsvps = details['rsvps'];
      if (rsvps is List) {
        for (final rsvp in rsvps) {
          if (rsvp is Map<String, dynamic>) {
            final status = (rsvp['status']?.toString().toUpperCase() ?? '')
                .trim();
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
    final matchDetails = _getUnifiedMatchDetails;

    // Check for cancellation status
    final isCancelled = _getCancellationStatus(matchDetails);
    final cancellationReason = _getCancellationReason(matchDetails);
    final isPractice = _isTypePractice(matchDetails);

    // Extract match information
    final homeTeam = _safeMapFromData(matchDetails['homeTeam']) ?? {};
    final opponentTeam = _safeMapFromData(matchDetails['opponentTeam']) ?? {};
    final venue = _safeMapFromData(matchDetails['venue']) ?? {};
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
      child: isCancelled
          ? _buildCancelledCard(context, matchDetails, cancellationReason, isPractice)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isPractice) ...[
                  _buildTeamsSection(
                    context,
                    homeTeam,
                    opponentTeam,
                    isCancelled: isCancelled,
                  ),
                  SizedBox(height: 18),
                ],
                if (isPractice) _buildPracticeHeader(context, isCancelled),
                _buildInfoSection(
                  context,
                  matchDateTime,
                  venue,
                  isCancelled: isCancelled,
                ),
                SizedBox(height: 18),
                _buildRsvpSummarySection(
                  context,
                  matchDetails,
                  isCancelled: isCancelled,
                ),
              ],
            ),
    );
  }

  Widget _buildCancelledCard(
    BuildContext context,
    Map<String, dynamic> matchDetails,
    String? cancellationReason,
    bool isPractice,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final venue = _safeMapFromData(matchDetails['venue']) ?? {};
    final venueName = venue['name']?.toString() ?? 'Venue TBD';

    final matchDateTime = matchDetails['dateTime'] != null
        ? DateTime.tryParse(matchDetails['dateTime'].toString())
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cancellation header
          Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: Colors.red,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'CANCELLED',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              Text(
                isPractice ? 'Practice' : 'Match',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Basic info
          if (!isPractice) ...[
            // Match teams (minimal)
            Builder(
              builder: (context) {
                final homeTeam = _safeMapFromData(matchDetails['homeTeam']) ?? {};
                final opponentTeam = _safeMapFromData(matchDetails['opponentTeam']) ?? {};
                return Text(
                  '${homeTeam['name'] ?? 'Home Team'} vs ${opponentTeam['name'] ?? 'Opponent Team'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.red.withOpacity(0.6),
                  ),
                );
              },
            ),
          ] else ...[
            // Practice title
            Text(
              'Practice Session',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.black87,
                decoration: TextDecoration.lineThrough,
                decorationColor: Colors.red.withOpacity(0.6),
              ),
            ),
          ],

          SizedBox(height: 8),

          // Date and venue (compact)
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
              SizedBox(width: 4),
              Text(
                matchDateTime != null
                    ? _formatMatchDateLabel(matchDateTime)
                    : 'Date TBD',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
              ),
              SizedBox(width: 16),
              Icon(
                Icons.location_on,
                size: 14,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  venueName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Cancellation reason
          if (cancellationReason != null && cancellationReason.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reason: $cancellationReason',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPracticeHeader(
    BuildContext context, [
    bool isCancelled = false,
  ]) {
    return Column(
      children: [
        Text(
          "Practice Session",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isCancelled
                ? Colors.grey.shade500
                : Theme.of(context).colorScheme.primary,
            decoration: isCancelled ? TextDecoration.lineThrough : null,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 18),
      ],
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
    Map<String, dynamic> opponentTeam, {
    bool isCancelled = false,
  }) {
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
              isCancelled: isCancelled,
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
              isCancelled: isCancelled,
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
    bool isCancelled = false,
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
              color: isCancelled
                  ? Colors.grey.shade500
                  : Theme.of(context).textTheme.titleMedium?.color,
              decoration: isCancelled ? TextDecoration.lineThrough : null,
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
      return condensed
          .substring(0, math.min(3, condensed.length))
          .toUpperCase();
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
    final dayPart =
        '${DateFormat('EEE').format(local)}, $day$suffix ${DateFormat('MMM').format(local)}';
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
    Map<String, dynamic> venue, {
    bool isCancelled = false,
  }) {
    final details = _getUnifiedMatchDetails;
    final isPractice = _isTypePractice(details);

    if (isPractice) {
      return _buildPracticeInfoSection(
        context,
        details,
        isCancelled: isCancelled,
      );
    }

    final venueName = venue['name']?.toString() ?? 'Venue TBD';
    final venueAddress = venue['address']?.toString();
    final venueDisplay =
        (venueAddress != null &&
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
          isCancelled: isCancelled,
        ),
        SizedBox(height: 8),
        _buildInfoRow(
          context,
          icon: Icons.location_on,
          label: venueDisplay.isNotEmpty ? venueDisplay : 'Venue to be decided',
          isCancelled: isCancelled,
        ),
      ],
    );
  }

  Widget _buildPracticeInfoSection(
    BuildContext context,
    Map<String, dynamic> details, {
    bool isCancelled = false,
  }) {
    final date = details['date']?.toString() ?? '';
    final time = details['time']?.toString() ?? '';

    // Extract venue name properly from venue object
    final venueMap = _safeMapFromData(details['venue']);
    final venue = venueMap?['name']?.toString() ??
                  details['venue']?.toString() ?? '';

    final duration = details['duration']?.toString() ?? '';
    final maxParticipants = details['maxParticipants'] as int? ?? 0;
    final confirmedPlayers = details['confirmedPlayers'] as int? ?? 0;

    // Combine date and time for proper DateTime parsing
    DateTime? practiceDateTime;
    if (date.isNotEmpty && time.isNotEmpty) {
      try {
        practiceDateTime = DateTime.parse('${date}T$time:00');
      } catch (e) {
        practiceDateTime = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (practiceDateTime != null)
          _buildInfoRow(
            context,
            icon: Icons.calendar_today,
            label: _formatPracticeDateLabel(practiceDateTime, duration),
            isCancelled: isCancelled,
          ),
        if (practiceDateTime != null) SizedBox(height: 8),
        if (venue.isNotEmpty)
          _buildInfoRow(
            context,
            icon: Icons.location_on,
            label: venue,
            isCancelled: isCancelled,
          ),
        if (venue.isNotEmpty) SizedBox(height: 8),
        if (maxParticipants > 0) ...[
          _buildInfoRow(
            context,
            icon: Icons.group,
            label: '$confirmedPlayers/$maxParticipants participants',
            isCancelled: isCancelled,
          ),
          SizedBox(height: 8),
          _buildProgressBar(confirmedPlayers, maxParticipants),
          SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildProgressBar(int current, int max) {
    if (max <= 0) return SizedBox.shrink();

    final progress = current / max;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available spots',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            Text(
              '${max - current} remaining',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.dividerColor,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          minHeight: 6,
        ),
      ],
    );
  }

  String _formatPracticeDateLabel(DateTime? dateTime, String duration) {
    if (dateTime == null) {
      return 'Date & time to be announced';
    }

    final local = dateTime.toLocal();
    final day = local.day;
    final suffix = _ordinalSuffix(day);
    final dayPart =
        '${DateFormat('EEE').format(local)}, $day$suffix ${DateFormat('MMM').format(local)}';
    final timePart = DateFormat('h:mma').format(local).toLowerCase();

    String result = '$dayPart at $timePart';

    if (duration.isNotEmpty) {
      // Try to calculate end time from duration
      final endTime = _calculateEndTime(dateTime, duration);
      if (endTime != null) {
        result += ' to ${DateFormat('h:mma').format(endTime).toLowerCase()}';
      } else {
        result += ' • $duration';
      }
    }

    return result;
  }

  DateTime? _calculateEndTime(DateTime startTime, String duration) {
    try {
      final durationText = duration.toLowerCase().trim();

      // Handle "2 hours", "90 minutes", "1.5 hours" etc.
      final hoursMatch = RegExp(
        r'(\d+(?:\.\d+)?)\s*(?:hour|hr)s?',
      ).firstMatch(durationText);
      final minutesMatch = RegExp(
        r'(\d+)\s*(?:minute|min)s?',
      ).firstMatch(durationText);

      if (hoursMatch != null) {
        final hours = double.parse(hoursMatch.group(1)!);
        return startTime.add(Duration(minutes: (hours * 60).round()));
      } else if (minutesMatch != null) {
        final minutes = int.parse(minutesMatch.group(1)!);
        return startTime.add(Duration(minutes: minutes));
      }
    } catch (e) {
      // If parsing fails, return null to fallback to showing duration text
    }
    return null;
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isCancelled = false,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: isCancelled ? Colors.grey.shade500 : theme.colorScheme.primary,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isCancelled
                  ? Colors.grey.shade500
                  : theme.textTheme.bodyLarge?.color,
              decoration: isCancelled ? TextDecoration.lineThrough : null,
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
    Map<String, dynamic> matchDetails, {
    bool isCancelled = false,
  }) {
    final counts =
        _statusCountsFromRaw(matchDetails['statusCounts']) ??
        _extractStatusCounts(matchDetails);

    // Show cancellation message instead of RSVP buttons if cancelled
    if (isCancelled) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'RSVP not available for cancelled ${_isTypePractice(_getUnifiedMatchDetails) ? 'practice' : 'match'}',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Row(
      children: [
        _buildRsvpButton(
          context,
          label: 'In',
          status: 'YES',
          count: counts['YES'] ?? 0,
          color: Color(0xFF4CAF50),
          isDisabled: isCancelled,
        ),
        SizedBox(width: 8),
        _buildRsvpButton(
          context,
          label: 'Out',
          status: 'NO',
          count: counts['NO'] ?? 0,
          color: Color(0xFFFF5722),
          isDisabled: isCancelled,
        ),
        SizedBox(width: 8),
        _buildRsvpButton(
          context,
          label: 'Maybe',
          status: 'MAYBE',
          count: counts['MAYBE'] ?? 0,
          color: Color(0xFFFF9800),
          isDisabled: isCancelled,
        ),
      ],
    );
  }

  Map<String, int>? _statusCountsFromRaw(dynamic raw) {
    if (raw is Map) {
      final normalized = <String, int>{'YES': 0, 'NO': 0, 'MAYBE': 0};

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
    bool isDisabled = false,
  }) {
    final isSelected = _currentRSVPStatus == status;
    final theme = Theme.of(context);
    final backgroundColor = isDisabled
        ? Colors.grey.shade300
        : isSelected
        ? color
        : theme.colorScheme.surfaceVariant.withOpacity(
            theme.brightness == Brightness.dark ? 0.4 : 0.7,
          );
    final foregroundColor = isDisabled
        ? Colors.grey.shade500
        : isSelected
        ? Colors.white
        : theme.textTheme.labelLarge?.color ??
              theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: Stack(
        children: [
          ElevatedButton(
            onPressed: isDisabled
                ? null
                : () => _handleDirectRSVP(context, status),
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
              label,
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4),
            ),
          ),
          if (count > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: count > 99 ? 6 : 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : Colors.white,
                    width: 1.5,
                  ),
                ),
                constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    color: isSelected ? color : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleDirectRSVP(BuildContext context, String status) async {
    final messageId = _getUnifiedMatchId;
    final isPractice = _isTypePractice(_getUnifiedMatchDetails);

    if (!_isValidMatchId(messageId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to RSVP: ${isPractice ? 'Practice' : 'Match'} ID not found',
          ),
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
      final resolvedMessageId = messageId!.trim();

      bool isSuccess = false;
      Map<String, dynamic> response = {};

      // Use unified MatchService for both matches and practices
      // since they're the same underlying model with different types
      if (isPractice) {
        print(
          '🏃 Practice RSVP: matchId=$resolvedMessageId, status=$normalizedStatus',
        );
      }

      response = await MatchService.rsvpToMatch(
        matchId: resolvedMessageId,
        status: normalizedStatus,
      );
      isSuccess = response['success'] == true || response['rsvp'] != null;

      if (isPractice) {
        print(
          '🏃 Practice RSVP result: success=$isSuccess, response=$response',
        );
      }

      if (!context.mounted) {
        return;
      }

      if (isSuccess) {
        final currentDetails = _getUnifiedMatchDetails;

        final updatedDetails = Map<String, dynamic>.from(
          _resolvedMatchDetails ?? currentDetails ?? {},
        );

        final updatedUserRsvp = Map<String, dynamic>.from(
          _safeMapFromData(updatedDetails['userRsvp']) ?? {},
        );

        if (!isPractice) {
          final responseRsvp = response['rsvp'];
          if (responseRsvp is Map<String, dynamic>) {
            updatedUserRsvp.addAll(responseRsvp);
          }
        }
        updatedUserRsvp['status'] = normalizedStatus;
        updatedDetails['userRsvp'] = updatedUserRsvp;

        // Update counts for practice messages
        if (isPractice) {
          final confirmedPlayers =
              updatedDetails['confirmedPlayers'] as int? ?? 0;
          if (previousStatus == null && normalizedStatus == 'YES') {
            updatedDetails['confirmedPlayers'] = confirmedPlayers + 1;
          } else if (previousStatus == 'YES' && normalizedStatus != 'YES') {
            updatedDetails['confirmedPlayers'] = math.max(
              0,
              confirmedPlayers - 1,
            );
          } else if (previousStatus != 'YES' && normalizedStatus == 'YES') {
            updatedDetails['confirmedPlayers'] = confirmedPlayers + 1;
          }
        } else {
          // Update status counts for match messages
          final statusCounts =
              _statusCountsFromRaw(updatedDetails['statusCounts']) ??
              _extractStatusCounts(updatedDetails);

          if (previousStatus != null &&
              statusCounts.containsKey(previousStatus)) {
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
        }

        setState(() {
          _currentRSVPStatus = normalizedStatus;
          _resolvedMatchDetails = updatedDetails;
        });

        widget.onRSVP?.call();

        // Refresh match details to keep venue/time data current (matches only)
        if (!isPractice) {
          _loadMatchDetails();
        }
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

  /// Check if the match/practice is cancelled
  bool _getCancellationStatus(Map<String, dynamic> details) {
    final matchId = _getUnifiedMatchId;

    // Debug logging for specific match ID
    if (matchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
      print('🚫 DEBUG - Checking cancellation for match ID: $matchId');
      print('🚫 DEBUG - isCancelled value: ${details['isCancelled']}');
      print(
        '🚫 DEBUG - isCancelled type: ${details['isCancelled'].runtimeType}',
      );
    }

    // Check for cancellation in practice or match details
    if (details['isCancelled'] == true) {
      if (matchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
        print('🚫 DEBUG - Found cancellation in main details');
      }
      return true;
    }

    // Also check in nested data structures
    if (details['practice'] != null &&
        details['practice']['isCancelled'] == true) {
      if (matchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
        print('🚫 DEBUG - Found cancellation in practice details');
      }
      return true;
    }

    if (details['match'] != null && details['match']['isCancelled'] == true) {
      if (matchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
        print('🚫 DEBUG - Found cancellation in match details');
      }
      return true;
    }

    if (matchId == 'cmfpk03gx008q6v3mfd6c3kbj') {
      print('🚫 DEBUG - No cancellation found for this match');
    }

    return false;
  }

  /// Get cancellation reason if available
  String? _getCancellationReason(Map<String, dynamic> details) {
    // Check for cancellation reason in various locations
    if (details['cancellationReason'] is String &&
        details['cancellationReason'].toString().isNotEmpty) {
      return details['cancellationReason'].toString();
    }

    if (details['practice'] != null &&
        details['practice']['cancellationReason'] is String) {
      return details['practice']['cancellationReason'].toString();
    }

    if (details['match'] != null &&
        details['match']['cancellationReason'] is String) {
      return details['match']['cancellationReason'].toString();
    }

    return null;
  }

  /// Build cancellation banner
  Widget _buildCancellationBanner(BuildContext context, String? reason) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red.shade600, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTypePractice(_getUnifiedMatchDetails)
                      ? 'Practice Cancelled'
                      : 'Match Cancelled',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    reason,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
