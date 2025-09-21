import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../services/match_service.dart';
import '../widgets/svg_avatar.dart';
import '../widgets/event_cards.dart';
import '../screens/matches/match_detail.dart';
import '../screens/practices/practice_match_detail.dart';
import '../services/notification_service.dart';

class MatchesListWidget extends StatefulWidget {
  final Club? clubFilter;
  final bool showHeader;
  final String? customEmptyMessage;
  final bool isFromHome;

  const MatchesListWidget({
    super.key,
    this.clubFilter,
    this.showHeader = false,
    this.customEmptyMessage,
    this.isFromHome = false,
  });

  @override
  State<MatchesListWidget> createState() => MatchesListWidgetState();
}

class MatchesListWidgetState extends State<MatchesListWidget> {
  List<MatchListItem> _matches = [];
  bool _isLoading = false;

  // Real-time notification subscriptions for match updates
  final Set<String> _subscribedMatchIds = {};

  // Search and filtering
  final TextEditingController _searchController = TextEditingController();

  // Infinite scroll with pagination
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadMatches();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasNextPage) {
      _loadMoreMatches();
    }
  }

  @override
  void dispose() {
    // Clean up notification subscriptions
    for (final matchId in _subscribedMatchIds) {
      NotificationService.removeMatchUpdateCallback(matchId, _handleMatchUpdate);
    }
    _subscribedMatchIds.clear();

    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _matches.clear();
    });

    await _fetchMatchesPage(1, isRefresh: true);

    setState(() => _isLoading = false);
  }

  Future<void> _fetchMatchesPage(int page, {bool isRefresh = false}) async {
    try {
      List<MatchListItem> newMatches;
      Map<String, dynamic>? paginationInfo;

      // Debug logging
      print(
        '🔍 MatchesListWidget Debug: clubFilter = ${widget.clubFilter?.id}',
      );
      print('🔍 MatchesListWidget Debug: isFromHome = ${widget.isFromHome}');

      // Use MatchService to get matches - it will use the appropriate endpoint
      if (widget.clubFilter != null) {
        // For club-specific matches, get paginated matches
        newMatches = await MatchService.getMatches(
          clubId: widget.clubFilter!.id,
          includeCancelled: false,
          showFullyPaid: false,
          upcomingOnly: false, // Get all matches
        );
        // Club matches don't have pagination info from API yet
        paginationInfo = null;
      } else if (widget.isFromHome) {
        // For home screen matches, use /matches endpoint with me=true
        newMatches = await MatchService.getUserMatches(
          includeCancelled: false,
          showFullyPaid: false,
          upcomingOnly: false,
        );
        // User matches from /matches endpoint don't have pagination info yet
        paginationInfo = null;
      } else {
        // For user's matches from matches screen, get paginated matches from RSVP endpoint
        final response = await ApiService.get('/rsvp?page=$page&limit=20');
        final responseMap = response;
        final matchesList = responseMap['matches'] as List;
        paginationInfo = responseMap['pagination'] as Map<String, dynamic>;

        newMatches = matchesList
            .map(
              (match) => MatchListItem.fromJson(match as Map<String, dynamic>),
            )
            .toList();
      }

      setState(() {
        if (isRefresh) {
          _matches = newMatches;
        } else {
          _matches.addAll(newMatches);
        }

        // Update pagination info
        if (paginationInfo != null) {
          _currentPage = paginationInfo['page'] as int;
          _totalPages = paginationInfo['totalPages'] as int;
          _hasNextPage = paginationInfo['hasNextPage'] as bool;
        } else {
          // For club matches without pagination
          _hasNextPage = false;
        }

        // Subscribe to real-time updates for new matches
        _subscribeToMatchUpdates();

        // Sort matches: upcoming first (ascending), then past matches (descending)
        final now = DateTime.now();
        final upcomingMatches = _matches
            .where((match) => match.matchDate.toLocal().isAfter(now))
            .toList();
        final pastMatches = _matches
            .where((match) => match.matchDate.toLocal().isBefore(now))
            .toList();

        // Sort upcoming matches by date (ascending - earliest first)
        upcomingMatches.sort((a, b) => a.matchDate.compareTo(b.matchDate));
        // Sort past matches by date (descending - most recent first)
        pastMatches.sort((a, b) => b.matchDate.compareTo(a.matchDate));

        // Combine: upcoming first, then past
        _matches = [...upcomingMatches, ...pastMatches];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load matches: $e')));
      }
    }
  }

  Future<void> _loadMoreMatches() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      await _fetchMatchesPage(nextPage, isRefresh: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more matches: $e')),
        );
      }
    }

    setState(() => _isLoadingMore = false);
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
                'Match Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(height: 16),

              // Refresh button
              ListTile(
                title: Text(
                  'Refresh Matches',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Load latest match updates',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                leading: Icon(
                  Icons.refresh,
                  color: Theme.of(context).primaryColor,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _loadMatches();
                },
                contentPadding: EdgeInsets.zero,
              ),

              // Info about swipe gestures and pagination
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick RSVP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'For all upcoming matches:\n• Swipe right → YES RSVP\n• Swipe left → NO RSVP\n• Press & hold → Select role\n• Confirmation shown when changing RSVP',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pagination info if applicable
                  if (_totalPages > 1) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Page $_currentPage of $_totalPages • ${_matches.length} matches loaded',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          if (widget.showHeader)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                widget.clubFilter != null
                    ? '${widget.clubFilter!.name} Matches'
                    : 'Matches',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Main content with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMatches,
              color: Theme.of(context).primaryColor,
              displacement: 40.0,
              strokeWidth: 2.0,
              child: _isLoading && _matches.isEmpty
                  ? _buildLoadingState()
                  : _matches.isEmpty
                  ? _buildEmptyState()
                  : _buildMatchesList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20),
      children: [
        SizedBox(height: 100),
        Center(
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
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              SizedBox(height: 8),
              Text(
                widget.clubFilter != null
                    ? 'This club has no scheduled matches yet.'
                    : 'Pull down to refresh and check for new matches.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchesList() {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : Colors.grey[200],
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount:
            _matches.length +
            (_isLoadingMore ? 1 : 0) +
            (_hasNextPage && !_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, index) {
          if (index == _matches.length - 1 &&
              (_hasNextPage || _isLoadingMore)) {
            return const SizedBox.shrink(); // No separator before loading indicator
          }
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          // Show loading indicator at the bottom when loading more
          if (index >= _matches.length && _isLoadingMore) {
            return _buildLoadingMoreIndicator();
          }

          // Show "Load more" button when there are more pages but not currently loading
          if (index >= _matches.length && _hasNextPage && !_isLoadingMore) {
            return _buildLoadMoreButton();
          }

          final match = _matches[index];
          return _buildMatchItem(match);
        },
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading more matches...',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Center(
        child: TextButton.icon(
          onPressed: _loadMoreMatches,
          icon: Icon(Icons.expand_more, color: Theme.of(context).primaryColor),
          label: Text(
            'Load More Matches',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchItem(MatchListItem match) {
    final now = DateTime.now();
    final localMatchDate = match.matchDate.toLocal();
    final isUpcoming = localMatchDate.isAfter(now);

    // Determine if this is a practice or match based on type
    final isPractice = match.type.toLowerCase() == 'practice';
    final isMatch =
        match.type.toLowerCase() == 'game' ||
        match.type.toLowerCase() == 'tournament';

    // Enable swipe for upcoming matches, regardless of current canRsvp status
    // This allows users to change their RSVP even if they've already responded
    if (isUpcoming) {
      return _buildSwipeableEventItem(match, isUpcoming, isPractice);
    }

    // For past matches, show normal item
    return _buildRegularEventItem(match, isUpcoming, isPractice);
  }

  void _openMatchDetails(MatchListItem match) {
    final isPractice = match.type.toLowerCase() == 'practice';
    final route = MaterialPageRoute(
      builder: (context) => isPractice
          ? PracticeMatchDetailScreen(matchId: match.id)
          : MatchDetailScreen(matchId: match.id, initialType: match.type),
    );
    Navigator.of(context).push(route);
  }

  Widget _buildSwipeableEventItem(
    MatchListItem match,
    bool isUpcoming,
    bool isPractice,
  ) {
    // Always allow swipe for upcoming matches - users can change their RSVP
    return Dismissible(
      key: Key('match_${match.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.2,
        DismissDirection.endToStart: 0.2,
      },
      // Handle both partial and full swipes
      confirmDismiss: (direction) async {
        // Make RSVP API call when user swipes past threshold
        if (direction == DismissDirection.startToEnd) {
          // Swipe right = YES
          await _handleRsvp(match, 'YES');
        } else if (direction == DismissDirection.endToStart) {
          // Swipe left = NO
          await _handleRsvp(match, 'NO');
        }
        // Always return false to keep the card in the list after RSVP
        return false;
      },
      background: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'YES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'NO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.cancel, color: Colors.white, size: 24),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _openMatchDetails(match),
        onLongPress: () => _showRoleSelectionModal(match),
        child: _buildEventCard(match, isUpcoming, isPractice),
      ),
    );
  }

  Widget _buildRegularEventItem(
    MatchListItem match,
    bool isUpcoming,
    bool isPractice,
  ) {
    return GestureDetector(
      onTap: () => _openMatchDetails(match),
      child: _buildEventCard(match, isUpcoming, isPractice),
    );
  }

  Widget _buildEventCard(
    MatchListItem match,
    bool isUpcoming,
    bool isPractice,
  ) {
    // Use appropriate card based on type
    if (isPractice) {
      return Opacity(
        opacity: isUpcoming ? 1.0 : 0.6,
        child: PracticeEventCard(
          practice: match,
          onTap: null, // onTap handled by parent GestureDetector
        ),
      );
    } else {
      return Opacity(
        opacity: isUpcoming ? 1.0 : 0.6,
        child: MatchEventCard(
          match: match,
          isUpcoming: isUpcoming,
          onTap: null, // onTap handled by parent GestureDetector
        ),
      );
    }
  }

  String? _getReadableMatchType(String type) {
    final normalized = type.toLowerCase();
    switch (normalized) {
      case 'game':
        return 'Game';
      case 'practice':
        return 'Practice';
      case 'tournament':
        return 'Tournament';
      case 'friendly':
        return 'Friendly';
      case 'league':
        return 'League';
      default:
        if (type.isEmpty) return null;
        return '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}';
    }
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

  Future<bool?> _showRsvpChangeConfirmation(
    MatchListItem match,
    String newStatus,
  ) async {
    final currentStatus = match.userRsvp?.status ?? 'NONE';
    final statusText = newStatus == 'YES' ? 'attend' : 'decline';
    final currentStatusText = currentStatus.toLowerCase() == 'yes'
        ? 'attending'
        : 'not attending';

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Change RSVP?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                match.opponent ?? 'Practice Session',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'You are currently $currentStatusText.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Do you want to change your RSVP to $statusText?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Change RSVP',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRsvp(
    MatchListItem match,
    String status, [
    String? selectedRole,
  ]) async {
    // Check if user already has an RSVP and is changing it
    if (match.userRsvp != null &&
        match.userRsvp!.status.toUpperCase() != status.toUpperCase()) {
      final bool? shouldChange = await _showRsvpChangeConfirmation(
        match,
        status,
      );
      if (shouldChange != true) {
        return; // User cancelled the change
      }
    }
    // Immediately update the UI with optimistic state
    setState(() {
      final matchIndex = _matches.indexWhere((m) => m.id == match.id);
      if (matchIndex != -1) {
        // Create optimistic RSVP object
        final optimisticRsvp = MatchRSVPSimple(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
          status: status,
          selectedRole: selectedRole,
          isConfirmed: status == 'YES', // Optimistic assumption
          waitlistPosition: null, // Will be updated from API response if needed
          teamId: match.userRsvp?.teamId, // Preserve existing teamId if available
        );

        // Create updated match with optimistic RSVP info
        final updatedMatch = MatchListItem(
          id: match.id,
          clubId: match.clubId,
          type: match.type,
          location: match.location,
          opponent: match.opponent,
          notes: match.notes,
          spots: match.spots,
          matchDate: match.matchDate,
          createdAt: match.createdAt,
          updatedAt: DateTime.now(),
          hideUntilRSVP: match.hideUntilRSVP,
          rsvpAfterDate: match.rsvpAfterDate,
          rsvpBeforeDate: match.rsvpBeforeDate,
          notifyMembers: match.notifyMembers,
          isCancelled: match.isCancelled,
          cancellationReason: match.cancellationReason,
          isSquadReleased: match.isSquadReleased,
          totalExpensed: match.totalExpensed,
          paidAmount: match.paidAmount,
          club: match.club,
          canSeeDetails: match.canSeeDetails,
          canRsvp: match.canRsvp,
          availableSpots: match.availableSpots,
          confirmedPlayers: match.confirmedPlayers,
          userRsvp: optimisticRsvp,
          team: match.team, // Preserve team data
          opponentTeam: match.opponentTeam, // Preserve opponent team data
        );
        _matches[matchIndex] = updatedMatch;
      }
    });

    // Toast removed - visual feedback comes from badge update instead

    // Now make the API call in background to sync with server
    try {
      final body = {'matchId': match.id, 'status': status};

      if (selectedRole != null) {
        body['selectedRole'] = selectedRole;
      }

      final response = await ApiService.post('/rsvp', body);

      if (response['success'] == true) {
        // Update with real server response if needed
        final actualRsvp = response['rsvp'];
        if (actualRsvp != null) {
          setState(() {
            final matchIndex = _matches.indexWhere((m) => m.id == match.id);
            if (matchIndex != -1) {
              final currentMatch = _matches[matchIndex];
              final updatedMatch = MatchListItem(
                id: currentMatch.id,
                clubId: currentMatch.clubId,
                type: currentMatch.type,
                location: currentMatch.location,
                opponent: currentMatch.opponent,
                notes: currentMatch.notes,
                spots: currentMatch.spots,
                matchDate: currentMatch.matchDate,
                createdAt: currentMatch.createdAt,
                updatedAt: DateTime.now(),
                hideUntilRSVP: currentMatch.hideUntilRSVP,
                rsvpAfterDate: currentMatch.rsvpAfterDate,
                rsvpBeforeDate: currentMatch.rsvpBeforeDate,
                notifyMembers: currentMatch.notifyMembers,
                isCancelled: currentMatch.isCancelled,
                cancellationReason: currentMatch.cancellationReason,
                isSquadReleased: currentMatch.isSquadReleased,
                totalExpensed: currentMatch.totalExpensed,
                paidAmount: currentMatch.paidAmount,
                club: currentMatch.club,
                canSeeDetails: currentMatch.canSeeDetails,
                canRsvp: currentMatch.canRsvp,
                availableSpots: currentMatch.availableSpots,
                confirmedPlayers: currentMatch.confirmedPlayers,
                userRsvp: MatchRSVPSimple.fromJson(actualRsvp),
                team: currentMatch.team, // Preserve team data
                opponentTeam: currentMatch.opponentTeam, // Preserve opponent team data
              );
              _matches[matchIndex] = updatedMatch;
            }
          });
        }

        // Show server confirmation if there's important info (like waitlist)
        if (response['message'] != null &&
            response['message'].toString().contains('waitlist')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message']),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      // If API call fails, revert the optimistic update
      setState(() {
        final matchIndex = _matches.indexWhere((m) => m.id == match.id);
        if (matchIndex != -1) {
          final currentMatch = _matches[matchIndex];
          final revertedMatch = MatchListItem(
            id: currentMatch.id,
            clubId: currentMatch.clubId,
            type: currentMatch.type,
            location: currentMatch.location,
            opponent: currentMatch.opponent,
            notes: currentMatch.notes,
            spots: currentMatch.spots,
            matchDate: currentMatch.matchDate,
            createdAt: currentMatch.createdAt,
            updatedAt: currentMatch.updatedAt,
            hideUntilRSVP: currentMatch.hideUntilRSVP,
            rsvpAfterDate: currentMatch.rsvpAfterDate,
            rsvpBeforeDate: currentMatch.rsvpBeforeDate,
            notifyMembers: currentMatch.notifyMembers,
            isCancelled: currentMatch.isCancelled,
            cancellationReason: currentMatch.cancellationReason,
            isSquadReleased: currentMatch.isSquadReleased,
            totalExpensed: currentMatch.totalExpensed,
            paidAmount: currentMatch.paidAmount,
            club: currentMatch.club,
            canSeeDetails: currentMatch.canSeeDetails,
            canRsvp: currentMatch.canRsvp,
            availableSpots: currentMatch.availableSpots,
            confirmedPlayers: currentMatch.confirmedPlayers,
            userRsvp: match.userRsvp, // Revert to original state
            team: currentMatch.team, // Preserve team data
            opponentTeam: currentMatch.opponentTeam, // Preserve opponent team data
          );
          _matches[matchIndex] = revertedMatch;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update RSVP: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showRoleSelectionModal(MatchListItem match) {
    final roles = [
      'Any Position',
      'Batsman',
      'Bowler',
      'All-rounder',
      'Wicket Keeper',
      'Captain',
    ];

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
                'Select Role for Match',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(height: 8),
              Text(
                match.opponent ?? 'Practice Session',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              Text(
                DateFormat(
                  'MMM dd, yyyy · HH:mm',
                ).format(match.matchDate.toLocal()),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 24),

              // Role options
              ...roles.map(
                (role) => ListTile(
                  title: Text(
                    role,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  leading: Icon(
                    _getRoleIcon(role),
                    color: Theme.of(context).primaryColor,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleRsvp(match, 'YES', role);
                  },
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 4,
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Subscribe to real-time updates for all matches in the current list
  void _subscribeToMatchUpdates() {
    for (final match in _matches) {
      if (!_subscribedMatchIds.contains(match.id)) {
        NotificationService.addMatchUpdateCallback(match.id, _handleMatchUpdate);
        _subscribedMatchIds.add(match.id);
        print('🔔 Subscribed to match updates: ${match.id}');
      }
    }
  }

  /// Handle real-time match updates (e.g., RSVP changes)
  void _handleMatchUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    final matchId = data['matchId'] as String?;
    if (matchId == null) return;

    print('🔄 Received match update for: $matchId, data: $data');

    // Find the match in our list and update it
    final matchIndex = _matches.indexWhere((match) => match.id == matchId);
    if (matchIndex == -1) {
      print('ℹ️ Match $matchId not found in current list, skipping update');
      return;
    }

    try {
      // Parse the updated RSVP data
      final rsvpsData = data['rsvps'];
      final confirmedPlayers = int.tryParse(data['confirmedPlayers']?.toString() ?? '0') ?? 0;

      if (rsvpsData != null) {
        setState(() {
          // Update the match with new RSVP data
          final currentMatch = _matches[matchIndex];

          // Create an updated match with new RSVP information
          _matches[matchIndex] = MatchListItem(
            id: currentMatch.id,
            clubId: currentMatch.clubId,
            type: currentMatch.type,
            location: currentMatch.location,
            opponent: currentMatch.opponent,
            notes: currentMatch.notes,
            spots: currentMatch.spots,
            matchDate: currentMatch.matchDate,
            createdAt: currentMatch.createdAt,
            updatedAt: currentMatch.updatedAt,
            hideUntilRSVP: currentMatch.hideUntilRSVP,
            rsvpAfterDate: currentMatch.rsvpAfterDate,
            rsvpBeforeDate: currentMatch.rsvpBeforeDate,
            notifyMembers: currentMatch.notifyMembers,
            isCancelled: bool.tryParse(data['isCancelled']?.toString() ?? 'false') ?? currentMatch.isCancelled,
            cancellationReason: data['cancellationReason']?.toString() ?? currentMatch.cancellationReason,
            isSquadReleased: currentMatch.isSquadReleased,
            totalExpensed: currentMatch.totalExpensed,
            paidAmount: currentMatch.paidAmount,
            club: currentMatch.club,
            canSeeDetails: currentMatch.canSeeDetails,
            canRsvp: currentMatch.canRsvp,
            availableSpots: currentMatch.availableSpots,
            confirmedPlayers: confirmedPlayers,
            userRsvp: currentMatch.userRsvp,
            rsvps: currentMatch.rsvps,
            team: currentMatch.team,
            opponentTeam: currentMatch.opponentTeam,
          );
        });

        print('✅ Updated match $matchId with $confirmedPlayers confirmed players');
      }
    } catch (e) {
      print('❌ Error updating match $matchId: $e');
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Batsman':
        return Icons.sports_cricket;
      case 'Bowler':
        return Icons.sports_baseball;
      case 'All-rounder':
        return Icons.sports;
      case 'Wicket Keeper':
        return Icons.sports_handball;
      case 'Captain':
        return Icons.stars;
      case 'Any Position':
      default:
        return Icons.person;
    }
  }
}
