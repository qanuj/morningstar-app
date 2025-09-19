import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/match.dart';
import '../../services/match_service.dart';
import '../../services/practice_service.dart';
import '../../widgets/event_cards.dart';
import '../../screens/matches/create_match_screen.dart';
import '../../screens/practices/create_practice_screen.dart';

enum EventType { match, practice }

/// Unified selector for both matches and practices
/// Shows different UI based on event type
class UnifiedEventPicker extends StatefulWidget {
  final String clubId;
  final EventType eventType;
  final ValueChanged<MatchListItem> onEventSelected;

  const UnifiedEventPicker({
    super.key,
    required this.clubId,
    required this.eventType,
    required this.onEventSelected,
  });

  @override
  State<UnifiedEventPicker> createState() => _UnifiedEventPickerState();
}

class _UnifiedEventPickerState extends State<UnifiedEventPicker> {
  final List<MatchListItem> _events = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;
  int _currentOffset = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get _title => widget.eventType == EventType.match ? 'Select Match' : 'Select Practice Session';
  String get _emptyMessage => widget.eventType == EventType.match
      ? 'No upcoming matches found for this club.'
      : 'No upcoming practice sessions found for this club.';
  IconData get _headerIcon => widget.eventType == EventType.match ? Icons.sports_cricket : Icons.fitness_center;

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreEvents();
    }
  }

  Future<void> _loadEvents({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentOffset = 0;
        _hasMoreData = true;
        _error = null;
      });
    }

    setState(() {
      _isLoading = !isRefresh;
      _error = null;
    });

    try {
      List<MatchListItem> events;
      if (widget.eventType == EventType.match) {
        events = await MatchService.getMatches(
          clubId: widget.clubId,
          upcomingOnly: true,
          limit: _pageSize,
          offset: isRefresh ? 0 : _currentOffset,
          type: 'match',
        );
      } else {
        events = await PracticeService.getPracticeSessions(
          clubId: widget.clubId,
          upcomingOnly: true,
          limit: _pageSize,
          offset: isRefresh ? 0 : _currentOffset,
          type: 'practice',
        );
      }

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _events.clear();
            _currentOffset = 0;
          }
          _events.addAll(events);
          _hasMoreData = events.length == _pageSize;
          _currentOffset += events.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = widget.eventType == EventType.match
              ? 'Failed to load matches'
              : 'Failed to load practice sessions';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreEvents() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      List<MatchListItem> moreEvents;
      if (widget.eventType == EventType.match) {
        moreEvents = await MatchService.getMatches(
          clubId: widget.clubId,
          upcomingOnly: true,
          limit: _pageSize,
          offset: _currentOffset,
          type: 'match',
        );
      } else {
        moreEvents = await PracticeService.getPracticeSessions(
          clubId: widget.clubId,
          upcomingOnly: true,
          limit: _pageSize,
          offset: _currentOffset,
          type: 'practice',
        );
      }

      if (mounted) {
        setState(() {
          _events.addAll(moreEvents);
          _hasMoreData = moreEvents.length == _pageSize;
          _currentOffset += moreEvents.length;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
      print('❌ Error loading more events: $e');
    }
  }

  Future<void> _createNewEvent() async {
    Widget createScreen;
    if (widget.eventType == EventType.match) {
      createScreen = CreateMatchScreen(
        onMatchCreated: (match) {
          // Refresh the list after creation
          _loadEvents(isRefresh: true);
        },
      );
    } else {
      createScreen = CreatePracticeScreen(
        clubId: widget.clubId,
        onPracticeCreated: (practiceData) {
          // Refresh the list after creation
          _loadEvents(isRefresh: true);
        },
      );
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => createScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_headerIcon, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(_title),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: widget.eventType == EventType.match ? 'Create Match' : 'Create Practice',
            onPressed: _createNewEvent,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100], // Light gray background
        child: SafeArea(
          child: _buildEventsContent(theme),
        ),
      ),
    );
  }

  Widget _buildEventsContent(ThemeData theme) {
    if (_isLoading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _events.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadEvents(isRefresh: true),
        child: ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                children: [
                  Text(_error!, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _loadEvents(isRefresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadEvents(isRefresh: true),
        child: ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                children: [
                  Icon(
                    _headerIcon,
                    color: Colors.grey[400],
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _createNewEvent,
                    icon: Icon(Icons.add),
                    label: Text(widget.eventType == EventType.match ? 'Create Match' : 'Create Practice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadEvents(isRefresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _events.length + (_hasMoreData ? 1 : 0),
        separatorBuilder: (_, index) {
          if (index == _events.length - 1 && _hasMoreData) {
            return const SizedBox.shrink(); // No separator before loading indicator
          }
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          if (index == _events.length) {
            // Loading indicator at the bottom
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _isLoadingMore
                    ? CircularProgressIndicator()
                    : SizedBox.shrink(),
              ),
            );
          }

          final event = _events[index];
          return widget.eventType == EventType.match
              ? MatchEventCard(
                  match: event,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onEventSelected(event);
                  },
                )
              : PracticeEventCard(
                  practice: event,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onEventSelected(event);
                  },
                );
        },
      ),
    );
  }
}