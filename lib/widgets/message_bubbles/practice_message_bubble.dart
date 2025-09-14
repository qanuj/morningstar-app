import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  String? _currentRSVPStatus; // Track current RSVP status: 'YES', 'NO', 'MAYBE', or null

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
      customColor: Color(0xFF4CAF50).withOpacity(0.1),
      showMetaOverlay: true,
      showShadow: true,
      onReactionRemoved: widget.onReactionRemoved,
      content: _buildPracticeContent(context),
    );
  }

  Widget _buildPracticeContent(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final practiceDetails = message.practiceDetails ?? {};

    // Extract practice information
    final title = practiceDetails['title']?.toString() ?? 'Net Practice';
    final description = practiceDetails['description']?.toString() ?? '';
    final date = practiceDetails['date']?.toString() ?? '';
    final time = practiceDetails['time']?.toString() ?? '';
    final venue = practiceDetails['venue']?.toString() ?? '';
    final duration = practiceDetails['duration']?.toString() ?? '';
    final type = practiceDetails['type']?.toString() ?? 'Training';
    final maxParticipants = practiceDetails['maxParticipants'] as int? ?? 0;
    final currentParticipants =
        practiceDetails['currentParticipants'] as int? ?? 0;
    final isJoined = practiceDetails['isJoined'] as bool? ?? false;
    final isFull =
        maxParticipants > 0 && currentParticipants >= maxParticipants;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Practice header with sports icon
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Practice description
              if (description.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.87)
                          : Colors.black.withOpacity(0.87),
                    ),
                  ),
                ),

              // Practice details
              Column(
                children: [
                  if (date.isNotEmpty)
                    _buildDetailRow(
                      context,
                      Icons.calendar_today,
                      'Date',
                      date,
                    ),
                  if (time.isNotEmpty)
                    _buildDetailRow(context, Icons.access_time, 'Time', time),
                  if (venue.isNotEmpty)
                    _buildDetailRow(context, Icons.location_on, 'Venue', venue),
                  if (duration.isNotEmpty)
                    _buildDetailRow(context, Icons.timer, 'Duration', duration),
                  if (maxParticipants > 0)
                    _buildDetailRow(
                      context,
                      Icons.people,
                      'Participants',
                      '$currentParticipants/$maxParticipants',
                      showProgress: true,
                      progress: maxParticipants > 0
                          ? currentParticipants / maxParticipants
                          : 0.0,
                    ),
                ],
              ),

              SizedBox(height: 16),

              // Join button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isFull && !isJoined
                      ? null
                      : () {
                          // Handle join/leave practice
                          onJoinPractice?.call();
                        },
                  icon: Icon(
                    isJoined ? Icons.check_circle : Icons.add_circle,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    isFull && !isJoined
                        ? 'Session Full'
                        : isJoined
                        ? 'Joined'
                        : 'Join Session',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFull && !isJoined
                        ? Colors.grey
                        : isJoined
                        ? Color(0xFF4CAF50)
                        : Color(0xFF4CAF50),
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

        // Practice details button (top right corner)
        Positioned(
          top: 12,
          right: 12,
          child: InkWell(
            onTap: () {
              // Navigate to practice details or handle practice info
              print('Practice details tapped');
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.info_outline,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool showProgress = false,
    double progress = 0.0,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.87)
                        : Colors.black.withOpacity(0.87),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showProgress && progress > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50),
                      ),
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
