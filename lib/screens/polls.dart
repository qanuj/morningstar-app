import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class PollsScreen extends StatefulWidget {
  @override
  _PollsScreenState createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  List<Poll> _polls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get('/polls');
      setState(() {
        _polls = (response['data'] as List).map((poll) => Poll.fromJson(poll)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load polls: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _votePoll(String pollId, String optionId) async {
    try {
      await ApiService.post('/polls/$pollId/vote', {'optionId': optionId});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote submitted successfully')),
      );
      await _loadPolls(); // Reload to get updated data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit vote: $e')),
      );
    }
  }

  Future<void> _updateVote(String pollId, String optionId) async {
    try {
      await ApiService.put('/polls/$pollId/vote', {'optionId': optionId});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote updated successfully')),
      );
      await _loadPolls(); // Reload to get updated data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update vote: $e')),
      );
    }
  }

  void _handleVote(Poll poll, String optionId) {
    if (poll.hasVoted) {
      _showUpdateVoteDialog(poll, optionId);
    } else {
      _votePoll(poll.id, optionId);
    }
  }

  void _showUpdateVoteDialog(Poll poll, String optionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Update Vote'),
        content: Text('You have already voted on this poll. Do you want to change your vote?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateVote(poll.id, optionId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cricketGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Update Vote'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadPolls,
        color: AppTheme.cricketGreen,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.cricketGreen,
                ),
              )
            : _polls.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppTheme.cricketGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.poll_outlined,
                            size: 64,
                            color: AppTheme.cricketGreen,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No polls available',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Check back later for new polls',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _polls.length,
                    itemBuilder: (context, index) {
                      final poll = _polls[index];
                      return _buildPollCard(poll);
                    },
                  ),
      ),
    );
  }

  Widget _buildPollCard(Poll poll) {
    final isExpired = poll.expiresAt != null && poll.expiresAt!.isBefore(DateTime.now());
    final totalVotes = poll.options.fold(0, (sum, option) => sum + option.voteCount);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: AppTheme.softCardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Optional: Add poll detail view
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poll Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cricketGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.poll,
                        color: AppTheme.cricketGreen,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        poll.question,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                    ),
                    if (isExpired)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'EXPIRED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),

                // Club and Creator Info
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (poll.club.logo != null)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              poll.club.logo!,
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppTheme.cricketGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.sports_cricket,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${poll.club.name} • by ${poll.createdBy.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Poll Options
                ...poll.options.map((option) {
                  final percentage = totalVotes > 0 ? (option.voteCount / totalVotes * 100) : 0.0;
                  final isUserVote = poll.userVote?.pollOptionId == option.id;

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isUserVote 
                          ? AppTheme.cricketGreen.withOpacity(0.1)
                          : AppTheme.backgroundColor,
                      border: Border.all(
                        color: isUserVote 
                            ? AppTheme.cricketGreen.withOpacity(0.5)
                            : AppTheme.dividerColor.withOpacity(0.3),
                        width: isUserVote ? 2 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: !isExpired ? () => _handleVote(poll, option.id) : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.text,
                                      style: TextStyle(
                                        fontWeight: isUserVote 
                                            ? FontWeight.w600 
                                            : FontWeight.w500,
                                        color: AppTheme.primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  if (poll.hasVoted || totalVotes > 0) ...[
                                    SizedBox(width: 12),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cricketGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${option.voteCount}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: AppTheme.cricketGreen,
                                        ),
                                      ),
                                    ),
                                    if (isUserVote) ...[
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.check_circle,
                                        color: AppTheme.cricketGreen,
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                              if (poll.hasVoted || totalVotes > 0) ...[
                                SizedBox(height: 12),
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.dividerColor.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: percentage / 100,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isUserVote 
                                            ? AppTheme.cricketGreen
                                            : AppTheme.cricketGreen.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.secondaryTextColor,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),

                SizedBox(height: 16),

                // Poll Footer
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: AppTheme.secondaryTextColor),
                      SizedBox(width: 4),
                      Text(
                        'Created ${DateFormat('MMM dd, yyyy').format(poll.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                      if (poll.expiresAt != null) ...[
                        SizedBox(width: 16),
                        Icon(Icons.event, size: 16, color: isExpired ? Colors.red : AppTheme.secondaryTextColor),
                        SizedBox(width: 4),
                        Text(
                          'Expires ${DateFormat('MMM dd, yyyy').format(poll.expiresAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isExpired ? Colors.red : AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cricketGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.cricketGreen,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!isExpired) ...[
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cricketGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.cricketGreen.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.cricketGreen,
                        ),
                        SizedBox(width: 8),
                        Text(
                          poll.hasVoted 
                              ? 'Tap on an option to change your vote'
                              : 'Tap on an option to vote',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.cricketGreen,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}