import 'package:flutter/material.dart';
import '../../widgets/svg_avatar.dart';

class PollVotesScreen extends StatelessWidget {
  final String question;
  final List<Map<String, dynamic>> options;

  const PollVotesScreen({
    super.key,
    required this.question,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Find the option with the most votes for the star indicator
    int maxVotes = 0;
    for (final option in options) {
      final votes = option['votes'] as int? ?? 0;
      if (votes > maxVotes) {
        maxVotes = votes;
      }
    }

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
          'Poll Results',
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
            // Poll question in a card
            Container(
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
              child: Text(
                question,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Options with results
            if (options.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'No poll options available',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ...options.map((option) {
                final optText = option['text']?.toString() ?? '';
                final votes = option['votes'] as int? ?? 0;
                final voters = (option['voters'] as List? ?? [])
                    .cast<Map<String, dynamic>>();
                final isWinning = votes == maxVotes && maxVotes > 0;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
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
                      // Option header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              optText,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '$votes vote${votes == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isWinning) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ],
                        ],
                      ),

                      // Voters list
                      if (voters.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        // Add a subtle divider
                        Container(
                          height: 1,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                          margin: const EdgeInsets.only(bottom: 12),
                        ),
                        ...voters.map((voter) {
                          final votedAt = DateTime.tryParse(
                            voter['votedAt'] ?? '',
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SVGAvatar(
                                  imageUrl: voter['profilePicture'],
                                  size: 44,
                                  fallbackText: voter['name']?[0] ?? 'U',
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        voter['name'] == 'You'
                                            ? 'You'
                                            : (voter['name'] ?? 'Unknown User'),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        votedAt != null
                                            ? 'today ${_formatVoteTimeShort(votedAt)}'
                                            : 'recently',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ] else ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 1,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                          margin: const EdgeInsets.only(bottom: 8),
                        ),
                        Text(
                          '0 votes',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  String _formatVoteTimeShort(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      // Format as "2:05 PM" for same day
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}