import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import 'match_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Match> _matches = [];
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
      final clubId = await AuthService.getCurrentClubId();
      if (clubId != null) {
        final response = await ApiService.get('/clubs/$clubId/matches');
        setState(() {
          _matches = (response as List).map((match) => Match.fromJson(match)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load matches: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  List<Match> get _filteredMatches {
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
    return Column(
      children: [
        Container(
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
        Expanded(
          child: _isLoading
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
        ),
      ],
    );
  }

  Widget _buildMatchCard(Match match) {
    final isUpcoming = match.matchDate.isAfter(DateTime.now());
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(match: match),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                ],
              ),
              SizedBox(height: 12),
              Text(
                match.opponent ?? 'Practice Match',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
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
              if (match.notes != null) ...[
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
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: AppTheme.cricketGreen),
                  SizedBox(width: 4),
                  Text(
                    '${match.spots} spots',
                    style: TextStyle(
                      color: AppTheme.cricketGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  if (isUpcoming && !match.isCancelled)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MatchDetailScreen(match: match),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cricketGreen,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        'RSVP',
                        style: TextStyle(color: Colors.white, fontSize: 12),
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
}