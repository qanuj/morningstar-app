import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club_message.dart';
import '../../services/chat_api_service.dart';
import '../dialogs/match_rsvp_dialog.dart';
import '../svg_avatar.dart';
import 'base_message_bubble.dart';

/// A specialized message bubble for displaying match announcements
class MatchMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final Function(String messageId, String emoji, String userId)? onReactionRemoved;
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
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      customColor: Color(0xFF4CAF50).withOpacity(0.1),
      showMetaOverlay: true,
      showShadow: true,
      onReactionRemoved: onReactionRemoved,
      content: _buildMatchContent(context),
    );
  }

  Widget _buildMatchContent(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final matchDetails = message.matchDetails ?? {};
    
    // Extract match information
    final homeTeam = matchDetails['homeTeam'] as Map<String, dynamic>? ?? {};
    final opponentTeam = matchDetails['opponentTeam'] as Map<String, dynamic>? ?? {};
    final venue = matchDetails['venue'] as Map<String, dynamic>? ?? {};
    final matchDateTime = matchDetails['dateTime'] != null 
        ? DateTime.tryParse(matchDetails['dateTime'].toString())
        : null;
    
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF4CAF50).withOpacity(isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF4CAF50).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Match header with match icon
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sports_cricket,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Match Created',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Show content if no match details, otherwise show rich match info
                if (matchDetails.isEmpty) ...[
                  // Fallback content when no match details
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white.withOpacity(0.87) : Colors.black.withOpacity(0.87),
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
                
                // RSVP Button (full width)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRSVPDialog(context),
                    icon: Icon(
                      Icons.how_to_reg,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      'RSVP to Match',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // View Match button (top right corner)
          Positioned(
            top: 12,
            right: 12,
            child: InkWell(
              onTap: onViewMatch,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.sports_cricket,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsSection(BuildContext context, Map<String, dynamic> homeTeam, Map<String, dynamic> opponentTeam) {
    // Extract team names with fallbacks
    final homeTeamName = homeTeam['name']?.toString() ?? 
                        homeTeam['teamName']?.toString() ?? 
                        'Home Team';
    final opponentTeamName = opponentTeam['name']?.toString() ?? 
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

  Widget _buildTeamInfo(BuildContext context, String teamName, String? logoUrl, {required bool isHome}) {
    return Column(
      children: [
        // Team Logo
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Color(0xFF4CAF50).withOpacity(0.3),
              width: 1,
            ),
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
              : Icon(
                  Icons.sports_cricket,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
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

  Widget _buildMatchDetails(BuildContext context, DateTime? matchDateTime, Map<String, dynamic> venue) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(0xFF4CAF50).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Date & Time
          if (matchDateTime != null) ...[
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Color(0xFF4CAF50),
                ),
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
              Icon(
                Icons.location_on,
                size: 16,
                color: Color(0xFF4CAF50),
              ),
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

  void _showRSVPDialog(BuildContext context) {
    if (message.matchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to RSVP: Match ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => MatchRSVPDialog(
        matchId: message.matchId!,
        onRSVP: (status) => _handleRSVP(context, status),
      ),
    );
  }

  void _handleRSVP(BuildContext context, String status) async {
    if (message.matchId == null) return;

    try {
      final success = await ChatApiService.rsvpToMatch(
        message.clubId,
        message.id,
        message.matchId!,
        status,
      );

      if (success && context.mounted) {
        // RSVP successful - the dialog will show success message
        // In a real app, you might want to update the UI to show current RSVP status
        onRSVP?.call();
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