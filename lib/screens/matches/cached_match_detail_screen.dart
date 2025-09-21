import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club_message.dart';
import '../../widgets/cached_media_image.dart';

/// Cached match detail screen that uses only message data, no API calls
class CachedMatchDetailScreen extends StatelessWidget {
  final ClubMessage message;
  final Map<String, dynamic> matchData;

  const CachedMatchDetailScreen({
    super.key,
    required this.message,
    required this.matchData,
  });

  bool get _isPractice => message.messageType == 'practice';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPractice ? 'Practice Details' : 'Match Details'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            if (_getCancellationStatus())
              _buildCancellationCard(context)
            else
              _buildStatusCard(context),

            const SizedBox(height: 24),

            // Teams section (only for matches)
            if (!_isPractice) ...[
              _buildTeamsSection(context),
              const SizedBox(height: 24),
            ],

            // Practice header (only for practices)
            if (_isPractice) ...[
              _buildPracticeHeader(context),
              const SizedBox(height: 24),
            ],

            // Match/Practice information
            _buildInfoSection(context),

            const SizedBox(height: 24),

            // RSVP section
            if (!_getCancellationStatus()) _buildRSVPSection(context),

            const SizedBox(height: 24),

            // Additional details
            if (message.content.isNotEmpty) ...[
              _buildDescriptionSection(context),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationCard(BuildContext context) {
    final theme = Theme.of(context);
    final reason = _getCancellationReason();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Text(
                '${_isPractice ? 'Practice' : 'Match'} Cancelled',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Reason: $reason',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _isPractice ? Icons.sports : Icons.sports_cricket,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            _isPractice ? 'Practice Session' : 'Match',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsSection(BuildContext context) {
    final homeTeam = _safeMapFromData(matchData['homeTeam']) ?? {};
    final opponentTeam = _safeMapFromData(matchData['opponentTeam']) ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teams',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTeamInfo(context, homeTeam, 'Home')),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: _buildTeamInfo(context, opponentTeam, 'Away')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamInfo(BuildContext context, Map<String, dynamic> team, String label) {
    final name = team['name']?.toString() ?? '$label Team';
    final logoUrl = team['logo']?.toString();

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: logoUrl != null && logoUrl.isNotEmpty
              ? CachedAvatarImage(
                  imageUrl: logoUrl,
                  size: 80,
                  fallbackText: name,
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPracticeHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.sports,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Text(
              'Practice Session',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoItems(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItems(BuildContext context) {
    final items = <Widget>[];

    // Date and time
    final dateTime = _getDateTime();
    if (dateTime != null) {
      items.add(_buildInfoItem(
        context,
        icon: Icons.calendar_today,
        label: 'Date & Time',
        value: _formatDateTime(dateTime),
      ));
    }

    // Venue
    final venue = _getVenue();
    if (venue.isNotEmpty) {
      items.add(_buildInfoItem(
        context,
        icon: Icons.location_on,
        label: 'Venue',
        value: venue,
      ));
    }

    // Duration (for practices)
    if (_isPractice) {
      final duration = matchData['duration']?.toString();
      if (duration != null && duration.isNotEmpty) {
        items.add(_buildInfoItem(
          context,
          icon: Icons.timer,
          label: 'Duration',
          value: duration,
        ));
      }

      // Participants (for practices)
      final maxParticipants = matchData['maxParticipants'] as int? ?? 0;
      final confirmedPlayers = matchData['confirmedPlayers'] as int? ?? 0;
      if (maxParticipants > 0) {
        items.add(_buildInfoItem(
          context,
          icon: Icons.group,
          label: 'Participants',
          value: '$confirmedPlayers / $maxParticipants',
        ));
      }
    }

    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: item,
      )).toList(),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRSVPSection(BuildContext context) {
    final counts = _getStatusCounts();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RSVP Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildRSVPCount(context, 'In', counts['YES'] ?? 0, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildRSVPCount(context, 'Out', counts['NO'] ?? 0, Colors.red)),
                const SizedBox(width: 12),
                Expanded(child: _buildRSVPCount(context, 'Maybe', counts['MAYBE'] ?? 0, Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRSVPCount(BuildContext context, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message.content,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Map<String, dynamic>? _safeMapFromData(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    } else if (value is String && value.isNotEmpty) {
      return {'name': value};
    }
    return null;
  }

  DateTime? _getDateTime() {
    final dateTimeStr = matchData['dateTime']?.toString();
    if (dateTimeStr != null) {
      return DateTime.tryParse(dateTimeStr);
    }

    // For practices, try to combine date and time
    if (_isPractice) {
      final date = matchData['date']?.toString();
      final time = matchData['time']?.toString();
      if (date != null && time != null) {
        try {
          return DateTime.parse('${date}T$time:00');
        } catch (e) {
          return null;
        }
      }
    }

    return null;
  }

  String _getVenue() {
    final venue = _safeMapFromData(matchData['venue']);
    if (venue != null) {
      final name = venue['name']?.toString() ?? '';
      final address = venue['address']?.toString();
      if (address != null && address.isNotEmpty && address != name) {
        return '$name, $address';
      }
      return name;
    }

    // Fallback to direct venue string
    return matchData['venue']?.toString() ?? '';
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(local)} at ${timeFormat.format(local)}';
  }

  Map<String, int> _getStatusCounts() {
    final counts = <String, int>{'YES': 0, 'NO': 0, 'MAYBE': 0};

    // Try to get counts from statusCounts field
    final statusCounts = matchData['statusCounts'];
    if (statusCounts is Map) {
      statusCounts.forEach((key, value) {
        final upperKey = key.toString().toUpperCase();
        if (counts.containsKey(upperKey)) {
          if (value is num) {
            counts[upperKey] = value.toInt();
          } else {
            final parsed = int.tryParse(value.toString());
            if (parsed != null) {
              counts[upperKey] = parsed;
            }
          }
        }
      });
    }

    // Try to get counts from aggregate counts
    final aggregate = matchData['counts'];
    if (aggregate is Map<String, dynamic>) {
      counts['YES'] = ((aggregate['confirmed'] as num?)?.toInt() ?? 0) +
          ((aggregate['waitlisted'] as num?)?.toInt() ?? 0);
      counts['NO'] = (aggregate['declined'] as num?)?.toInt() ?? 0;
      counts['MAYBE'] = (aggregate['maybe'] as num?)?.toInt() ?? 0;
    }

    // For practices, use participant counts
    if (_isPractice) {
      final confirmedPlayers = matchData['confirmedPlayers'] as int? ?? 0;
      counts['YES'] = confirmedPlayers;
    }

    counts.updateAll((key, value) => value < 0 ? 0 : value);
    return counts;
  }

  bool _getCancellationStatus() {
    if (matchData['isCancelled'] == true) return true;
    if (matchData['practice'] != null && matchData['practice']['isCancelled'] == true) return true;
    if (matchData['match'] != null && matchData['match']['isCancelled'] == true) return true;
    return false;
  }

  String? _getCancellationReason() {
    if (matchData['cancellationReason'] is String && matchData['cancellationReason'].toString().isNotEmpty) {
      return matchData['cancellationReason'].toString();
    }
    if (matchData['practice'] != null && matchData['practice']['cancellationReason'] is String) {
      return matchData['practice']['cancellationReason'].toString();
    }
    if (matchData['match'] != null && matchData['match']['cancellationReason'] is String) {
      return matchData['match']['cancellationReason'].toString();
    }
    return null;
  }
}