import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../services/match_service.dart';
import '../widgets/svg_avatar.dart';
import '../screens/matches/match_detail.dart';

class MatchesListWidget extends StatefulWidget {
  final Club? clubFilter;
  final bool showHeader;
  final String? customEmptyMessage;

  const MatchesListWidget({
    super.key,
    this.clubFilter,
    this.showHeader = false,
    this.customEmptyMessage,
  });

  @override
  State<MatchesListWidget> createState() => MatchesListWidgetState();
}

class MatchesListWidgetState extends State<MatchesListWidget> {
  List<MatchListItem> _matches = [];
  bool _isLoading = false;

  // Search and filtering
  final TextEditingController _searchController = TextEditingController();
  bool _showPastMatches = false; // Hidden by default

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);

    try {
      List<MatchListItem> allMatches;
      
      // Use MatchService to get matches - it will use the appropriate endpoint
      if (widget.clubFilter != null) {
        // For club-specific matches, use the admin matches endpoint with specific parameters
        final upcomingOnly = !_showPastMatches;
        print('🔍 Filter Debug: _showPastMatches = $_showPastMatches, upcomingOnly = $upcomingOnly');
        
        allMatches = await MatchService.getMatches(
          clubId: widget.clubFilter!.id,
          includeCancelled: false,
          showFullyPaid: false,
          upcomingOnly: upcomingOnly, // Use the filter setting
        );
      } else {
        // For user's matches, use the RSVP endpoint
        final response = await ApiService.get('/rsvp');
        allMatches = (response['data'] as List)
            .map((match) => MatchListItem.fromJson(match))
            .toList();
      }

      setState(() {
        var filteredMatches = allMatches;
        
        final now = DateTime.now();
        
        // Apply client-side filtering for user matches only (API handles it for club matches)
        if (widget.clubFilter == null && !_showPastMatches) {
          // Show only upcoming matches
          filteredMatches = filteredMatches
              .where((match) => match.matchDate.toLocal().isAfter(now))
              .toList();
        }
        
        // API returns matches in correct order, no client-side sorting needed
        _matches = filteredMatches;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load matches: $e')));
      }
    }

    setState(() => _isLoading = false);
  }

  /// Public method to refresh matches from parent widgets
  Future<void> refreshMatches() async {
    return _loadMatches();
  }

  void showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Title
              Text(
                'Filter Matches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(height: 8),
              
              // Past matches toggle
              SwitchListTile(
                title: Text(
                  'Show Past Matches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Include completed matches in the list',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                value: _showPastMatches,
                onChanged: (value) {
                  print('🔍 Toggle Debug: Changing _showPastMatches from $_showPastMatches to $value');
                  setState(() {
                    _showPastMatches = value;
                  });
                  print('🔍 Toggle Debug: _showPastMatches is now $_showPastMatches');
                  Navigator.pop(context);
                  _loadMatches(); // Reload with new filter
                },
                activeColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700] 
                    : Colors.grey[300],
                inactiveThumbColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[400] 
                    : Colors.grey[500],
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<MatchListItem>> _groupMatchesByDate(
    List<MatchListItem> matches,
  ) {
    final Map<String, List<MatchListItem>> groupedMatches = {};

    for (final match in matches) {
      // Convert to local timezone before formatting
      final localDate = match.matchDate.toLocal();
      final dateKey = DateFormat('yyyy-MM-dd').format(localDate);
      if (!groupedMatches.containsKey(dateKey)) {
        groupedMatches[dateKey] = [];
      }
      groupedMatches[dateKey]!.add(match);
    }

    // API returns matches in correct order, preserve that order in groups
    return groupedMatches;
  }

  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final matchDate = DateTime(date.year, date.month, date.day);

    if (matchDate == today) {
      return 'Today';
    } else if (matchDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showHeader)
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              widget.clubFilter != null
                  ? '${widget.clubFilter!.name} Matches'
                  : 'Matches',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),


        // Main content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadMatches,
            color: Theme.of(context).primaryColor,
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : _matches.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sports_cricket_outlined,
                            size: 64,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          widget.customEmptyMessage ?? 'No matches found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).textTheme.titleMedium?.color,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.clubFilter != null
                              ? 'This club has no scheduled matches yet.'
                              : 'Check back later for upcoming matches.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : _buildMatchesList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchesList() {
    final groupedMatches = _groupMatchesByDate(_matches);

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4),
      itemCount: groupedMatches.length,
      itemBuilder: (context, index) {
        final dateKey = groupedMatches.keys.elementAt(index);
        final dayMatches = groupedMatches[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDateHeader(dateKey),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)
                      : Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            // Matches for this date
            ...dayMatches.map((match) => _buildMatchItem(match)),

            if (index < groupedMatches.length - 1) SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildMatchItem(MatchListItem match) {
    final now = DateTime.now();
    final localMatchDate = match.matchDate.toLocal();
    final isUpcoming = localMatchDate.isAfter(now);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MatchDetailScreen(matchId: match.id),
          ),
        );
      },
      child: Container(
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
              color: Theme.of(context).shadowColor.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Club Avatar with RSVP Badge
              _buildTeamAvatar(match),
              SizedBox(width: 12),

              // Match Info (Center)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      match.opponent ?? 'Practice Session',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.15)
                            : Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        match.type,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.9)
                              : Theme.of(context).primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (match.location.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 10,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              match.location,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Time and Status (Right)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('HH:mm').format(localMatchDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isUpcoming
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  SizedBox(height: 2),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isUpcoming
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isUpcoming ? 'Upcoming' : 'Completed',
                      style: TextStyle(
                        color: isUpcoming
                            ? Colors.green[700]
                            : Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
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

  Widget _buildTeamAvatar(MatchListItem match) {
    final now = DateTime.now();
    final localMatchDate = match.matchDate.toLocal();
    final isUpcoming = localMatchDate.isAfter(now);

    return Stack(
      children: [
        // Club Avatar
        SVGAvatar(
          imageUrl: match.club.logo,
          size: 40,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          fallbackIcon: Icons.sports_cricket,
          iconSize: 24,
        ),
        // RSVP Status Badge (if applicable)
        if (match.userRsvp != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _getRsvpStatusColor(match.userRsvp!.status),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
              child: Icon(
                _getRsvpStatusIcon(match.userRsvp!.status),
                color: Theme.of(context).colorScheme.onPrimary,
                size: 10,
              ),
            ),
          )
        else
          // Match Type Badge for non-RSVP matches
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isUpcoming
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
              child: Icon(
                isUpcoming ? Icons.schedule : Icons.check,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 10,
              ),
            ),
          ),
      ],
    );
  }

  Color _getRsvpStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'yes':
        return Colors.green;
      case 'no':
        return Colors.red;
      case 'maybe':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRsvpStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'yes':
        return Icons.check;
      case 'no':
        return Icons.close;
      case 'maybe':
        return Icons.question_mark;
      default:
        return Icons.help_outline;
    }
  }
}
