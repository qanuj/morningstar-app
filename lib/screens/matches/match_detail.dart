import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/match_details.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  MatchDetailScreenState createState() => MatchDetailScreenState();
}

class MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchRSVPResponse? _matchData;
  bool _isLoading = false;
  String _selectedRole = 'Batsman';
  final _notesController = TextEditingController();

  final List<String> _roles = [
    'Batsman',
    'Bowler',
    'All-rounder',
    'Wicket Keeper',
    'Captain',
    'Any Position',
  ];

  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchData() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get('/matches/${widget.matchId}');
      setState(() {
        final match = Match.fromJson(response);
        _matchData = MatchRSVPResponse(
          match: match,
          rsvps: RSVPCounts(
            confirmed: [],
            waitlisted: [],
            declined: [],
            maybe: [],
            pending: [],
          ),
          userRsvp: match.userRsvp,
          counts: RSVPCounts(
            confirmed: [],
            waitlisted: [],
            declined: [],
            maybe: [],
            pending: [],
          ),
        );

        if (match.userRsvp != null) {
          _selectedRole = match.userRsvp!.selectedRole ?? 'Batsman';
          _notesController.text = match.userRsvp!.notes ?? '';
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load match data: $e')));
    }

    setState(() => _isLoading = false);
  }

  Future<void> _submitRSVP(String status) async {
    if (_matchData == null) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'matchId': widget.matchId,
        'status': status,
        'selectedRole': _selectedRole,
        'notes': _notesController.text.trim(),
      };

      final response = await ApiService.post('/rsvp', data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'RSVP updated successfully'),
        ),
      );

      await _loadMatchData(); // Reload data
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update RSVP: $e')));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _matchData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Match Details'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).appBarTheme.backgroundColor
              : AppTheme.cricketGreen,
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).appBarTheme.foregroundColor
              : Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_matchData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Match Details'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).appBarTheme.backgroundColor
              : AppTheme.cricketGreen,
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).appBarTheme.foregroundColor
              : Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 80, color: Colors.red),
              SizedBox(height: 16),
              Text('Failed to load match details'),
              SizedBox(height: 16),
              ElevatedButton(onPressed: _loadMatchData, child: Text('Retry')),
            ],
          ),
        ),
      );
    }

    final match = _matchData!.match;
    final userRsvp = _matchData!.userRsvp;
    match.matchDate.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Match Details'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).appBarTheme.backgroundColor
            : AppTheme.cricketGreen,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).appBarTheme.foregroundColor
            : Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMatchData,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Match Header
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getMatchTypeColor(match.type),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              match.type.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          if (match.club.logo != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                match.club.logo!,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppTheme.cricketGreen,
                                      borderRadius: BorderRadius.circular(12),
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
                          SizedBox(width: 8),
                          Text(
                            match.club.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Spacer(),
                          if (match.isCancelled)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'CANCELLED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        match.canSeeDetails
                            ? (match.opponent ?? 'Practice Match')
                            : 'Match Details TBD',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: AppTheme.cricketGreen),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              match.location,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, color: AppTheme.cricketGreen),
                          SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'EEEE, MMM dd, yyyy • hh:mm a',
                            ).format(match.matchDate),
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      if (match.canSeeDetails && match.notes != null) ...[
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                match.notes!,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!match.canSeeDetails) ...[
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    'Details Hidden',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.orange.shade300
                                        : Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Match details will be revealed closer to the event or after you RSVP.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.orange.shade300
                                        : Colors.orange[700],
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

              SizedBox(height: 16),

              // Match Stats
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match Stats',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'Total Spots',
                              '${match.spots}',
                              Icons.group,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'Confirmed',
                              '${match.confirmedPlayers}',
                              Icons.check_circle,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'Available',
                              '${match.availableSpots}',
                              Icons.event_available,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'Expenses',
                              '₹${match.totalExpensed.toStringAsFixed(0)}',
                              Icons.money,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Squad Information (if released)
              if (match.isSquadReleased && match.finalSquad != null) ...[
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sports_cricket,
                              color: AppTheme.cricketGreen,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Final Squad',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.cricketGreen,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Captain and Wicket Keeper
                        if (match.captain != null ||
                            match.wicketKeeper != null) ...[
                          Row(
                            children: [
                              if (match.captain != null) ...[
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.blue.withOpacity(0.2)
                                          : Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.star, color: Colors.blue),
                                        SizedBox(height: 4),
                                        Text(
                                          'Captain',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          match.captain!.user?.name ??
                                              'Unknown',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],
                              if (match.wicketKeeper != null) ...[
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.sports_baseball,
                                          color: Colors.green,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Wicket Keeper',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.green,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          match.wicketKeeper!.user?.name ??
                                              'Unknown',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 16),
                        ],

                        // Squad List
                        Text(
                          'Squad Members (${match.finalSquad!.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...match.finalSquad!
                            .map((player) => _buildSquadMember(player)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Current RSVP Status
              if (userRsvp != null)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your RSVP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              _getRSVPIcon(userRsvp.status),
                              color: _getRSVPColor(userRsvp.status),
                            ),
                            SizedBox(width: 8),
                            Text(
                              _getRSVPText(userRsvp.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: _getRSVPColor(userRsvp.status),
                              ),
                            ),
                          ],
                        ),
                        if (userRsvp.selectedRole != null) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.sports_cricket,
                                size: 16,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 8),
                              Text('Preferred role: ${userRsvp.selectedRole}'),
                            ],
                          ),
                        ],
                        if (userRsvp.notes != null &&
                            userRsvp.notes!.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.note, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Expanded(child: Text('Notes: ${userRsvp.notes}')),
                            ],
                          ),
                        ],
                        if (userRsvp.isConfirmed) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.withOpacity(0.2)
                          : Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'You are confirmed for this match!',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.green.shade300
                                        : Colors.green[700],
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (userRsvp.waitlistPosition != null) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'You are #${userRsvp.waitlistPosition} on the waitlist',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.orange.shade300
                                        : Colors.orange[700],
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

              SizedBox(height: 16),

              // RSVP Form (if can RSVP)
              if (match.canRsvp && !match.isCancelled)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userRsvp != null
                              ? 'Update Your RSVP'
                              : 'RSVP for this Match',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Preferred Role',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          items: _roles.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedRole = value!),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Notes (Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Any additional notes...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        if (_isLoading)
                          Center(child: CircularProgressIndicator())
                        else
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _submitRSVP('YES'),
                                  icon: Icon(Icons.check, color: Colors.white),
                                  label: Text(
                                    'Yes',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _submitRSVP('MAYBE'),
                                  icon: Icon(Icons.help, color: Colors.white),
                                  label: Text(
                                    'Maybe',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _submitRSVP('NO'),
                                  icon: Icon(Icons.close, color: Colors.white),
                                  label: Text(
                                    'No',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

              SizedBox(height: 16),

              // RSVP Lists - Remove since we're not getting them from this API
              // The /matches/[id] API doesn't return RSVP lists, only user's own RSVP
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSquadMember(MatchRSVP player) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (player.user?.profilePicture != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                player.user!.profilePicture!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.cricketGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: 16),
                  );
                },
              ),
            )
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.cricketGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.user?.name ?? 'Unknown User',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
                if (player.selectedRole != null) ...[
                  SizedBox(height: 2),
                  Text(
                    player.selectedRole!,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ],
            ),
          ),
          // Special role indicators
          if (player.isCaptain)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'C',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          if (player.isWicketKeeper) ...[
            if (player.isCaptain) SizedBox(width: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'WK',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.cricketGreen),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
          textAlign: TextAlign.center,
        ),
      ],
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
