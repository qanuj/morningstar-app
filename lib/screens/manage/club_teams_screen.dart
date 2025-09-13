import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/team.dart';
import '../../services/team_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import 'create_team_screen.dart';

class ClubTeamsScreen extends StatefulWidget {
  final Club club;

  const ClubTeamsScreen({
    super.key,
    required this.club,
  });

  @override
  State<ClubTeamsScreen> createState() => _ClubTeamsScreenState();
}

class _ClubTeamsScreenState extends State<ClubTeamsScreen> {
  List<Team> _teams = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }


  Future<void> _loadTeams() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('🔍 Loading teams for club: ${widget.club.id}');
      final teams = await TeamService.getClubTeams(
        clubId: widget.club.id,
      );
      print('✅ Teams loaded successfully: ${teams.length}');

      if (mounted) {
        setState(() {
          _teams = teams;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading teams: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTeam(Team team) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Team'),
        content: Text('Are you sure you want to delete "${team.name}"?${team.isPrimary ? '\n\nNote: This is the primary team and cannot be deleted.' : ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          if (!team.isPrimary)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
        ],
      ),
    );

    if (confirm != true || team.isPrimary) return;

    try {
      await TeamService.deleteTeam(
        teamId: team.id,
        clubId: widget.club.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTeams();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete team: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateTeamDialog([Team? teamToEdit]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateTeamScreen(
          club: widget.club,
          teamToEdit: teamToEdit,
          onTeamSaved: () {
            _loadTeams();
          },
        ),
      ),
    );
  }


  Widget _buildTeamCard(Team team) {
    return GestureDetector(
      onTap: () => _showCreateTeamDialog(team),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Team logo (large)
              Stack(
                children: [
                  team.logo != null && team.logo!.isNotEmpty
                      ? SVGAvatar(
                          imageUrl: team.logo,
                          size: 80,
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          fallbackIcon: Icons.sports_cricket,
                          iconSize: 40,
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              team.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                              ),
                            ),
                          ),
                        ),
                  // Primary team badge
                  if (team.isPrimary)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16),

              // Team name
              Text(
                team.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              
              if (team.isPrimary) ...[
                SizedBox(height: 4),
                Text(
                  'Primary Team',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              SizedBox(height: 16), // Consistent spacing
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ClubAppBar(
        clubName: widget.club.name,
        clubLogo: widget.club.logo,
        subtitle: 'Teams',
        actions: [
          IconButton(
            onPressed: () => _showCreateTeamDialog(),
            icon: Icon(Icons.add),
            tooltip: 'Add Team',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
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
                      ElevatedButton(
                        onPressed: _loadTeams,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _teams.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_cricket,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No teams found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create your first team to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateTeamDialog(),
                            icon: Icon(Icons.add),
                            label: Text('Create Team'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTeams,
                      child: GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _teams.length,
                        itemBuilder: (context, index) {
                          return _buildTeamCard(_teams[index]);
                        },
                      ),
                    ),
    );
  }
}