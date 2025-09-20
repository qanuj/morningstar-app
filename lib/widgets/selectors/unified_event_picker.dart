import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/match.dart';
import '../../services/match_service.dart';
import '../../services/practice_service.dart';
import '../../widgets/event_cards.dart';
import '../../widgets/custom_app_bar.dart';
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

  // Static method to show as modal bottom sheet
  static Future<MatchListItem?> showEventPicker({
    required BuildContext context,
    required String clubId,
    required EventType eventType,
  }) async {
    return await showModalBottomSheet<MatchListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UnifiedEventPickerModal(
        clubId: clubId,
        eventType: eventType,
      ),
    );
  }
}

// New Modal Widget for Unified Event Picker
class UnifiedEventPickerModal extends StatefulWidget {
  final String clubId;
  final EventType eventType;

  const UnifiedEventPickerModal({
    super.key,
    required this.clubId,
    required this.eventType,
  });

  @override
  State<UnifiedEventPickerModal> createState() => _UnifiedEventPickerModalState();
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
      appBar: DuggyAppBar(
        subtitle: _title,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: widget.eventType == EventType.match ? 'Create Match' : 'Create Practice',
            onPressed: _createNewEvent,
          ),
        ],
      ),
      body: Container(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : Colors.grey[200],
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
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
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
                      foregroundColor: theme.colorScheme.onPrimary,
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

class _UnifiedEventPickerModalState extends State<UnifiedEventPickerModal> {
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
          // Refresh the list after creation and close modal
          _loadEvents(isRefresh: true);
          Navigator.of(context).pop();
        },
      );
    } else {
      createScreen = CreatePracticeScreen(
        clubId: widget.clubId,
        onPracticeCreated: (practiceData) {
          // Refresh the list after creation and close modal
          _loadEvents(isRefresh: true);
          Navigator.of(context).pop();
        },
      );
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => createScreen),
    );
  }

  Widget _buildEventsContent() {
    if (_isLoading && _events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).primaryColor),
            SizedBox(height: 16),
            Text('Loading ${widget.eventType == EventType.match ? 'matches' : 'practices'}...'),
          ],
        ),
      );
    }

    if (_error != null && _events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadEvents(isRefresh: true),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _headerIcon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                  : Theme.of(context).textTheme.bodySmall?.color,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              _emptyMessage,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createNewEvent,
              icon: Icon(Icons.add),
              label: Text(widget.eventType == EventType.match ? 'Create Match' : 'Create Practice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  ? CircularProgressIndicator(color: Theme.of(context).primaryColor)
                  : SizedBox.shrink(),
            ),
          );
        }

        final event = _events[index];
        return widget.eventType == EventType.match
            ? MatchEventCard(
                match: event,
                onTap: () {
                  Navigator.of(context).pop(event);
                },
              )
            : PracticeEventCard(
                practice: event,
                onTap: () {
                  Navigator.of(context).pop(event);
                },
              );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black87
            : Color(0xFFF5F5F5),
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
                Icon(
                  _headerIcon,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  tooltip: widget.eventType == EventType.match ? 'Create Match' : 'Create Practice',
                  onPressed: _createNewEvent,
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => _loadEvents(isRefresh: true),
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Content Area
          Expanded(
            child: _buildEventsContent(),
          ),
        ],
      ),
    );
  }
}