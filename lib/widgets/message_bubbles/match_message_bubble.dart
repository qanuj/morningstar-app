import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club_message.dart';
import '../../services/chat_api_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialize RSVP status from message data if available
    _currentRSVPStatus = _extractRSVPStatus();
  }

  String? _extractRSVPStatus() {
    // Try to extract RSVP status from matchDetails if available
    final matchDetails = widget.message.matchDetails;
    if (matchDetails != null && matchDetails['userRsvp'] != null) {
      return matchDetails['userRsvp']['status'];
    }
    return null;
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
    final matchDetails = widget.message.matchDetails ?? {};

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
            // Fallback content when no match details
            if (widget.message.content.isNotEmpty)
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
          if (matchDateTime != null) ...[
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${DateFormat('EEE, MMM d, yyyy').format(matchDateTime)} at ${DateFormat('h:mm a').format(matchDateTime)}',
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
                  venue['name']?.toString() ?? 'Venue TBD',
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

    try {
      final success = await ChatApiService.rsvpToMatch(
        widget.message.clubId,
        widget.message.id,
        widget.message.matchId!,
        status,
      );

      if (success && context.mounted) {
        // Update local RSVP status
        setState(() {
          _currentRSVPStatus = status;
        });

        // Show success message based on RSVP status
        final statusText = status == 'YES'
            ? 'confirmed'
            : status == 'NO'
            ? 'declined'
            : 'marked as maybe';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('RSVP $statusText successfully!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
        widget.onRSVP?.call();
      } else if (context.mounted) {
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
}
