import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/poll.dart';
import '../../services/poll_service.dart';
import '../../widgets/svg_avatar.dart';
import '../../screens/polls/create_poll_screen.dart';

/// Shared poll picker component that can be used from any context
/// Can either pick existing polls or trigger creation of new polls
class PollPicker extends StatefulWidget {
  final String clubId;
  final ValueChanged<Poll> onExistingPollSelected;
  final VoidCallback onCreateNewPoll;
  final String title;
  final String createNewText;
  final String createNewDescription;

  // Static method to show as modal bottom sheet and return selected poll
  static Future<Poll?> showPollPicker({
    required BuildContext context,
    required String clubId,
    String title = 'Send Poll to Chat',
  }) async {
    return await showModalBottomSheet<Poll>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: PollPickerModal(
          clubId: clubId,
          title: title,
        ),
      ),
    );
  }

  const PollPicker({
    super.key,
    required this.clubId,
    required this.onExistingPollSelected,
    required this.onCreateNewPoll,
    this.title = 'Send Poll to Chat',
    this.createNewText = 'Create New Poll',
    this.createNewDescription = 'Open the poll creation screen to set up a new poll.',
  });

  @override
  State<PollPicker> createState() => _PollPickerState();
}

class _PollPickerState extends State<PollPicker> {
  final List<Poll> _polls = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final polls = await PollService.getPolls(
        clubId: widget.clubId,
        includeExpired: false,
      );
      if (mounted) {
        setState(() {
          _polls
            ..clear()
            ..addAll(polls);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load polls';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPolls,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCreateNewCard(theme),
              const SizedBox(height: 24),
              Text(
                'Existing Polls',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildPollsContent(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateNewCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pop();
          widget.onCreateNewPoll();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.createNewText,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.createNewDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollsContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadPolls,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_polls.isEmpty) {
      return Center(
        child: Text(
          'No active polls found for this club.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
        ),
      );
    }

    return ListView.separated(
      itemCount: _polls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final poll = _polls[index];
        return _PollListTile(
          poll: poll,
          onTap: () {
            Navigator.of(context).pop();
            widget.onExistingPollSelected(poll);
          },
        );
      },
    );
  }
}

class _PollListTile extends StatelessWidget {
  final Poll poll;
  final VoidCallback onTap;

  const _PollListTile({required this.poll, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localCreated = poll.createdAt.toLocal();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.poll,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.question,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by ${poll.createdBy.name}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${poll.options.length} options • ${poll.totalVotes} votes',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Created ${DateFormat('MMM d, h:mma').format(localCreated).toLowerCase()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  if (poll.expiresAt != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Expires ${DateFormat('MMM d').format(poll.expiresAt!.toLocal())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
              if (poll.hasVoted) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Voted',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
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
    );
  }
}

/// Modal wrapper for PollPicker that handles navigation and returns selected poll
class PollPickerModal extends StatefulWidget {
  final String clubId;
  final String title;

  const PollPickerModal({
    super.key,
    required this.clubId,
    required this.title,
  });

  @override
  State<PollPickerModal> createState() => _PollPickerModalState();
}

class _PollPickerModalState extends State<PollPickerModal> {
  final List<Poll> _polls = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final polls = await PollService.getPolls(
        clubId: widget.clubId,
        includeExpired: false,
      );
      if (mounted) {
        setState(() {
          _polls
            ..clear()
            ..addAll(polls);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load polls';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewPoll() async {
    // Navigate to create poll screen and await result
    final result = await Navigator.of(context).push<Poll>(
      MaterialPageRoute(
        builder: (context) => CreatePollScreen(
          clubId: widget.clubId,
          onPollCreated: (poll) {
            // Just pop this screen, the poll will be returned via the route result
            Navigator.of(context).pop(poll);
          },
        ),
      ),
    );

    // If poll was created, return it to close the modal and pass it back
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPolls,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCreateNewCard(theme),
              const SizedBox(height: 24),
              Text(
                'Existing Polls',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildPollsContent(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateNewCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _createNewPoll,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Poll',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Open the poll creation screen to set up a new poll.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollsContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadPolls,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_polls.isEmpty) {
      return Center(
        child: Text(
          'No active polls found for this club.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
        ),
      );
    }

    return ListView.separated(
      itemCount: _polls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final poll = _polls[index];
        return _PollListTile(
          poll: poll,
          onTap: () {
            // Return the selected poll
            Navigator.of(context).pop(poll);
          },
        );
      },
    );
  }
}