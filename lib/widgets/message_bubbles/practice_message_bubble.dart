import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../services/chat_api_service.dart';
import 'base_message_bubble.dart';

/// A specialized message bubble for displaying practice session messages
class PracticeMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;
  final Function()? onJoinPractice;

  const PracticeMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.isSelected,
    this.showSenderInfo = false,
    this.onReactionRemoved,
    this.onJoinPractice,
  });

  @override
  State<PracticeMessageBubble> createState() => _PracticeMessageBubbleState();
}

class _PracticeMessageBubbleState extends State<PracticeMessageBubble> {
  String?
  _currentRSVPStatus; // Track current RSVP status: 'YES', 'NO', 'MAYBE', or null

  @override
  void initState() {
    super.initState();
    // Initialize RSVP status from message data if available
    _currentRSVPStatus = _extractRSVPStatus();
  }

  String? _extractRSVPStatus() {
    // Try to extract RSVP status from practiceDetails if available
    final practiceDetails = widget.message.practiceDetails;
    if (practiceDetails != null && practiceDetails['userRsvp'] != null) {
      return practiceDetails['userRsvp']['status'];
    } else if (practiceDetails != null && practiceDetails['isJoined'] == true) {
      return 'YES'; // Map isJoined to 'YES' status
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
      content: _buildPracticeContent(context),
    );
  }

  Widget _buildPracticeContent(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final practiceDetails = widget.message.practiceDetails ?? {};

    // Extract practice information
    final date = practiceDetails['date']?.toString() ?? '';
    final time = practiceDetails['time']?.toString() ?? '';
    final venue = practiceDetails['venue']?.toString() ?? '';
    final duration = practiceDetails['duration']?.toString() ?? '';
    final maxParticipants = practiceDetails['maxParticipants'] as int? ?? 0;
    final currentParticipants =
        practiceDetails['currentParticipants'] as int? ?? 0;

    // Combine date and time for proper DateTime parsing
    DateTime? practiceDateTime;
    if (date.isNotEmpty && time.isNotEmpty) {
      try {
        practiceDateTime = DateTime.parse('${date}T$time:00');
      } catch (e) {
        practiceDateTime = null;
      }
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show content if no practice details, otherwise show rich practice info
          if (practiceDetails.isEmpty) ...[
            // Fallback content when no practice details
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
            // Practice details (Date, Time, Venue, etc.)
            _buildPracticeDetails(
              context,
              practiceDateTime,
              venue,
              duration,
              maxParticipants,
              currentParticipants,
            ),
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

  Widget _buildPracticeDetails(
    BuildContext context,
    DateTime? practiceDateTime,
    String venue,
    String duration,
    int maxParticipants,
    int currentParticipants,
  ) {
    // Format date, time and duration in single line
    String dateTimeText = '';
    if (practiceDateTime != null) {
      // Format as "Mon, Sept 15th at 4:30PM to 6:30PM"
      final dayOfWeek = _getDayOfWeek(practiceDateTime.weekday);
      final month = _getMonthName(practiceDateTime.month);
      final day = _getDayWithSuffix(practiceDateTime.day);
      final startTime = _formatTime(practiceDateTime);

      dateTimeText = '$dayOfWeek, $day $month > $startTime';

      if (duration.isNotEmpty) {
        // Try to calculate end time from duration
        final endTime = _calculateEndTime(practiceDateTime, duration);
        if (endTime != null) {
          dateTimeText += ' to ${_formatTime(endTime)}';
        } else {
          dateTimeText += ' • $duration';
        }
      }
    }

    return Column(
      children: [
        // Date, Time & Duration (merged)
        Text(
          "Practice",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        SizedBox(height: 8),

        // Date, Time & Duration (merged)
        if (dateTimeText.isNotEmpty)
          _buildDetailRowNoLabel(context, Icons.calendar_today, dateTimeText),

        // Venue
        if (venue.isNotEmpty)
          _buildDetailRowNoLabel(context, Icons.location_on, venue),

        // Participants
        if (maxParticipants > 0) ...[
          _buildDetailRowNoLabel(
            context,
            Icons.group,
            '$currentParticipants/$maxParticipants participants',
          ),
          if (maxParticipants > 0)
            Padding(
              padding: EdgeInsets.only(left: 24, bottom: 8),
              child: LinearProgressIndicator(
                value: currentParticipants / maxParticipants,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                minHeight: 3,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDetailRowNoLabel(
    BuildContext context,
    IconData icon,
    String value,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.87)
                    : Colors.black.withOpacity(0.87),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDirectRSVP(BuildContext context, String status) async {
    if (widget.message.practiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to RSVP: Practice ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Use ChatApiService.rsvpToMatch for now as it handles RSVP
      // In future, this should be ChatApiService.rsvpToPractice
      final success = await ChatApiService.rsvpToMatch(
        widget.message.clubId,
        widget.message.id,
        widget.message.practiceId!, // Use practiceId instead of matchId
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
        widget.onJoinPractice?.call();
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

  String _getDayOfWeek(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _getDayWithSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return '${day}th';
    }
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute == 0
        ? ''
        : ':${minute.toString().padLeft(2, '0')}';
    return '$displayHour$minuteStr$period';
  }

  DateTime? _calculateEndTime(DateTime startTime, String duration) {
    // Try to parse duration and calculate end time
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
}
