import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club_message.dart';
import '../../services/match_service.dart';
import '../../services/notification_service.dart';
import '../../services/message_storage_service.dart';
import '../svg_avatar.dart';
import 'base_message_bubble.dart';

/// A cached match message bubble that uses local data and only updates via push notifications
/// No unnecessary API calls - all data comes from the message content
class CachedMatchMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final Function(String messageId, String emoji, String userId)? onReactionRemoved;
  final Function()? onViewMatch;
  final Function()? onRSVP;

  const CachedMatchMessageBubble({
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
  State<CachedMatchMessageBubble> createState() => _CachedMatchMessageBubbleState();
}

class _CachedMatchMessageBubbleState extends State<CachedMatchMessageBubble> {
  String? _currentRSVPStatus;
  Map<String, dynamic> _cachedMatchDetails = {};
  String? _registeredMatchId;

  bool get _isPracticeMessage => widget.message.messageType == 'practice';

  /// Get the unified match details from cached data only
  Map<String, dynamic> get _getUnifiedMatchDetails {
    return _cachedMatchDetails.isNotEmpty
        ? _cachedMatchDetails
        : widget.message.meta ?? {};
  }

  /// Get the unified match ID
  String? get _getUnifiedMatchId {
    return widget.message.matchId ?? widget.message.practiceId;
  }

  /// Check if this is a practice type
  bool _isTypePractice(Map<String, dynamic> details) {
    final type = details['type']?.toString().toUpperCase();
    return type == 'PRACTICE' || widget.message.messageType == 'practice';
  }

  Map<String, dynamic>? _safeMapFromData(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    } else if (value is String && value.isNotEmpty) {
      return {'name': value};
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Initialize from cached message data only
    _cachedMatchDetails = _getUnifiedMatchDetails;
    _currentRSVPStatus = _extractRSVPStatus();

    // Register for push notification updates only
    final matchId = _getUnifiedMatchId;
    if (_isValidMatchId(matchId)) {
      _registerForMatchUpdates();
    }
  }

  @override
  void didUpdateWidget(covariant CachedMatchMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldMessageId = oldWidget.message.matchId ?? oldWidget.message.practiceId;
    final newMessageId = _getUnifiedMatchId;

    final messageIdChanged = oldMessageId != newMessageId;
    final messageChanged = oldWidget.message.id != widget.message.id;
    final detailsChanged = oldWidget.message.meta != _getUnifiedMatchDetails;

    if (messageIdChanged || messageChanged || detailsChanged) {
      // Update cached data from new message
      _cachedMatchDetails = _getUnifiedMatchDetails;
      _currentRSVPStatus = _extractRSVPStatus();

      if (messageIdChanged) {
        _unregisterMatchUpdates(oldMessageId);
        if (_isValidMatchId(newMessageId)) {
          _registerForMatchUpdates();
        }
      }
    }
  }

  String? _extractRSVPStatus() {
    final details = _getUnifiedMatchDetails;
    if (details.isNotEmpty && details['userRsvp'] != null) {
      final status = details['userRsvp']['status'];
      if (status is String && status.isNotEmpty) {
        return status.toUpperCase();
      }
    }
    return null;
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

  /// Handle push notification updates for match/practice changes
  void _handleMatchUpdatePush(Map<String, dynamic> data) async {
    if (!mounted) return;

    final matchId = _getUnifiedMatchId;
    if (!_isValidMatchId(matchId)) return;

    final resolvedMatchId = matchId!.trim();
    final incomingMatchId = data['matchId']?.toString();

    if (incomingMatchId != null && incomingMatchId.trim() != resolvedMatchId) {
      return;
    }

    debugPrint('📲 Received match update push notification for $resolvedMatchId');

    // Update local cached data from push notification
    final updatedDetails = Map<String, dynamic>.from(_cachedMatchDetails);

    // Update fields that can change via push notifications
    if (data['isCancelled'] != null) {
      updatedDetails['isCancelled'] = data['isCancelled'];
    }

    if (data['cancellationReason'] != null) {
      updatedDetails['cancellationReason'] = data['cancellationReason'];
    }

    if (data['dateTime'] != null) {
      updatedDetails['dateTime'] = data['dateTime'];
    }

    if (data['venue'] != null) {
      updatedDetails['venue'] = data['venue'];
    }

    if (data['counts'] != null) {
      updatedDetails['counts'] = data['counts'];
    }

    // Update RSVP status if included
    if (data['userRsvp'] != null) {
      updatedDetails['userRsvp'] = data['userRsvp'];
    }

    setState(() {
      _cachedMatchDetails = updatedDetails;
      _currentRSVPStatus = _extractRSVPStatus();
    });

    // Update the message in local storage with new details
    await _updateMessageInCache(updatedDetails);

    debugPrint('✅ Updated cached match details from push notification');
  }

  /// Update the message in local cache with new details
  Future<void> _updateMessageInCache(Map<String, dynamic> updatedDetails) async {
    try {
      // Load current messages from cache
      final messages = await MessageStorageService.loadMessages(widget.message.clubId);

      // Find and update the specific message
      final messageIndex = messages.indexWhere((m) => m.id == widget.message.id);
      if (messageIndex != -1) {
        final updatedMessage = widget.message.copyWith(
          meta: updatedDetails,
        );

        messages[messageIndex] = updatedMessage;

        // Save back to cache
        await MessageStorageService.saveMessages(widget.message.clubId, messages);
        debugPrint('💾 Updated message cache with new match details');
      }
    } catch (e) {
      debugPrint('❌ Error updating message cache: $e');
    }
  }

  Map<String, int> _extractStatusCounts(Map<String, dynamic> details) {
    final counts = <String, int>{'YES': 0, 'NO': 0, 'MAYBE': 0};

    // Try the new unified meta fields first
    if (details['confirmedPlayers'] != null || details['availableSpots'] != null) {
      final confirmedPlayers = (details['confirmedPlayers'] as num?)?.toInt() ?? 0;
      final availableSpots = (details['availableSpots'] as num?)?.toInt() ?? 0;

      counts['YES'] = confirmedPlayers;
      // For spots and other counts, we don't have detailed breakdown from match data
      // so we'll show what we have
      return counts;
    }

    // Fallback to old field structure
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
            final status = (rsvp['status']?.toString().toUpperCase() ?? '').trim();
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
    final homeTeam = _safeMapFromData(matchDetails['homeTeam'] ?? matchDetails['team']) ?? {};
    final opponentTeam = _safeMapFromData(matchDetails['opponentTeam']) ?? {};
    final venue = _safeMapFromData(matchDetails['venue']) ?? (matchDetails['location'] != null ? {'name': matchDetails['location']} : {});
    final matchDateTime = matchDetails['dateTime'] != null
        ? DateTime.tryParse(matchDetails['dateTime'].toString())
        : (matchDetails['matchDate'] != null
            ? DateTime.tryParse(matchDetails['matchDate'].toString())
            : null);

    if (matchDetails.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          widget.message.content.isNotEmpty
              ? widget.message.content
              : 'Match details not available',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white.withOpacity(0.87) : Colors.black.withOpacity(0.87),
          ),
        ),
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
                  _buildTeamsSection(context, homeTeam, opponentTeam, isCancelled: isCancelled),
                  SizedBox(height: 18),
                ],
                if (isPractice) _buildPracticeHeader(context, isCancelled),
                _buildInfoSection(context, matchDateTime, venue, isCancelled: isCancelled),
                SizedBox(height: 18),
                _buildRsvpSummarySection(context, matchDetails, isCancelled: isCancelled),
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
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cancellation header
          Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
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
              Icon(Icons.schedule, size: 14, color: isDarkMode ? Colors.white54 : Colors.black54),
              SizedBox(width: 4),
              Text(
                matchDateTime != null ? _formatMatchDateLabel(matchDateTime) : 'Date TBD',
                style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54),
              ),
              SizedBox(width: 16),
              Icon(Icons.location_on, size: 14, color: isDarkMode ? Colors.white54 : Colors.black54),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  venueName,
                  style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54),
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

  Widget _buildPracticeHeader(BuildContext context, [bool isCancelled = false]) {
    return Column(
      children: [
        Text(
          "Practice Session",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isCancelled ? Colors.grey.shade500 : Theme.of(context).colorScheme.primary,
            decoration: isCancelled ? TextDecoration.lineThrough : null,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 18),
      ],
    );
  }

  Widget _buildTeamsSection(
    BuildContext context,
    Map<String, dynamic> homeTeam,
    Map<String, dynamic> opponentTeam, {
    bool isCancelled = false,
  }) {
    final homeTeamName = homeTeam['name']?.toString() ?? homeTeam['teamName']?.toString() ?? 'Home Team';
    final opponentTeamName = opponentTeam['name']?.toString() ?? opponentTeam['teamName']?.toString() ?? 'Away Team';

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
              color: isCancelled ? Colors.grey.shade500 : Theme.of(context).textTheme.titleMedium?.color,
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
    if (trimmed.isEmpty) return 'TBD';
    if (trimmed.length <= 20) return trimmed;

    final tokens = trimmed.split(RegExp(r'[^A-Za-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.length >= 2) {
      final acronym = tokens.map((token) => token[0]).join().toUpperCase();
      if (acronym.length >= 2) return acronym;
    }

    final condensed = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (condensed.length >= 3) {
      return condensed.substring(0, math.min(3, condensed.length)).toUpperCase();
    }

    return trimmed.substring(0, math.min(20, trimmed.length));
  }

  Widget _buildTeamLogo(String? logoUrl) {
    return SizedBox(
      width: 56,
      height: 56,
      child: logoUrl != null && logoUrl.isNotEmpty
          ? SVGAvatar(
              imageUrl: logoUrl,
              size: 56,
              fallbackText: '',
            )
          : Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.shield_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
    );
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
      return _buildPracticeInfoSection(context, details, isCancelled: isCancelled);
    }

    final venueName = venue['name']?.toString() ?? 'Venue TBD';
    final venueAddress = venue['address']?.toString();
    final venueDisplay = (venueAddress != null && venueAddress.isNotEmpty && venueAddress != venueName)
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

    final venueMap = _safeMapFromData(details['venue']);
    final venue = venueMap?['name']?.toString() ?? details['venue']?.toString() ?? '';

    final duration = details['duration']?.toString() ?? '';
    final maxParticipants = details['maxParticipants'] as int? ?? 0;
    final confirmedPlayers = details['confirmedPlayers'] as int? ?? 0;

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
              style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
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
    if (dateTime == null) return 'Date & time to be announced';

    final local = dateTime.toLocal();
    final day = local.day;
    final suffix = _ordinalSuffix(day);
    final dayPart = '${DateFormat('EEE').format(local)}, $day$suffix ${DateFormat('MMM').format(local)}';
    final timePart = DateFormat('h:mma').format(local).toLowerCase();

    String result = '$dayPart at $timePart';

    if (duration.isNotEmpty) {
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

      final hoursMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hour|hr)s?').firstMatch(durationText);
      final minutesMatch = RegExp(r'(\d+)\s*(?:minute|min)s?').firstMatch(durationText);

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
              color: isCancelled ? Colors.grey.shade500 : theme.textTheme.bodyLarge?.color,
              decoration: isCancelled ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMatchDateLabel(DateTime? dateTime) {
    if (dateTime == null) return 'Date & time to be announced';

    final local = dateTime.toLocal();
    final day = local.day;
    final suffix = _ordinalSuffix(day);
    final dayPart = '${DateFormat('EEE').format(local)}, $day$suffix ${DateFormat('MMM').format(local)}';
    final timePart = DateFormat('h:mma').format(local).toLowerCase();
    return '$dayPart at $timePart';
  }

  String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildRsvpSummarySection(
    BuildContext context,
    Map<String, dynamic> matchDetails, {
    bool isCancelled = false,
  }) {
    final counts = _statusCountsFromRaw(matchDetails['statusCounts']) ?? _extractStatusCounts(matchDetails);

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
        Expanded(
          flex: 5, // 50% of the width
          child: _buildRsvpButton(
            context,
            label: 'In',
            status: 'YES',
            count: counts['YES'] ?? 0,
            color: Color(0xFF4CAF50),
            isDisabled: isCancelled,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          flex: 3, // 30% of the width
          child: _buildRsvpButton(
            context,
            label: 'Out',
            status: 'NO',
            count: counts['NO'] ?? 0,
            color: Color(0xFFFF5722),
            isDisabled: isCancelled,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          flex: 2, // 20% of the width
          child: _buildRsvpButton(
            context,
            label: 'Maybe',
            status: 'MAYBE',
            count: counts['MAYBE'] ?? 0,
            color: Color(0xFFFF9800),
            isDisabled: isCancelled,
          ),
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
            : theme.textTheme.labelLarge?.color ?? theme.colorScheme.onSurfaceVariant;

    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isDisabled ? null : () => _handleDirectRSVP(context, status),
            style: ElevatedButton.styleFrom(
              elevation: isSelected ? 2 : 0,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4),
            ),
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
    );
  }

  void _handleDirectRSVP(BuildContext context, String status) async {
    final messageId = _getUnifiedMatchId;
    final isPractice = _isTypePractice(_getUnifiedMatchDetails);

    if (!_isValidMatchId(messageId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to RSVP: ${isPractice ? 'Practice' : 'Match'} ID not found'),
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

      // Make RSVP API call
      final response = await MatchService.rsvpToMatch(
        matchId: resolvedMessageId,
        status: normalizedStatus,
      );
      final isSuccess = response['success'] == true || response['rsvp'] != null;

      if (!context.mounted) return;

      if (isSuccess) {
        // Update local cached data optimistically
        final updatedDetails = Map<String, dynamic>.from(_cachedMatchDetails);
        final updatedUserRsvp = Map<String, dynamic>.from(
          _safeMapFromData(updatedDetails['userRsvp']) ?? {},
        );

        updatedUserRsvp['status'] = normalizedStatus;
        updatedDetails['userRsvp'] = updatedUserRsvp;

        // Update counts locally
        if (isPractice) {
          final confirmedPlayers = updatedDetails['confirmedPlayers'] as int? ?? 0;
          if (previousStatus == null && normalizedStatus == 'YES') {
            updatedDetails['confirmedPlayers'] = confirmedPlayers + 1;
          } else if (previousStatus == 'YES' && normalizedStatus != 'YES') {
            updatedDetails['confirmedPlayers'] = math.max(0, confirmedPlayers - 1);
          } else if (previousStatus != 'YES' && normalizedStatus == 'YES') {
            updatedDetails['confirmedPlayers'] = confirmedPlayers + 1;
          }
        } else {
          final statusCounts = _statusCountsFromRaw(updatedDetails['statusCounts']) ?? _extractStatusCounts(updatedDetails);

          if (previousStatus != null && statusCounts.containsKey(previousStatus)) {
            statusCounts[previousStatus] = (statusCounts[previousStatus] ?? 1) - 1;
            if ((statusCounts[previousStatus] ?? 0) < 0) {
              statusCounts[previousStatus] = 0;
            }
          }

          if (statusCounts.containsKey(normalizedStatus)) {
            statusCounts[normalizedStatus] = (statusCounts[normalizedStatus] ?? 0) + 1;
          }

          updatedDetails['statusCounts'] = statusCounts;
        }

        setState(() {
          _currentRSVPStatus = normalizedStatus;
          _cachedMatchDetails = updatedDetails;
        });

        // Update cache
        await _updateMessageInCache(updatedDetails);

        widget.onRSVP?.call();
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
    if (matchId == null) return false;
    final trimmed = matchId.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.toLowerCase() == 'placeholder_match_id') return false;
    return true;
  }

  bool _getCancellationStatus(Map<String, dynamic> details) {
    if (details['isCancelled'] == true) return true;
    if (details['practice'] != null && details['practice']['isCancelled'] == true) return true;
    if (details['match'] != null && details['match']['isCancelled'] == true) return true;
    return false;
  }

  String? _getCancellationReason(Map<String, dynamic> details) {
    if (details['cancellationReason'] is String && details['cancellationReason'].toString().isNotEmpty) {
      return details['cancellationReason'].toString();
    }
    if (details['practice'] != null && details['practice']['cancellationReason'] is String) {
      return details['practice']['cancellationReason'].toString();
    }
    if (details['match'] != null && details['match']['cancellationReason'] is String) {
      return details['match']['cancellationReason'].toString();
    }
    return null;
  }
}