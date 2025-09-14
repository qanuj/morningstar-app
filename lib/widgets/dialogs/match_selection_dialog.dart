import 'package:flutter/material.dart';
import '../../models/match.dart';
import '../../services/match_service.dart';
import '../svg_avatar.dart';

/// Dialog for admins to choose between sending existing match or creating new match
class MatchSelectionDialog extends StatefulWidget {
  final String clubId;
  final Function(MatchListItem match) onExistingMatchSelected;
  final VoidCallback onCreateNewMatch;

  const MatchSelectionDialog({
    super.key,
    required this.clubId,
    required this.onExistingMatchSelected,
    required this.onCreateNewMatch,
  });

  @override
  State<MatchSelectionDialog> createState() => _MatchSelectionDialogState();
}

class _MatchSelectionDialogState extends State<MatchSelectionDialog> {
  List<MatchListItem> _matches = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get upcoming matches for the club
      final matches = await MatchService.getMatches(
        clubId: widget.clubId,
        upcomingOnly: true,
      );
      if (mounted) {
        setState(() {
          _matches = matches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load matches: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sports_cricket,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send Match to Chat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Create New Match Option
                    _buildCreateNewOption(),
                    
                    SizedBox(height: 20),
                    
                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Existing Matches Section
                    Text(
                      'Send Existing Match',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    _buildExistingMatchesSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNewOption() {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        widget.onCreateNewMatch();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF4CAF50).withOpacity(0.1),
          border: Border.all(
            color: Color(0xFF4CAF50).withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Match',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Set up a new match and announce it',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF4CAF50),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingMatchesSection() {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            CircularProgressIndicator(
              color: Color(0xFF4CAF50),
            ),
            SizedBox(height: 12),
            Text(
              'Loading matches...',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: _loadMatches,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_matches.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.sports_cricket,
              size: 48,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
            ),
            SizedBox(height: 12),
            Text(
              'No upcoming matches found',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Create your first match to get started',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _matches.map((match) => _buildMatchItem(match)).toList(),
    );
  }

  Widget _buildMatchItem(MatchListItem match) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        widget.onExistingMatchSelected(match);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Teams display
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Home team (current club)
                  Expanded(
                    child: Column(
                      children: [
                        SVGAvatar(
                          imageUrl: match.club.logo,
                          size: 28,
                          backgroundColor: Color(0xFF4CAF50).withOpacity(0.1),
                          iconColor: Color(0xFF4CAF50),
                          fallbackIcon: Icons.sports_cricket,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 2),
                        Text(
                          match.club.name,
                          style: TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // VS
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Opponent team
                  Expanded(
                    child: Column(
                      children: [
                        SVGAvatar(
                          imageUrl: null, // No opponent logo in current model
                          size: 28,
                          backgroundColor: Color(0xFF4CAF50).withOpacity(0.1),
                          iconColor: Color(0xFF4CAF50),
                          fallbackIcon: Icons.sports_cricket,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 2),
                        Text(
                          match.opponent ?? 'TBD',
                          style: TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(width: 8),
            
            // Match details
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatMatchDate(match.matchDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    match.location.isNotEmpty ? match.location : 'Venue TBD',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            Icon(
              Icons.send,
              size: 16,
              color: Color(0xFF4CAF50),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMatchDate(DateTime? dateTime) {
    if (dateTime == null) return 'Date TBD';
    
    final now = DateTime.now();
    final difference = dateTime.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference < 7) {
      return '$difference days';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}