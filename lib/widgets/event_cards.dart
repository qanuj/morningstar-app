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
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      margin: EdgeInsets.zero,
      child: InkWell(
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
              ),

              const SizedBox(width: 12),

              // Match info (center column)
              Expanded(
                child: Column(
                  children: [
                    // VS with team names
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _getTeamAbbreviation(
                              match.team?.name ?? match.club.name,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' VS ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              letterSpacing: 0.8,
                            ),
                          ),
                          TextSpan(
                            text: _getTeamAbbreviation(
                              match.opponentTeam?.name ??
                                  match.opponent ??
                                  'TBD',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
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
                        Icon(
                          Icons.location_on,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            match.location.isNotEmpty
                                ? match.location
                                : 'Venue TBD',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
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
              ),
            ],
          ),
        ),
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
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      margin: EdgeInsets.zero,
      child: InkWell(
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
                        Icon(
                          Icons.location_on,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            practice.location.isNotEmpty
                                ? practice.location
                                : 'Venue TBD',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
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
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.access_time,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
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

  const _TeamLogo({this.logoUrl, required this.fallbackColor, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? ClipOval(
              child: SVGAvatar(
                imageUrl: logoUrl!,
                size: size,
                backgroundColor: Colors.transparent,
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
