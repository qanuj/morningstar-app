import 'package:flutter/material.dart';
import '../../widgets/svg_avatar.dart';

class MatchRsvpScreen extends StatelessWidget {
  final Map<String, dynamic> matchDetails;
  final bool isPractice;

  const MatchRsvpScreen({
    super.key,
    required this.matchDetails,
    required this.isPractice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final rsvps = matchDetails['rsvps'] as List? ?? [];
    final counts = _extractStatusCounts(matchDetails);

    return Scaffold(
      backgroundColor: isDarkMode
          ? theme.scaffoldBackgroundColor
          : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? theme.scaffoldBackgroundColor
            : Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
        ),
        title: Text(
          '${isPractice ? 'Practice' : 'Match'} RSVPs',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRsvpStatusCard(
              'Going',
              'YES',
              rsvps,
              counts,
              isDarkMode,
              theme,
            ),
            const SizedBox(height: 20),
            _buildRsvpStatusCard(
              'Not Going',
              'NO',
              rsvps,
              counts,
              isDarkMode,
              theme,
            ),
            const SizedBox(height: 20),
            _buildRsvpStatusCard(
              'Maybe',
              'MAYBE',
              rsvps,
              counts,
              isDarkMode,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRsvpStatusCard(
    String label,
    String status,
    List rsvps,
    Map<String, int> counts,
    bool isDarkMode,
    ThemeData theme,
  ) {
    final statusRsvps = rsvps.where((rsvp) {
      if (rsvp is Map<String, dynamic>) {
        return rsvp['status']?.toString().toUpperCase() == status;
      }
      return false;
    }).toList();

    final count = counts[status] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          if (statusRsvps.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Add a subtle divider
            Container(
              height: 1,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              margin: const EdgeInsets.only(bottom: 16),
            ),
            ...statusRsvps.map<Widget>((rsvp) {
              final user = rsvp['user'] as Map<String, dynamic>? ?? {};
              final name = user['name']?.toString() ?? 'Unknown';
              final avatarUrl = user['profilePicture']?.toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SVGAvatar(
                      imageUrl: avatarUrl,
                      size: 44,
                      fallbackText: name.isNotEmpty ? name[0] : 'U',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ] else if (count == 0) ...[
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              margin: const EdgeInsets.only(bottom: 8),
            ),
            Text(
              'No responses yet',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, int> _extractStatusCounts(Map<String, dynamic> matchDetails) {
    // Extract counts from match details
    final yesCount = matchDetails['yesCount'] as int? ?? 0;
    final noCount = matchDetails['noCount'] as int? ?? 0;
    final maybeCount = matchDetails['maybeCount'] as int? ?? 0;

    return {'YES': yesCount, 'NO': noCount, 'MAYBE': maybeCount};
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'YES':
        return Colors.green;
      case 'NO':
        return Colors.red;
      case 'MAYBE':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
