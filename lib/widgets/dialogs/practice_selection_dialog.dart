import 'package:flutter/material.dart';
import '../../models/match.dart';
import '../../services/match_service.dart';

/// Dialog for selecting existing practice or creating new practice
class PracticeSelectionDialog extends StatefulWidget {
  final String clubId;
  final Function(MatchListItem practice) onExistingPracticeSelected;
  final VoidCallback onCreateNewPractice;

  const PracticeSelectionDialog({
    super.key,
    required this.clubId,
    required this.onExistingPracticeSelected,
    required this.onCreateNewPractice,
  });

  @override
  State<PracticeSelectionDialog> createState() => _PracticeSelectionDialogState();
}

class _PracticeSelectionDialogState extends State<PracticeSelectionDialog> {
  List<MatchListItem> _practices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPractices();
  }

  Future<void> _loadPractices() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch matches for the club and filter for practice sessions
      final allMatches = await MatchService.getMatches(
        clubId: widget.clubId,
        upcomingOnly: true,
      );

      // Filter for practice sessions only (assuming type field exists)
      final practices = allMatches.where((match) => 
        match.type?.toLowerCase() == 'practice' || 
        match.opponent?.toLowerCase().contains('practice') == true
      ).toList();
      
      setState(() {
        _practices = practices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load practice sessions';
        _isLoading = false;
      });
      print('❌ Error loading practices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Practice Session',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Create New Practice Button
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onCreateNewPractice();
                  },
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text(
                    'Create New Practice Session',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4CAF50),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),

            // Divider
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Or select existing practice',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),

            // Practice List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red, size: 48),
                              SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPractices,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _practices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.fitness_center,
                                    color: Colors.grey[400],
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No upcoming practice sessions',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Create a new practice session to get started',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: _practices.length,
                              itemBuilder: (context, index) {
                                final practice = _practices[index];
                                return _buildPracticeItem(practice);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeItem(MatchListItem practice) {
    final practiceDate = practice.matchDate;
    final dayName = _getDayName(practiceDate.weekday);
    final timeStr = '${practiceDate.hour.toString().padLeft(2, '0')}:${practiceDate.minute.toString().padLeft(2, '0')}';
    final dateStr = '${practiceDate.day}/${practiceDate.month}/${practiceDate.year}';
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          widget.onExistingPracticeSelected(practice);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Practice Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              
              // Practice Details
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      practice.opponent?.isNotEmpty == true 
                        ? practice.opponent! 
                        : 'Practice Session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            practice.location,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Date & Time
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$dayName, $timeStr',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}