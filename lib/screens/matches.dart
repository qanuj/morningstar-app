import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import 'match_detail.dart';

class MatchesScreen extends StatefulWidget {
  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<MatchListItem> _matches = [];
  bool _isLoading = false;
  String _selectedTab = 'upcoming';

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get('/rsvp');
      setState(() {
        _matches = (response['data'] as List).map((match) => MatchListItem.fromJson(match)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load matches: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  List<MatchListItem> get _filteredMatches {
    final now = DateTime.now();
    if (_selectedTab == 'upcoming') {
      return _matches.where((match) => match.matchDate.isAfter(now)).toList()
        ..sort((a, b) => a.matchDate.compareTo(b.matchDate));
    } else {
      return _matches.where((match) => match.matchDate.isBefore(now)).toList()
        ..sort((a, b) => b.matchDate.compareTo(a.matchDate));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Matches'),
        backgroundColor: AppTheme.cricketGreen,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: Container(
            color: AppTheme.cricketGreen,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 'upcoming'),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'upcoming' 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(0),
                      ),
                      child: Text(
                        'Upcoming',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: _selectedTab == 'upcoming' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 'past'),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'past' 
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(0),
                      ),
                      child: Text(
                        'Past',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: _selectedTab == 'past' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _filteredMatches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_cricket,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _selectedTab == 'upcoming' 
                          ? 'No upcoming matches'
                          : 'No past matches',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMatches,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _filteredMatches.length,
                    itemBuilder: (context, index) {
                      final match = _filteredMatches[index];
                      return _buildMatchCard(match);
                    },
                  ),
                ),
    );
  }

  Widget _buildMatchCard(MatchListItem match) {
    final isUpcoming = match.matchDate.isAfter(DateTime.now());
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(matchId: match.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with match type and club info
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getMatchTypeColor(match.type),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      match.type.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  if (match.club.logo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        match.club.logo!,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.cricketGreen,
                              borderRadius: BorderRadius.circular(10),
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
                  SizedBox(width: 4),
                  Text(
                    match.club.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  if (match.isCancelled)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'CANCELLED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (!match.canSeeDetails && !match.isCancelled)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'TBD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),
              
              // MatchListItem title
              Text(
                match.canSeeDetails 
                  ? (match.opponent ?? 'Practice Match')
                  : 'Match Details TBD',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              
              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      match.location,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              
              // Date and time
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(match.matchDate),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              
              // Notes (if available and details are visible)
              if (match.canSeeDetails && match.notes != null) ...[
                SizedBox(height: 8),
                Text(
                  match.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              SizedBox(height: 12),
              
              // Match info and RSVP status
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: AppTheme.cricketGreen),
                  SizedBox(width: 4),
                  Text(
                    '${match.confirmedPlayers}/${match.spots} confirmed',
                    style: TextStyle(
                      color: AppTheme.cricketGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (match.userRsvp != null) ...[
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRSVPColor(match.userRsvp!.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRSVPIcon(match.userRsvp!.status),
                            size: 12,
                            color: _getRSVPColor(match.userRsvp!.status),
                          ),
                          SizedBox(width: 4),
                          Text(
                            _getRSVPText(match.userRsvp!.status),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getRSVPColor(match.userRsvp!.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Spacer(),
                  if (isUpcoming && match.canRsvp)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MatchDetailScreen(matchId: match.id),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cricketGreen,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        match.userRsvp != null ? 'Update RSVP' : 'RSVP',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
              
              // Waitlist status
              if (match.userRsvp != null && match.userRsvp!.waitlistPosition != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Waitlist #${match.userRsvp!.waitlistPosition}',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Confirmed status
              if (match.userRsvp != null && match.userRsvp!.isConfirmed) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'You are confirmed for this match!',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
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
    );
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

  IconData _getRSVPIcon(String status) {
    switch (status) {
      case 'YES':
        return Icons.check_circle;
      case 'NO':
        return Icons.cancel;
      case 'MAYBE':
        return Icons.help;
      default:
        return Icons.hourglass_empty;
    }
  }

  Color _getRSVPColor(String status) {
    switch (status) {
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
    switch (status) {
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
}