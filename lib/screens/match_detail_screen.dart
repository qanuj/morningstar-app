// lib/screens/match_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class MatchDetailScreen extends StatefulWidget {
  final Match match;

  MatchDetailScreen({required this.match});

  @override
  _MatchDetailScreenState createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  MatchRSVP? _currentRSVP;
  List<MatchRSVP> _allRSVPs = [];
  bool _isLoading = false;
  String _selectedRole = 'Batsman';
  final _notesController = TextEditingController();

  final List<String> _roles = [
    'Batsman',
    'Bowler', 
    'All-rounder',
    'Wicket-keeper',
    'Any position'
  ];

  @override
  void initState() {
    super.initState();
    _loadRSVPData();
  }

  Future<void> _loadRSVPData() async {
    setState(() => _isLoading = true);

    try {
      // Load current user's RSVP
      final rsvpResponse = await ApiService.get('/matches/${widget.match.id}/rsvp/my');
      if (rsvpResponse['rsvp'] != null) {
        _currentRSVP = MatchRSVP.fromJson(rsvpResponse['rsvp']);
        _selectedRole = _currentRSVP?.selectedRole ?? 'Batsman';
        _notesController.text = _currentRSVP?.notes ?? '';
      }

      // Load all RSVPs
      final allRsvpResponse = await ApiService.get('/matches/${widget.match.id}/rsvp');
      _allRSVPs = (allRsvpResponse['rsvps'] as List)
          .map((rsvp) => MatchRSVP.fromJson(rsvp))
          .toList();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load RSVP data: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _submitRSVP(String status) async {
    setState(() => _isLoading = true);

    try {
      final data = {
        'status': status,
        'selectedRole': _selectedRole,
        'notes': _notesController.text.trim(),
      };

      final response = await ApiService.post('/matches/${widget.match.id}/rsvp', data);
      _currentRSVP = MatchRSVP.fromJson(response['rsvp']);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('RSVP updated successfully')),
      );

      await _loadRSVPData(); // Reload data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update RSVP: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = widget.match.matchDate.isAfter(DateTime.now());
    final canRSVP = isUpcoming && !widget.match.isCancelled;

    return Scaffold(
      appBar: AppBar(
        title: Text('Match Details'),
        backgroundColor: AppTheme.cricketGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getMatchTypeColor(widget.match.type),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  widget.match.type.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Spacer(),
                              if (widget.match.isCancelled)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'CANCELLED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            widget.match.opponent ?? 'Practice Match',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: AppTheme.cricketGreen),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.match.location,
                                  style: TextStyle(fontSize: 16),
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
                                DateFormat('EEEE, MMM dd, yyyy • hh:mm a')
                                    .format(widget.match.matchDate),
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          if (widget.match.notes != null) ...[
                            SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    widget.match.notes!,
                                    style: TextStyle(fontSize: 14),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'Total Spots',
                              '${widget.match.spots}',
                              Icons.group,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'Confirmed',
                              '${_allRSVPs.where((r) => r.status == 'YES').length}',
                              Icons.check_circle,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'Maybe',
                              '${_allRSVPs.where((r) => r.status == 'MAYBE').length}',
                              Icons.help,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'No',
                              '${_allRSVPs.where((r) => r.status == 'NO').length}',
                              Icons.cancel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Current RSVP Status
                  if (_currentRSVP != null)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your RSVP',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  _getRSVPIcon(_currentRSVP!.status),
                                  color: _getRSVPColor(_currentRSVP!.status),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _getRSVPText(_currentRSVP!.status),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _getRSVPColor(_currentRSVP!.status),
                                  ),
                                ),
                              ],
                            ),
                            if (_currentRSVP!.selectedRole != null) ...[
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.sports_cricket, size: 16, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('Preferred role: ${_currentRSVP!.selectedRole}'),
                                ],
                              ),
                            ],
                            if (_currentRSVP!.isConfirmed) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      'You are confirmed for this match!',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_currentRSVP!.waitlistPosition != null) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.hourglass_empty, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text(
                                      'You are #${_currentRSVP!.waitlistPosition} on the waitlist',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w500,
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
                  if (canRSVP)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Your RSVP',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Preferred Role',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
                              onChanged: (value) => setState(() => _selectedRole = value!),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _submitRSVP('YES'),
                                    icon: Icon(Icons.check, color: Colors.white),
                                    label: Text('Yes', style: TextStyle(color: Colors.white)),
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
                                    label: Text('Maybe', style: TextStyle(color: Colors.white)),
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
                                    label: Text('No', style: TextStyle(color: Colors.white)),
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
                ],
              ),
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
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