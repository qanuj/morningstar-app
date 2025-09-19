import 'package:flutter/material.dart';
import '../../models/match.dart';
import '../../services/practice_service.dart';

/// Shared practice picker component that can be used from any context
/// Can either pick existing practices or trigger creation of new practices
class PracticePicker extends StatefulWidget {
  final String clubId;
  final Function(MatchListItem practice) onExistingPracticeSelected;
  final VoidCallback onCreateNewPractice;
  final String title;
  final String createNewText;
  final String createNewDescription;

  const PracticePicker({
    super.key,
    required this.clubId,
    required this.onExistingPracticeSelected,
    required this.onCreateNewPractice,
    this.title = 'Select Practice Session',
    this.createNewText = 'Create New Practice Session',
    this.createNewDescription = 'Set up a new training session for the team',
  });

  @override
  State<PracticePicker> createState() => _PracticePickerState();
}

class _PracticePickerState extends State<PracticePicker> {
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

      // Fetch practice sessions using the dedicated practice API
      final practices = await PracticeService.getPracticeSessions(
        clubId: widget.clubId,
        upcomingOnly: true,
        limit: 20,
      );

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.fitness_center, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              widget.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPractices,
          ),
        ],
      ),
      body: Column(
        children: [

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
                  widget.createNewText,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
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
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
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
                                    widget.createNewDescription,
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: Theme.of(context).colorScheme.primary,
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
                        color: Theme.of(context).colorScheme.primary,
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