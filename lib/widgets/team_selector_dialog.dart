import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../widgets/svg_avatar.dart';

class TeamSelectorDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Function(Team team)? onTeamSelected;
  final Function(List<Team> teams)? onMultipleTeamsSelected;
  final bool Function(Team team)? filterTeams;
  final bool showClubName;
  final bool multiSelect;
  final List<Team>? preSelectedTeams;

  const TeamSelectorDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.onTeamSelected,
    this.onMultipleTeamsSelected,
    this.filterTeams,
    this.showClubName = true,
    this.multiSelect = false,
    this.preSelectedTeams,
  }) : assert(
          (!multiSelect && onTeamSelected != null) || 
          (multiSelect && onMultipleTeamsSelected != null),
          'Single select requires onTeamSelected, multi-select requires onMultipleTeamsSelected',
        );

  @override
  State<TeamSelectorDialog> createState() => _TeamSelectorDialogState();
}

class _TeamSelectorDialogState extends State<TeamSelectorDialog> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedTeamIds;
  List<Team> _allTeams = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedTeamIds = widget.preSelectedTeams?.map((team) => team.id).toSet() ?? {};
    _loadTeams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load both user teams and opponent teams
      final List<Team> userTeams = await TeamService.getUserTeams();
      final List<Team> opponentTeams = await TeamService.getOpponentTeams();
      
      setState(() {
        _allTeams = [...userTeams, ...opponentTeams];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleTeamSelection(Team team) {
    setState(() {
      if (_selectedTeamIds.contains(team.id)) {
        _selectedTeamIds.remove(team.id);
      } else {
        _selectedTeamIds.add(team.id);
      }
    });
  }

  List<Team> _getSelectedTeams() {
    return _allTeams
        .where((team) => _selectedTeamIds.contains(team.id))
        .toList();
  }

  List<Team> _getFilteredTeams() {
    var teams = _allTeams;

    // Apply custom filter if provided
    if (widget.filterTeams != null) {
      teams = teams.where((team) => widget.filterTeams!(team)).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      teams = teams
          .where(
            (team) => 
                team.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (team.club?.name.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                team.sport.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (team.city?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false),
          )
          .toList();
    }

    return teams;
  }

  Widget _buildTeamTile(Team team) {
    final isSelected = _selectedTeamIds.contains(team.id);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.multiSelect) {
            _toggleTeamSelection(team);
          } else {
            Navigator.of(context).pop();
            widget.onTeamSelected!(team);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          decoration: widget.multiSelect && isSelected
              ? BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 4,
                    ),
                  ),
                )
              : null,
          child: Row(
            children: [
              // Checkbox for multi-select
              if (widget.multiSelect) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleTeamSelection(team);
                  },
                  activeColor: Theme.of(context).primaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                SizedBox(width: 12),
              ],
              
              // Team avatar
              Stack(
                children: [
                  SVGAvatar(
                    imageUrl: team.logo,
                    size: 50,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    fallbackIcon: Icons.sports_cricket,
                    iconSize: 28,
                    child: team.logo == null
                        ? Text(
                            team.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  // Verified Badge
                  if (team.isVerified)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    ),
                  // Primary team badge
                  if (team.isPrimary)
                    Positioned(
                      left: -2,
                      top: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(width: 16),

              // Team info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).textTheme.titleLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 4),

                    Row(
                      children: [
                        // Sport
                        Icon(
                          Icons.sports,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          team.sport,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        if (widget.showClubName && team.club != null) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              team.club!.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (team.city != null) ...[
                      SizedBox(height: 2),
                      Text(
                        team.city!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow indicator (only for single select)
              if (!widget.multiSelect)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTeams = _getFilteredTeams();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.multiSelect ? Icons.checklist : Icons.sports_cricket,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                if (widget.multiSelect && _selectedTeamIds.isNotEmpty)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_selectedTeamIds.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (widget.subtitle != null) ...[
                              SizedBox(height: 4),
                              Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.multiSelect) ...[
                        if (_selectedTeamIds.isNotEmpty) ...[
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedTeamIds.clear());
                            },
                            child: Text(
                              'Clear',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                        TextButton(
                          onPressed: _selectedTeamIds.isEmpty 
                              ? null 
                              : () {
                                  Navigator.of(context).pop();
                                  final selectedTeams = _getSelectedTeams();
                                  widget.onMultipleTeamsSelected!(selectedTeams);
                                },
                          child: Text(
                            'Done',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),

                  // Search bar
                  if (!_isLoading && filteredTeams.length > 3) ...[
                    SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search teams...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[500],
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Content
            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading teams...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            else if (_error != null)
              Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Error loading teams',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _loadTeams,
                      child: Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (filteredTeams.isEmpty)
              Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No teams found matching "$_searchQuery"'
                          : 'No teams found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Text('Clear search'),
                      ),
                    ],
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredTeams.length,
                  itemBuilder: (context, index) {
                    final team = filteredTeams[index];
                    return _buildTeamTile(team);
                  },
                ),
              ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Helper factory methods for common use cases
class TeamSelectorDialogFactory {
  /// Show team selector for creating matches
  static void showForMatchCreation({
    required BuildContext context,
    required Function(Team team) onTeamSelected,
    String title = 'Select Team',
  }) {
    showDialog(
      context: context,
      builder: (context) => TeamSelectorDialog(
        title: title,
        subtitle: 'Choose a team for the match',
        onTeamSelected: onTeamSelected,
      ),
    );
  }

  /// Show team selector for general team selection
  static void showForTeamSelection({
    required BuildContext context,
    Function(Team team)? onTeamSelected,
    Function(List<Team> teams)? onMultipleTeamsSelected,
    String title = 'Select Team',
    String? subtitle,
    bool Function(Team team)? filterTeams,
    bool multiSelect = false,
    List<Team>? preSelectedTeams,
    bool showClubName = true,
  }) {
    showDialog(
      context: context,
      builder: (context) => TeamSelectorDialog(
        title: title,
        subtitle: subtitle,
        onTeamSelected: onTeamSelected,
        onMultipleTeamsSelected: onMultipleTeamsSelected,
        filterTeams: filterTeams,
        multiSelect: multiSelect,
        preSelectedTeams: preSelectedTeams,
        showClubName: showClubName,
      ),
    );
  }

  /// Show multi-select team selector
  static void showMultiSelect({
    required BuildContext context,
    required Function(List<Team> teams) onMultipleTeamsSelected,
    required String title,
    String? subtitle,
    bool Function(Team team)? filterTeams,
    List<Team>? preSelectedTeams,
    bool showClubName = true,
  }) {
    showDialog(
      context: context,
      builder: (context) => TeamSelectorDialog(
        title: title,
        subtitle: subtitle,
        onMultipleTeamsSelected: onMultipleTeamsSelected,
        multiSelect: true,
        preSelectedTeams: preSelectedTeams,
        filterTeams: filterTeams,
        showClubName: showClubName,
      ),
    );
  }
}