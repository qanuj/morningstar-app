import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../widgets/duggy_logo.dart';
import 'notifications.dart';

class PollsScreen extends StatefulWidget {
  @override
  _PollsScreenState createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      
      // Try different possible response formats
      List<dynamic> pollsData;
      if (response['polls'] != null) {
        pollsData = response['polls'] as List;
      } else if (response['data'] != null) {
        pollsData = response['data'] as List;
      } else {
        throw Exception('No polls data found in response');
      }
      
      setState(() {
        _polls = pollsData.map((poll) => Poll.fromJson(poll)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load polls: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _votePoll(String pollId, String optionId) async {
    try {
      await ApiService.post('/polls/$pollId/vote', {'optionId': optionId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote submitted successfully')),
        );
        await _loadPolls(); // Reload to get updated data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit vote: $e')),
        );
      }
    }
  }

  Future<void> _updateVote(String pollId, String optionId) async {
    try {
      await ApiService.put('/polls/$pollId/vote', {'optionId': optionId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote updated successfully')),
        );
        await _loadPolls(); // Reload to get updated data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update vote: $e')),
        );
      }
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
              backgroundColor: Theme.of(context).primaryColor,
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
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: Drawer(), // You can customize this later if needed
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Icon(
            Icons.menu,
            color: Theme.of(context).appBarTheme.foregroundColor,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            DuggyLogoVariant.small(
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
            Text(
              'Polls',
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      NotificationsScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: animation.drive(
                            Tween(
                              begin: Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).chain(CurveTween(curve: Curves.easeOutCubic)),
                          ),
                          child: child,
                        );
                      },
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.notifications_outlined,
                color: Theme.of(context).appBarTheme.foregroundColor,
                size: 24,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPolls,
        color: Theme.of(context).primaryColor,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).primaryColor,
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
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.poll_outlined,
                            size: 64,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No polls available',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for new polls',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodySmall?.color,
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

  // Helper method to get the option the user voted for
  dynamic _getUserVotedOption(Poll poll) {
    if (!poll.hasVoted || poll.userVote == null) return null;
    
    try {
      return poll.options.firstWhere(
        (option) => option.id == poll.userVote!.pollOptionId,
      );
    } catch (e) {
      return null;
    }
  }

  void _showPollVotingSheet(Poll poll) {
    final isExpired = poll.expiresAt != null && poll.expiresAt!.isBefore(DateTime.now());
    final totalVotes = poll.options.fold(0, (sum, option) => sum + option.voteCount);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: poll.club.logo != null
                          ? Image.network(
                              poll.club.logo!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return DuggyLogoVariant.small();
                              },
                            )
                          : DuggyLogoVariant.small(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.question,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).textTheme.headlineSmall?.color,
                          ),
                        ),
                        Text(
                          poll.club.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // Poll Options
              Text(
                'Poll Options',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              SizedBox(height: 12),
              
              ...poll.options.map((option) {
                final percentage = totalVotes > 0 ? (option.voteCount / totalVotes * 100) : 0.0;
                final isUserVote = poll.userVote?.pollOptionId == option.id;
                
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: !isExpired ? () {
                        Navigator.pop(context);
                        _handleVote(poll, option.id);
                      } : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isUserVote 
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.withOpacity(0.1),
                          border: Border.all(
                            color: isUserVote 
                                ? Theme.of(context).primaryColor.withOpacity(0.5)
                                : Theme.of(context).dividerColor.withOpacity(0.3),
                            width: isUserVote ? 2 : 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.text,
                                    style: TextStyle(
                                      fontWeight: isUserVote ? FontWeight.w600 : FontWeight.w400,
                                      fontSize: 12,
                                      color: Theme.of(context).textTheme.titleLarge?.color,
                                    ),
                                  ),
                                ),
                                if (poll.hasVoted || totalVotes > 0) ...[
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${option.voteCount}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  if (isUserVote) ...[
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).primaryColor,
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
                                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: percentage / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isUserVote 
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context).primaryColor.withOpacity(0.7),
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
                                    color: Theme.of(context).textTheme.bodySmall?.color,
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
              }),
              
              // Footer info
              if (!isExpired) ...[
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(width: 8),
                      Text(
                        poll.hasVoted 
                            ? 'Tap on an option to change your vote'
                            : 'Tap on an option to vote',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
                  SizedBox(width: 4),
                  Text(
                    'Created ${DateFormat('MMM dd, yyyy').format(poll.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  if (poll.expiresAt != null) ...[
                    SizedBox(width: 16),
                    Icon(Icons.event, size: 16, color: isExpired ? Colors.red : Theme.of(context).textTheme.bodySmall?.color),
                    SizedBox(width: 4),
                    Text(
                      'Expires ${DateFormat('MMM dd, yyyy').format(poll.expiresAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpired ? Colors.red : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPollCard(Poll poll) {
    final isExpired = poll.expiresAt != null && poll.expiresAt!.isBefore(DateTime.now());
    final totalVotes = poll.options.fold(0, (sum, option) => sum + option.voteCount);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isExpired ? null : () => _showPollVotingSheet(poll),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Club Icon with Poll Badge
                Stack(
                  children: [
                    // Club Icon (bigger)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: poll.club.logo != null
                            ? Image.network(
                                poll.club.logo!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return DuggyLogoVariant.medium();
                                },
                              )
                            : DuggyLogoVariant.medium(),
                      ),
                    ),
                    // Poll Status Badge
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red : (poll.hasVoted ? Colors.green : Colors.orange),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF1e1e1e)
                                : Theme.of(context).cardColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isExpired ? Icons.close : (poll.hasVoted ? Icons.check : Icons.poll),
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12),
                
                // Poll Info (Center)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        poll.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        poll.club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Show either specific vote OR status badge (not both)
                          if (poll.hasVoted && poll.userVote != null)
                            // User's specific vote
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.how_to_vote,
                                    size: 10,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _getUserVotedOption(poll)?.text ?? "Unknown",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            // Status Badge (for non-voted or expired polls)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.15)
                                    : Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isExpired ? 'EXPIRED' : 'ACTIVE',
                                style: TextStyle(
                                  color: isExpired 
                                      ? Colors.red
                                      : Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white.withOpacity(0.9)
                                          : Theme.of(context).primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          
                          // Expiry Date Badge
                          if (poll.expiresAt != null)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 10,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    DateFormat('MMM dd').format(poll.expiresAt!),
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
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
                
                // Poll Stats (Right)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$totalVotes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalVotes == 1 ? 'vote' : 'votes',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd').format(poll.createdAt),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}