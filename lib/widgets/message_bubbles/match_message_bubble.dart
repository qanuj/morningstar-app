import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club_message.dart';
import '../../services/match_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialize RSVP status from message data if available
    _resolvedMatchDetails = widget.message.matchDetails;
    _currentRSVPStatus = _extractRSVPStatus();

    if (widget.message.matchId != null) {
      _loadMatchDetails();
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
    if (matchId == null) {
      return;
    }

    setState(() {
      _isLoadingMatchDetails = true;
      _matchDetailsError = null;
    });

    Map<String, dynamic>? detailedMatch;
    Map<String, dynamic>? clubMatch;

    try {
      detailedMatch = await MatchService.getMatchDetail(matchId);
      if (detailedMatch != null && detailedMatch.isEmpty) {
        detailedMatch = null;
      }
    } catch (e) {
      debugPrint('❌ MatchMessageBubble: error fetching match detail: $e');
    }

    try {
      clubMatch = await MatchService.getClubMatch(
        clubId: widget.message.clubId,
        matchId: matchId,
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

    final existing =
        _resolvedMatchDetails ?? widget.message.matchDetails ?? <String, dynamic>{};
    final existingHome = existing['homeTeam'] as Map<String, dynamic>? ?? {};
    final existingOpponent =
        existing['opponentTeam'] as Map<String, dynamic>? ?? {};
    final existingVenue = existing['venue'] as Map<String, dynamic>? ?? {};

    final homeName = asString(clubMatch?['team']?['name']) ??
        asString(detail?['club']?['name']) ??
        asString(existingHome['name']) ??
        'Home Team';
    final homeLogo = asString(clubMatch?['team']?['logo']) ??
        asString(detail?['club']?['logo']) ??
        asString(existingHome['logo']);

    final opponentName = asString(clubMatch?['opponentTeam']?['name']) ??
        asString(clubMatch?['opponent']) ??
        asString(detail?['opponent']) ??
        asString(existingOpponent['name']) ??
        'Opponent Team';
    final opponentLogo = asString(clubMatch?['opponentTeam']?['logo']) ??
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

    final result = <String, dynamic>{
      'homeTeam': {
        'name': homeName,
        if (homeLogo != null) 'logo': homeLogo,
      },
      'opponentTeam': {
        'name': opponentName,
        if (opponentLogo != null) 'logo': opponentLogo,
      },
      'venue': {
        'name': venueName,
        if (venueAddress != null && venueAddress.isNotEmpty)
          'address': venueAddress,
      },
    };

    if (matchDateIso != null) {
      result['dateTime'] = matchDateIso;
    }

    if (userRsvp != null) {
      result['userRsvp'] = userRsvp;
    }

    return result;
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

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show content if no match details, otherwise show rich match info
          if (matchDetails.isEmpty) ...[
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
          ] else ...[
            // Rich match display when we have match details
            // Teams Section
            _buildTeamsSection(context, homeTeam, opponentTeam),

            SizedBox(height: 16),

            // Match details (Date, Time, Venue)
            _buildMatchDetails(context, matchDateTime, venue),

            if (_isLoadingMatchDetails) ...[
              SizedBox(height: 16),
              _buildLoadingState(compact: true),
            ],
          ],

          SizedBox(height: 16),

          // RSVP Buttons Row (IN, OUT, Maybe)
          Row(
            children: [
              // IN Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleDirectRSVP(context, 'YES'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentRSVPStatus == 'YES'
                        ? Color(0xFF4CAF50)
                        : Color(0xFF4CAF50).withOpacity(0.2),
                    foregroundColor: _currentRSVPStatus == 'YES'
                        ? Colors.white
                        : Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: _currentRSVPStatus == 'YES'
                          ? BorderSide.none
                          : BorderSide(color: Color(0xFF4CAF50), width: 1),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    elevation: _currentRSVPStatus == 'YES' ? 2 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentRSVPStatus == 'YES')
                        Icon(Icons.check, size: 14),
                      if (_currentRSVPStatus == 'YES') SizedBox(width: 4),
                      Text(
                        'IN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 8),

              // OUT Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleDirectRSVP(context, 'NO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentRSVPStatus == 'NO'
                        ? Color(0xFFFF5722)
                        : Color(0xFFFF5722).withOpacity(0.2),
                    foregroundColor: _currentRSVPStatus == 'NO'
                        ? Colors.white
                        : Color(0xFFFF5722),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: _currentRSVPStatus == 'NO'
                          ? BorderSide.none
                          : BorderSide(color: Color(0xFFFF5722), width: 1),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    elevation: _currentRSVPStatus == 'NO' ? 2 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentRSVPStatus == 'NO')
                        Icon(Icons.close, size: 14),
                      if (_currentRSVPStatus == 'NO') SizedBox(width: 4),
                      Text(
                        'OUT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 8),

              // Maybe Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleDirectRSVP(context, 'MAYBE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentRSVPStatus == 'MAYBE'
                        ? Color(0xFFFF9800)
                        : Color(0xFFFF9800).withOpacity(0.2),
                    foregroundColor: _currentRSVPStatus == 'MAYBE'
                        ? Colors.white
                        : Color(0xFFFF9800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: _currentRSVPStatus == 'MAYBE'
                          ? BorderSide.none
                          : BorderSide(color: Color(0xFFFF9800), width: 1),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    elevation: _currentRSVPStatus == 'MAYBE' ? 2 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentRSVPStatus == 'MAYBE')
                        Icon(Icons.help_outline, size: 14),
                      if (_currentRSVPStatus == 'MAYBE') SizedBox(width: 4),
                      Text(
                        'MAYBE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Home Team
          Expanded(
            child: _buildTeamInfo(
              context,
              homeTeamName,
              homeTeam['logo']?.toString(),
              isHome: true,
            ),
          ),

          // VS indicator
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'VS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          // Opponent Team
          Expanded(
            child: _buildTeamInfo(
              context,
              opponentTeamName,
              opponentTeam['logo']?.toString(),
              isHome: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamInfo(
    BuildContext context,
    String teamName,
    String? logoUrl, {
    required bool isHome,
  }) {
    return Column(
      children: [
        // Team Logo
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: logoUrl != null && logoUrl.isNotEmpty
              ? SVGAvatar(
                  imageUrl: logoUrl,
                  size: 50,
                  backgroundColor: Color(0xFF4CAF50).withOpacity(0.1),
                  iconColor: Color(0xFF4CAF50),
                  fallbackIcon: Icons.sports_cricket,
                  showBorder: false, // We handle border ourselves
                  fit: BoxFit.contain,
                )
              : Icon(Icons.sports_cricket, color: Color(0xFF4CAF50), size: 24),
        ),

        SizedBox(height: 6),

        // Team Name
        Text(
          teamName.isNotEmpty ? teamName : (isHome ? 'Home Team' : 'Away Team'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMatchDetails(
    BuildContext context,
    DateTime? matchDateTime,
    Map<String, dynamic> venue,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final localMatchDateTime = matchDateTime?.toLocal();
    final venueName = venue['name']?.toString() ?? 'Venue TBD';
    final venueAddress = venue['address']?.toString();
    final venueDisplay = (venueAddress != null &&
            venueAddress.isNotEmpty &&
            venueAddress != venueName)
        ? '$venueName • $venueAddress'
        : venueName;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withOpacity(0.1)
            : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Date & Time
          if (localMatchDateTime != null) ...[
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${DateFormat('EEE, MMM d, yyyy').format(localMatchDateTime)} at ${DateFormat('h:mm a').format(localMatchDateTime)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],

          // Venue
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  venueDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleDirectRSVP(BuildContext context, String status) async {
    if (widget.message.matchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to RSVP: Match ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final normalizedStatus = status.toUpperCase();

    try {
      final response = await MatchService.rsvpToMatch(
        matchId: widget.message.matchId!,
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

        setState(() {
          _currentRSVPStatus = normalizedStatus;
          _resolvedMatchDetails = updatedDetails;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusSuccessMessage(normalizedStatus)),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );

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

  String _statusSuccessMessage(String status) {
    switch (status.toUpperCase()) {
      case 'YES':
        return 'RSVP confirmed successfully!';
      case 'NO':
        return 'RSVP declined successfully.';
      case 'MAYBE':
        return 'RSVP updated to maybe.';
      default:
        return 'RSVP updated.';
    }
  }
}
