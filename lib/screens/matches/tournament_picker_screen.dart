import 'package:flutter/material.dart';
import '../../services/tournament_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import 'package:intl/intl.dart';

class TournamentPickerScreen extends StatefulWidget {
  final String clubId;
  final String title;
  final Function(Tournament) onTournamentSelected;

  const TournamentPickerScreen({
    super.key,
    required this.clubId,
    required this.title,
    required this.onTournamentSelected,
  });

  @override
  State<TournamentPickerScreen> createState() => _TournamentPickerScreenState();

  // Static method to show as modal bottom sheet
  static Future<Tournament?> showTournamentPicker({
    required BuildContext context,
    required String clubId,
    required String title,
  }) async {
    return await showModalBottomSheet<Tournament>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TournamentPickerModal(
        clubId: clubId,
        title: title,
      ),
    );
  }
}

// New Modal Widget for Tournament Picker
class TournamentPickerModal extends StatefulWidget {
  final String clubId;
  final String title;

  const TournamentPickerModal({
    super.key,
    required this.clubId,
    required this.title,
  });

  @override
  State<TournamentPickerModal> createState() => _TournamentPickerModalState();
}

class _TournamentPickerScreenState extends State<TournamentPickerScreen> {
  List<Tournament> _tournaments = [];
  List<Tournament> _filteredTournaments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    try {
      setState(() => _isLoading = true);
      final tournaments = await TournamentService.getClubTournaments(widget.clubId);
      setState(() {
        _tournaments = tournaments;
        _filteredTournaments = tournaments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tournaments: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterTournaments(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTournaments = _tournaments;
      } else {
        _filteredTournaments = _tournaments
            .where((tournament) =>
                tournament.name.toLowerCase().contains(query.toLowerCase()) ||
                tournament.location.toLowerCase().contains(query.toLowerCase()) ||
                tournament.city.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: widget.title,
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterTournaments,
              decoration: InputDecoration(
                hintText: 'Search tournaments...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).primaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Tournament List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : _filteredTournaments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredTournaments.length,
                        itemBuilder: (context, index) {
                          final tournament = _filteredTournaments[index];
                          return _buildTournamentCard(tournament);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No tournaments found' : 'No tournaments available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Try adjusting your search terms'
                : 'Create a tournament first to schedule matches',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _filterTournaments('');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    final now = DateTime.now();
    final isUpcoming = tournament.startDate.isAfter(now);
    final isOngoing = tournament.startDate.isBefore(now) && tournament.endDate.isAfter(now);
    final isPast = tournament.endDate.isBefore(now);

    Color statusColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    String statusText = 'Past';
    IconData statusIcon = Icons.history;

    if (isUpcoming) {
      statusColor = Theme.of(context).primaryColor;
      statusText = 'Upcoming';
      statusIcon = Icons.schedule;
    } else if (isOngoing) {
      statusColor = Colors.green;
      statusText = 'Live';
      statusIcon = Icons.play_circle_filled;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 8,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          widget.onTournamentSelected(tournament);
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Tournament Logo/Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                child: Center(
                  child: Icon(
                    Icons.emoji_events,
                    size: 28,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Tournament Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tournament Name and Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tournament.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                size: 12,
                                color: statusColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),

                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${tournament.venue.isNotEmpty ? tournament.venue + ', ' : ''}${tournament.city}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),

                    // Date Range
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${DateFormat('MMM dd').format(tournament.startDate)} - ${DateFormat('MMM dd, yyyy').format(tournament.endDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TournamentPickerModalState extends State<TournamentPickerModal> {
  List<Tournament> _tournaments = [];
  List<Tournament> _filteredTournaments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    try {
      setState(() => _isLoading = true);
      final tournaments = await TournamentService.getClubTournaments(widget.clubId);
      setState(() {
        _tournaments = tournaments;
        _filteredTournaments = tournaments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tournaments: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterTournaments(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTournaments = _tournaments;
      } else {
        _filteredTournaments = _tournaments
            .where((tournament) =>
                tournament.name.toLowerCase().contains(query.toLowerCase()) ||
                tournament.location.toLowerCase().contains(query.toLowerCase()) ||
                tournament.city.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No tournaments found' : 'No tournaments available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Create a tournament first to schedule matches',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _filterTournaments('');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    final now = DateTime.now();
    final isUpcoming = tournament.startDate.isAfter(now);
    final isOngoing = tournament.startDate.isBefore(now) && tournament.endDate.isAfter(now);
    final isPast = tournament.endDate.isBefore(now);

    Color statusColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    String statusText = 'Past';
    IconData statusIcon = Icons.history;

    if (isUpcoming) {
      statusColor = Theme.of(context).primaryColor;
      statusText = 'Upcoming';
      statusIcon = Icons.schedule;
    } else if (isOngoing) {
      statusColor = Colors.green;
      statusText = 'Live';
      statusIcon = Icons.play_circle_filled;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 8,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop(tournament);
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Tournament Logo/Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                child: Center(
                  child: Icon(
                    Icons.emoji_events,
                    size: 28,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Tournament Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tournament Name and Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tournament.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                size: 12,
                                color: statusColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),

                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${tournament.venue.isNotEmpty ? tournament.venue + ', ' : ''}${tournament.city}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),

                    // Date Range
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${DateFormat('MMM dd').format(tournament.startDate)} - ${DateFormat('MMM dd, yyyy').format(tournament.endDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
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
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterTournaments,
              decoration: InputDecoration(
                hintText: 'Search tournaments...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).primaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Tournament List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : _filteredTournaments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filteredTournaments.length,
                        itemBuilder: (context, index) {
                          final tournament = _filteredTournaments[index];
                          return _buildTournamentCard(tournament);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}