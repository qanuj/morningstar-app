import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/match.dart';
import '../widgets/svg_avatar.dart';

/// Helper function to create team abbreviations
String _getTeamAbbreviation(String teamName) {
  if (teamName.length <= 12) {
    return teamName;
  }

  // Split the name into words
  final words = teamName.split(' ');

  if (words.length == 1) {
    // Single word: take first 3 characters + last character
    return teamName.length >= 4
        ? '${teamName.substring(0, 3)}${teamName.substring(teamName.length - 1)}'
              .toUpperCase()
        : teamName.substring(0, 3).toUpperCase();
  } else if (words.length >= 2) {
    // Multiple words: take first letter of each word
    String abbreviation = '';
    for (int i = 0; i < words.length && abbreviation.length < 4; i++) {
      if (words[i].isNotEmpty) {
        abbreviation += words[i][0].toUpperCase();
      }
    }
    return abbreviation;
  }

  // Fallback: first 3 characters
  return teamName.substring(0, 3).toUpperCase();
}

/// Reusable match card with compact three-column layout
class MatchEventCard extends StatelessWidget {
  final MatchListItem match;
  final VoidCallback? onTap;
  final bool isUpcoming;

  const MatchEventCard({
    super.key,
    required this.match,
    this.onTap,
    this.isUpcoming = true,
  });


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localDate = match.matchDate.toLocal();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Home team logo (1st column)
                  _TeamLogo(
                    logoUrl: match.team?.logo ?? match.club.logo,
                    fallbackColor: theme.colorScheme.primary,
                    size: 48,
                    hasRSVP: match.userRsvp != null &&
                            match.userRsvp!.teamId == match.team?.id,
                    rsvpStatus: match.userRsvp?.status,
                    isConfirmed: match.userRsvp?.isConfirmed ?? false,
                  ),

                  const SizedBox(width: 12),

