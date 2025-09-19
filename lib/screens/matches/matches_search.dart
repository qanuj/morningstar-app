import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/match.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import 'match_detail.dart';
import '../practices/practice_match_detail.dart';

class MatchesSearchScreen extends StatefulWidget {
  const MatchesSearchScreen({Key? key}) : super(key: key);

  @override
  State<MatchesSearchScreen> createState() => _MatchesSearchScreenState();
}

class _MatchesSearchScreenState extends State<MatchesSearchScreen> {
  List<MatchListItem> _matches = [];
  List<MatchListItem> _filteredMatches = [];
  bool _isLoading = false;

  final TextEditingController _searchController = TextEditingController();

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
      final response = await ApiService.get('/rsvp');
      setState(() {
        _matches = (response['data'] as List)
            .map((match) => MatchListItem.fromJson(match))
            .toList();
        _filteredMatches = _matches;
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

  void _filterMatches(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMatches = _matches;
      } else {
        _filteredMatches = _matches.where((match) {
          final opponent = match.opponent?.toLowerCase() ?? '';
          final location = match.location.toLowerCase();
          final type = match.type.toLowerCase();
          final queryLower = query.toLowerCase();

          return opponent.contains(queryLower) ||
              location.contains(queryLower) ||
              type.contains(queryLower);
        }).toList();
      }
    });
  }

  Map<String, List<MatchListItem>> _groupMatchesByDate(
    List<MatchListItem> matches,
  ) {
    final Map<String, List<MatchListItem>> groupedMatches = {};

    for (final match in matches) {
      final dateKey = DateFormat('yyyy-MM-dd').format(match.matchDate);
      if (!groupedMatches.containsKey(dateKey)) {
        groupedMatches[dateKey] = [];
      }
      groupedMatches[dateKey]!.add(match);
    }

    return groupedMatches;
  }

  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));
    final yesterday = today.subtract(Duration(days: 1));
    final matchDate = DateTime(date.year, date.month, date.day);

    if (matchDate == today) {
      return 'Today';
    } else if (matchDate == tomorrow) {
      return 'Tomorrow';
    } else if (matchDate == yesterday) {
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
    final groupedMatches = _groupMatchesByDate(_filteredMatches);
    int count = 0;

    // Date headers + matches count
    for (final entry in groupedMatches.entries) {
      count += 1; // Date header
      count += entry.value.length; // Matches
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailAppBar(pageTitle: 'Search Matches', customActions: []),
      body: Column(
        children: [
          // Search header
          Container(
            padding: EdgeInsets.all(16),
            child: Container(
              height: 50,
              child: TextField(
                controller: _searchController,
                onChanged: _filterMatches,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by opponent, location, or type...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).iconTheme.color,
                    size: 24,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).iconTheme.color,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterMatches('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Search results count
          if (_searchController.text.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredMatches.length} result${_filteredMatches.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          // Results
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : _filteredMatches.isEmpty
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
                            _searchController.text.isEmpty
                                ? Icons.search_outlined
                                : Icons.search_off_outlined,
                            size: 64,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Start typing to search'
                              : 'No matches found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Search by opponent, location, or match type'
                              : 'Try different search terms',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final groupedMatches = _groupMatchesByDate(
                            _filteredMatches,
                          );
                          final sortedDateKeys = groupedMatches.keys.toList()
                            ..sort((a, b) => b.compareTo(a)); // Latest first

                          int currentIndex = 0;

                          for (final dateKey in sortedDateKeys) {
                            final matches = groupedMatches[dateKey]!;

                            // Date header
                            if (index == currentIndex) {
                              return _buildDateHeader(dateKey);
                            }
                            currentIndex++;

                            // Match cards for this date
                            for (int i = 0; i < matches.length; i++) {
                              if (index == currentIndex) {
                                return _buildMatchCard(matches[i]);
                              }
                              currentIndex++;
                            }
                          }

                          return SizedBox.shrink(); // Should never reach here
                        }, childCount: _getChildCount()),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(MatchListItem match) {
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
          onTap: () {
            final isPractice = match.type.toLowerCase() == 'practice';
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => isPractice
                    ? PracticeMatchDetailScreen(matchId: match.id)
                    : MatchDetailScreen(
                        matchId: match.id,
                        initialType: match.type,
                      ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Club Icon with Match Badge
                Stack(
                  children: [
                    // Club/Opponent Avatar
                    _buildMatchAvatar(match),
                    // Match Type Badge
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _getMatchTypeColor(match.type),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF1e1e1e)
                                : Theme.of(context).cardColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.sports_cricket,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12),

                // Match Info (Center)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        match.canSeeDetails
                            ? (match.opponent ?? 'Practice Match')
                            : 'Match Details TBD',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          height: 1.2,
                        ),
                      ),
                      if (match.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          match.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            height: 1.1,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.15)
                                  : Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              match.type.toUpperCase(),
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withOpacity(0.9)
                                    : Theme.of(context).primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          if (match.isCancelled) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cancel_outlined,
                                    size: 10,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'CANCELLED',
                                    style: TextStyle(
                                      color: Colors.red,
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

                // Match Details (Right)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // RSVP Status or Player Count
                    if (match.userRsvp != null) ...[
                      _buildRSVPStatus(match),
                    ] else ...[
                      Text(
                        '${match.confirmedPlayers}/${match.spots}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('hh:mm a').format(match.matchDate),
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

  // Reuse the same helper methods from the original MatchesScreen
  Widget _buildMatchAvatar(MatchListItem match) {
    if (match.type.toLowerCase() == 'practice') {
      return SVGAvatar(
        imageUrl: match.club.logo,
        size: 40,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        fallbackIcon: Icons.sports_cricket,
        iconSize: 24,
      );
    } else {
      if (match.opponent != null && match.canSeeDetails) {
        final opponentInitial = match.opponent!.isNotEmpty
            ? match.opponent!.substring(0, 1).toUpperCase()
            : 'O';

        return SVGAvatar(
          imageUrl: match.club.logo,
          size: 40,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          fallbackIcon: Icons.sports_cricket,
          iconSize: 24,
          child: match.club.logo == null
              ? Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      opponentInitial,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                )
              : null,
        );
      } else {
        return SVGAvatar(
          imageUrl: match.club.logo,
          size: 40,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          fallbackIcon: Icons.sports_cricket,
          iconSize: 24,
        );
      }
    }
  }

  Color _getMatchTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'game':
        return Colors.red;
      case 'practice':
        return Colors.blue;
      case 'tournament':
        return Colors.purple;
      case 'friendly':
        return Colors.green;
      case 'league':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRSVPStatus(MatchListItem match) {
    if (match.userRsvp == null) {
      return Text(
        '${match.confirmedPlayers}/${match.spots}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      );
    }

    final rsvp = match.userRsvp!;
    final canChangeRSVP = match.canRsvp && !match.isCancelled;

    return GestureDetector(
      onTap: canChangeRSVP ? () => _showRSVPDialog(match) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getRSVPColor(rsvp.status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getRSVPColor(rsvp.status).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getRSVPIcon(rsvp.status),
              size: 12,
              color: _getRSVPColor(rsvp.status),
            ),
            const SizedBox(width: 4),
            Text(
              _getRSVPText(rsvp.status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _getRSVPColor(rsvp.status),
              ),
            ),
            if (canChangeRSVP) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 10, color: _getRSVPColor(rsvp.status)),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getRSVPIcon(String status) {
    switch (status.toUpperCase()) {
      case 'YES':
        return Icons.check_circle;
      case 'NO':
        return Icons.cancel;
      case 'MAYBE':
        return Icons.help_outline;
      default:
        return Icons.hourglass_empty;
    }
  }

  Color _getRSVPColor(String status) {
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

  String _getRSVPText(String status) {
    switch (status.toUpperCase()) {
      case 'YES':
        return 'Going';
      case 'NO':
        return 'Not Going';
      case 'MAYBE':
        return 'Maybe';
      default:
        return 'Pending';
    }
  }

  void _showRSVPDialog(MatchListItem match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sports_cricket,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update RSVP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.color,
                          ),
                        ),
                        Text(
                          match.opponent ?? 'Practice Match',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // RSVP Options
              ..._buildRSVPOptions(match),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildRSVPOptions(MatchListItem match) {
    final options = [
      {'status': 'YES', 'text': 'Going', 'icon': Icons.check_circle},
      {'status': 'MAYBE', 'text': 'Maybe', 'icon': Icons.help_outline},
      {'status': 'NO', 'text': 'Not Going', 'icon': Icons.cancel},
    ];

    return options.map((option) {
      final isSelected =
          match.userRsvp?.status.toUpperCase() == option['status'];
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () {
            // TODO: Implement RSVP update API call
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('RSVP updated to ${option['text']}'),
                backgroundColor: _getRSVPColor(option['status'] as String),
              ),
            );
          },
          leading: Icon(
            option['icon'] as IconData,
            color: isSelected
                ? _getRSVPColor(option['status'] as String)
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
          title: Text(
            option['text'] as String,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? _getRSVPColor(option['status'] as String)
                  : Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          trailing: isSelected
              ? Icon(
                  Icons.radio_button_checked,
                  color: _getRSVPColor(option['status'] as String),
                )
              : Icon(
                  Icons.radio_button_unchecked,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: isSelected
              ? _getRSVPColor(option['status'] as String).withOpacity(0.1)
              : null,
        ),
      );
    }).toList();
  }
}
