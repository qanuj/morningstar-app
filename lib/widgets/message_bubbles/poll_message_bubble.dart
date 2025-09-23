import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../services/chat_api_service.dart';
import '../../services/poll_service.dart';
import 'base_message_bubble.dart';
import 'glass_header.dart';

/// A specialized message bubble for displaying poll messages
class PollMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final Function(String messageId, String emoji, String userId)? onReactionRemoved;
  final Function()? onViewPoll;

  const PollMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.isSelected,
    this.showSenderInfo = false,
    this.onReactionRemoved,
    this.onViewPoll,
  });

  @override
  State<PollMessageBubble> createState() => _PollMessageBubbleState();
}

class _PollMessageBubbleState extends State<PollMessageBubble> {
  Map<String, dynamic> pollDetails = {};
  bool isVoting = false;

  @override
  void initState() {
    super.initState();
    pollDetails = widget.message.meta ?? {};
    // For received polls, fetch fresh data to get current user's voting state
    if (widget.message.pollId != null && !widget.isOwn) {
      _fetchFreshPollData();
    }
  }

  Future<void> _fetchFreshPollData() async {
    if (widget.message.pollId == null) return;

    try {
      // Fetch fresh poll data from the API to get current user's voting state
      final polls = await PollService.getPolls(
        clubId: widget.message.clubId,
        includeExpired: true, // Include expired polls to show results
      );

      // Find the specific poll
      final poll = polls.firstWhere(
        (p) => p.id == widget.message.pollId,
        orElse: () => throw Exception('Poll not found'),
      );

      if (mounted) {
        setState(() {
          // Update with fresh data that includes current user's voting state
          pollDetails = {
            'question': poll.question,
            'options': poll.options.map((option) => {
              'id': option.id,
              'text': option.text,
              'votes': option.voteCount,
            }).toList(),
            'totalVotes': poll.totalVotes,
            'hasVoted': poll.hasVoted,
            'userVotes': poll.hasVoted && poll.userVote != null ? [poll.userVote!.pollOptionId] : [],
            'allowMultiple': false,
            'anonymous': false,
            'expiresAt': poll.expiresAt?.toIso8601String(),
          };
        });
      }
    } catch (e) {
      print('Failed to fetch fresh poll data: $e');
      // Keep using the metadata from the message if API call fails
    }
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
      content: _buildPollContent(context),
    );
  }

  Widget _buildPollContent(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Extract poll information
    final question = pollDetails['question']?.toString() ?? widget.message.content;
    final options = pollDetails['options'] as List? ?? [];
    final totalVotes = pollDetails['totalVotes'] as int? ?? 0;
    final hasVoted = pollDetails['hasVoted'] as bool? ?? false;
    final userVotes = pollDetails['userVotes'] as List? ?? [];
    final allowMultiple = pollDetails['allowMultiple'] as bool? ?? false;
    final anonymous = pollDetails['anonymous'] as bool? ?? false;
    final expiresAt = pollDetails['expiresAt'] != null 
        ? DateTime.tryParse(pollDetails['expiresAt'].toString())
        : null;
    
    final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Poll header with glass effect background
        GlassHeader.poll(isExpired: isExpired),

        // Poll content with padding
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poll question
              Text(
                question,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white.withOpacity(0.87) : Colors.black.withOpacity(0.87),
                ),
              ),

              SizedBox(height: 12),

              // Poll options
              ...options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value as Map<String, dynamic>;
                return _buildPollOption(context, option, index, hasVoted, isExpired, totalVotes, userVotes, allowMultiple);
              }).toList(),

              SizedBox(height: 12),

              // Poll stats
              Row(
                children: [
                  Icon(
                    Icons.how_to_vote,
                    size: 16,
                    color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                    ),
                  ),
                  if (anonymous)
                    Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 16,
                            color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Anonymous',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (expiresAt != null && !isExpired)
                    Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Expires ${_formatExpiryTime(expiresAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPollOption(BuildContext context, Map<String, dynamic> option, int index, bool hasVoted, bool isExpired, int totalVotes, List userVotes, bool allowMultiple) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final optionId = option['id']?.toString() ?? index.toString();
    final text = option['text']?.toString() ?? '';
    final votes = option['votes'] as int? ?? 0;
    final isSelected = userVotes.contains(optionId);
    final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0.0;
    
    final canVote = !isExpired && !isVoting;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: canVote ? () => _voteForOption(optionId) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasVoted 
                ? (isSelected 
                    ? Color(0xFF003f9b).withOpacity(0.2) 
                    : (isDarkMode ? Colors.grey[800] : Colors.grey[100]))
                : (isDarkMode ? Colors.grey[800] : Colors.grey[50]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? Color(0xFF003f9b) 
                  : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // Progress bar background
              if (hasVoted && percentage > 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: [percentage / 100, percentage / 100],
                        colors: [
                          Color(0xFF003f9b).withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Option content
              Row(
                children: [
                  if (!hasVoted && canVote)
                    Container(
                      width: 20,
                      height: 20,
                      margin: EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: allowMultiple ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: allowMultiple ? BorderRadius.circular(4) : null,
                        border: Border.all(
                          color: Color(0xFF003f9b),
                          width: 2,
                        ),
                      ),
                    ),
                  
                  if (isSelected)
                    Container(
                      width: 20,
                      height: 20,
                      margin: EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: allowMultiple ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: allowMultiple ? BorderRadius.circular(4) : null,
                        color: Color(0xFF003f9b),
                      ),
                      child: Icon(
                        allowMultiple ? Icons.check : Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isDarkMode ? Colors.white.withOpacity(0.87) : Colors.black.withOpacity(0.87),
                      ),
                    ),
                  ),
                  
                  if (hasVoted)
                    Text(
                      '${percentage.toStringAsFixed(0)}% ($votes)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003f9b),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _voteForOption(String optionId) async {
    if (isVoting || widget.message.pollId == null) return;

    // Check if user is changing their vote (clicking the same option they already voted for)
    final userVotes = pollDetails['userVotes'] as List? ?? [];
    final hasVoted = pollDetails['hasVoted'] as bool? ?? false;
    final previousVoteId = hasVoted && userVotes.isNotEmpty ? userVotes.first.toString() : null;

    // If clicking the same option they already voted for, do nothing
    if (previousVoteId == optionId) return;

    setState(() {
      isVoting = true;
    });

    try {
      // Call the actual PollService API
      await PollService.voteOnPoll(
        pollId: widget.message.pollId!,
        optionId: optionId,
      );

      // Update local state
      setState(() {
        final options = pollDetails['options'] as List? ?? [];

        // If changing vote, decrease count for previous option
        if (hasVoted && previousVoteId != null) {
          for (var option in options) {
            if (option['id'] == previousVoteId) {
              option['votes'] = ((option['votes'] as int? ?? 0) - 1).clamp(0, double.infinity).toInt();
              break;
            }
          }
        }

        // Increase count for new option
        for (var option in options) {
          if (option['id'] == optionId) {
            option['votes'] = (option['votes'] as int? ?? 0) + 1;
            break;
          }
        }

        // Only increase total votes if this is a new vote (not a change)
        if (!hasVoted) {
          pollDetails['totalVotes'] = (pollDetails['totalVotes'] as int? ?? 0) + 1;
        }

        pollDetails['hasVoted'] = true;
        pollDetails['userVotes'] = [optionId]; // For single-choice polls

        isVoting = false;
      });

    } catch (e) {
      setState(() {
        isVoting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record vote. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatExpiryTime(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    
    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'soon';
    }
  }
}