                  // Match info (center column)
                  Expanded(
                    child: Column(
                      children: [
                        // VS with team names
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getTeamAbbreviation(
                                match.team?.name ?? match.club.name,
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'VS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onError,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Text(
                              _getTeamAbbreviation(
                                match.opponentTeam?.name ??
                                    match.opponent ??
                                    'TBD',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Date and time
                        Text(
                          DateFormat(
                            'EEE dd MMM, yyyy \'AT\' h:mm a',
                          ).format(localDate).toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 4),

                        // Location
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                match.location.isNotEmpty
                                    ? match.location
                                    : 'Venue TBD',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Away team logo (3rd column)
                  _TeamLogo(
                    logoUrl: match.opponentTeam?.logo,
                    fallbackColor: theme.colorScheme.secondary,
                    size: 48,
                    hasRSVP: match.userRsvp != null &&
                            match.userRsvp!.teamId == match.opponentTeam?.id,
                    rsvpStatus: match.userRsvp?.status,
                    isConfirmed: match.userRsvp?.isConfirmed ?? false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable practice card with horizontal logo+info layout
class PracticeEventCard extends StatelessWidget {
  final MatchListItem practice;
  final VoidCallback? onTap;

  const PracticeEventCard({super.key, required this.practice, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final practiceDate = practice.matchDate;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Club logo on left
                  _TeamLogo(
                    logoUrl: practice.club.logo,
                    fallbackColor: theme.colorScheme.primary,
                    size: 48,
                    hasRSVP: practice.userRsvp != null,
                    rsvpStatus: practice.userRsvp?.status,
                    isConfirmed: practice.userRsvp?.isConfirmed ?? false,
                  ),

                  const SizedBox(width: 12),

                  // All info in center column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Club name
                        Text(
                          practice.club.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 4),

                        // Date and time
                        Text(
                          DateFormat(
                            'EEE dd MMM, yyyy \'AT\' h:mm a',
                          ).format(practiceDate).toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 4),

                        // Location
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                practice.location.isNotEmpty
                                    ? practice.location
                                    : 'Venue TBD',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Duration on right side
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '2 Hours', // Default duration - could be made dynamic
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(Icons.access_time, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // RSVP indicator badge (top-right corner)
          if (practice.userRsvp != null)
            Positioned(
              top: 8,
              right: 8,
              child: _RSVPIndicator(
                status: practice.userRsvp!.status,
                isConfirmed: practice.userRsvp!.isConfirmed,
                waitlistPosition: practice.userRsvp!.waitlistPosition,
              ),
            ),
        ],
      ),
    );
  }
}

/// RSVP Status indicator badge
class _RSVPIndicator extends StatelessWidget {
  final String status;
  final bool isConfirmed;
  final int? waitlistPosition;

  const _RSVPIndicator({
    required this.status,
    required this.isConfirmed,
    this.waitlistPosition,
  });

  Color _getStatusColor() {
    if (waitlistPosition != null) {
      return Colors.orange; // Waitlisted
    }

    switch (status.toUpperCase()) {
      case 'YES':
        return isConfirmed ? Colors.green : Colors.orange;
      case 'NO':
        return Colors.red;
      case 'MAYBE':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (waitlistPosition != null) {
      return Icons.schedule; // Clock icon for waitlist
    }

    switch (status.toUpperCase()) {
      case 'YES':
        return isConfirmed ? Icons.check_circle : Icons.schedule;
      case 'NO':
        return Icons.cancel;
      case 'MAYBE':
        return Icons.help;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText() {
    if (waitlistPosition != null) {
      return '#$waitlistPosition';
    }

    switch (status.toUpperCase()) {
      case 'YES':
        return isConfirmed ? '✓' : '●';
      case 'NO':
        return '✗';
      case 'MAYBE':
        return '?';
      default:
        return '?';
    }
  }

  String _getTooltip() {
    if (waitlistPosition != null) {
      return 'Waitlisted (#$waitlistPosition)';
    }

    switch (status.toUpperCase()) {
      case 'YES':
        return isConfirmed ? 'Confirmed attendance' : 'Pending confirmation';
      case 'NO':
        return 'Not attending';
      case 'MAYBE':
        return 'Maybe attending';
      default:
        return 'RSVP status';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

    return Tooltip(
      message: _getTooltip(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getStatusIcon(), color: Colors.white, size: 8),
            if (waitlistPosition != null) ...[
              const SizedBox(width: 2),
              Text(
                '#$waitlistPosition',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Team/Club logo widget
class _TeamLogo extends StatelessWidget {
  final String? logoUrl;
  final Color fallbackColor;
  final double size;
  final bool hasRSVP;
  final String? rsvpStatus;
  final bool isConfirmed;

  const _TeamLogo({
    this.logoUrl,
    required this.fallbackColor,
    this.size = 64,
    this.hasRSVP = false,
    this.rsvpStatus,
    this.isConfirmed = false,
  });

  Color _getRSVPBorderColor() {
    if (!hasRSVP || rsvpStatus == null) return Colors.transparent;

    switch (rsvpStatus!.toUpperCase()) {
      case 'YES':
        return isConfirmed ? Colors.green : Colors.orange;
      case 'NO':
        return Colors.red;
      case 'MAYBE':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getRSVPBorderColor();
    final hasBorder = hasRSVP && borderColor != Colors.transparent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withOpacity(0.12),
        shape: BoxShape.circle,
        border: hasBorder
          ? Border.all(color: borderColor, width: 3)
          : null,
        boxShadow: hasBorder ? [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ] : null,
      ),
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? ClipOval(
              child: SVGAvatar(
                imageUrl: logoUrl!,
                size: size,
                backgroundColor: fallbackColor.withOpacity(0.12),
                iconColor: fallbackColor,
                fallbackIcon: Icons.sports_cricket,
                showBorder: false,
                fit: BoxFit.cover,
              ),
            )
          : Icon(Icons.shield_outlined, color: fallbackColor, size: size * 0.5),
    );
  }
}
