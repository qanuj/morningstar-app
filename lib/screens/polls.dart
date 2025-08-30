import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../widgets/duggy_logo.dart';

class PollsScreen extends StatefulWidget {
  @override
  _PollsScreenState createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  List<Poll> _polls = [];
  bool _isLoading = false;
  String _selectedStatus = 'all';
  String _selectedPeriod = 'all';
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _hasPrevPage = false;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPolls({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
    }

    setState(() => _isLoading = true);

    try {
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'limit': '20',
      };

      if (_selectedStatus != 'all') {
        queryParams['status'] = _selectedStatus;
      }

      if (_selectedPeriod != 'all') {
        queryParams['period'] = _selectedPeriod;
      }

      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await ApiService.get('/polls?$queryString');
      
      setState(() {
        _polls = (response['polls'] as List).map((poll) => Poll.fromJson(poll)).toList();

        // Update pagination info if available
        if (response['pagination'] != null) {
          final pagination = response['pagination'];
          _currentPage = pagination['currentPage'] ?? 1;
          _totalPages = pagination['totalPages'] ?? 1;
          _hasNextPage = pagination['hasNextPage'] ?? false;
          _hasPrevPage = pagination['hasPrevPage'] ?? false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load polls: $e')),
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

  Map<String, List<Poll>> _groupPollsByDate(List<Poll> polls) {
    final Map<String, List<Poll>> groupedPolls = {};
    
    for (final poll in polls) {
      final dateKey = DateFormat('yyyy-MM-dd').format(poll.createdAt);
      if (!groupedPolls.containsKey(dateKey)) {
        groupedPolls[dateKey] = [];
      }
      groupedPolls[dateKey]!.add(poll);
    }
    
    return groupedPolls;
  }
  
  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));
    final yesterday = today.subtract(Duration(days: 1));
    final pollDate = DateTime(date.year, date.month, date.day);
    
    if (pollDate == today) {
      return 'Today';
    } else if (pollDate == tomorrow) {
      return 'Tomorrow';
    } else if (pollDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
  
  Widget _buildDateHeader(String dateKey) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.1)
            : Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatDateHeader(dateKey),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.8)
              : Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
  
  int _getChildCount() {
    final groupedPolls = _groupPollsByDate(_polls);
    int count = 0;
    
    // Date headers + polls count
    for (final entry in groupedPolls.entries) {
      count += 1; // Date header
      count += entry.value.length; // Polls
    }
    
    count += 1; // Pagination widget
    return count;
  }

  Widget _buildPaginationWidget() {
    if (_totalPages <= 1) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _hasPrevPage ? _loadPreviousPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text('Previous'),
          ),
          Text(
            'Page $_currentPage of $_totalPages',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          ElevatedButton(
            onPressed: _hasNextPage ? _loadNextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text('Next'),
          ),
        ],
      ),
    );
  }
  
  void _loadNextPage() {
    if (_hasNextPage) {
      _currentPage++;
      _loadPolls();
    }
  }
  
  void _loadPreviousPage() {
    if (_hasPrevPage) {
      _currentPage--;
      _loadPolls();
    }
  }
  
  void _applyFilters() {
    _currentPage = 1;
    _loadPolls();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Filter Polls',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).textTheme.headlineSmall?.color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Status Filter
              Text(
                'Poll Status',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildFilterChip('All', 'all', _selectedStatus),
                  SizedBox(width: 8),
                  _buildFilterChip('Active', 'active', _selectedStatus),
                  SizedBox(width: 8),
                  _buildFilterChip('Expired', 'expired', _selectedStatus),
                ],
              ),
              SizedBox(height: 24),
              // Period Filter
              Text(
                'Time Period',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('All', 'all', _selectedPeriod),
                  _buildFilterChip('Week', 'week', _selectedPeriod),
                  _buildFilterChip('Month', 'month', _selectedPeriod),
                  _buildFilterChip('3 Months', '3months', _selectedPeriod),
                ],
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyFilters();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Apply Filters',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue) {
    final isSelected = currentValue == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w400,
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (label == 'All' || label == 'Week' || label == 'Month' || label == '3 Months') {
            _selectedPeriod = value;
          } else {
            _selectedStatus = value;
          }
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      checkmarkColor: Theme.of(context).primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.5)
              : Theme.of(context).dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search polls...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).iconTheme.color,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.8)
                    : Theme.of(context).primaryColor,
                size: 20,
              ),
              onPressed: _showFilterBottomSheet,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPolls(isRefresh: true),
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
                      'No polls found',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your poll history will appear here',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  // Poll List with Date Groups
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final groupedPolls = _groupPollsByDate(_polls);
                        final sortedDateKeys = groupedPolls.keys.toList()
                          ..sort((a, b) => b.compareTo(a)); // Latest first
                        
                        int currentIndex = 0;
                        
                        for (final dateKey in sortedDateKeys) {
                          final polls = groupedPolls[dateKey]!;
                          
                          // Date header
                          if (index == currentIndex) {
                            return _buildDateHeader(dateKey);
                          }
                          currentIndex++;
                          
                          // Poll cards for this date
                          for (int i = 0; i < polls.length; i++) {
                            if (index == currentIndex) {
                              return _buildPollCard(polls[i]);
                            }
                            currentIndex++;
                          }
                        }
                        
                        // Pagination widget at the end
                        if (index == currentIndex) {
                          return _buildPaginationWidget();
                        }
                        
                        return SizedBox.shrink(); // Should never reach here
                      },
                      childCount: _getChildCount(),
                    ),
                  ),
                ],
              ),
      ),
    );
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
                          '${poll.club.name} • by ${poll.createdBy.name}',
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
      margin: EdgeInsets.only(bottom: 8, left: 12, right: 12),
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
                        '${poll.club.name} • by ${poll.createdBy.name}',
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
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.15)
                                  : Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isExpired ? 'EXPIRED' : (poll.hasVoted ? 'VOTED' : 'ACTIVE'),
                              style: TextStyle(
                                color: isExpired 
                                    ? Colors.red
                                    : poll.hasVoted 
                                        ? Colors.green
                                        : Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white.withOpacity(0.9)
                                            : Theme.of(context).primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          if (poll.expiresAt != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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