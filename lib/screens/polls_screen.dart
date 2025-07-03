import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
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
      final clubId = await AuthService.getCurrentClubId();
      if (clubId != null) {
        final response = await ApiService.get('/clubs/$clubId/polls');
        setState(() {
          _polls = (response as List).map((poll) => Poll.fromJson(poll)).toList();
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPolls,
      child: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _polls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.poll,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No polls available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
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
    );
  }

  Widget _buildPollCard(Poll poll) {
    final isExpired = poll.expiresAt != null && poll.expiresAt!.isBefore(DateTime.now());
    final totalVotes = poll.options.fold(0, (sum, option) => sum + option.voteCount);

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poll Header
            Row(
              children: [
                Icon(Icons.poll, color: AppTheme.cricketGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.question,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),

            // Poll Options
            ...poll.options.map((option) {
              final percentage = totalVotes > 0 ? (option.voteCount / totalVotes * 100) : 0.0;
              final isUserVote = poll.userVote == option.id;

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: (!poll.hasVoted && !isExpired) 
                      ? () => _votePoll(poll.id, option.id)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUserVote 
                          ? AppTheme.cricketGreen.withOpacity(0.1)
                          : Colors.grey[50],
                      border: Border.all(
                        color: isUserVote 
                            ? AppTheme.cricketGreen 
                            : Colors.grey[300]!,
                        width: isUserVote ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  fontWeight: isUserVote 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (poll.hasVoted) ...[
                              SizedBox(width: 8),
                              Text(
                                '${option.voteCount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cricketGreen,
                                ),
                              ),
                              if (isUserVote) ...[
                                SizedBox(width: 4),
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.cricketGreen,
                                  size: 16,
                                ),
                              ],
                            ],
                          ],
                        ),
                        if (poll.hasVoted) ...[
                          SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isUserVote 
                                    ? AppTheme.cricketGreen
                                    : AppTheme.cricketGreen.withOpacity(0.5),
                              ),
                              minHeight: 6,
                            ),
                          ),
                          SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            SizedBox(height: 16),

            // Poll Footer
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Created ${DateFormat('MMM dd, yyyy').format(poll.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (poll.expiresAt != null) ...[
                  SizedBox(width: 16),
                  Icon(Icons.event, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Expires ${DateFormat('MMM dd, yyyy').format(poll.expiresAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ],
                Spacer(),
                Text(
                  '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            if (!poll.hasVoted && !isExpired) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cricketGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tap on an option to vote',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.cricketGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
