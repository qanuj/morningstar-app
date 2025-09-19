import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/team.dart';
import '../../services/team_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import '../team_qr_screen.dart';
import 'create_team_screen.dart';

class ClubTeamsScreen extends StatefulWidget {
  final Club club;

  const ClubTeamsScreen({super.key, required this.club});

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
      final teams = await TeamService.getClubTeams(clubId: widget.club.id);
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

  void _showTeamQR(Team team) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamQRScreen(team: team),
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    return GestureDetector(
      onTap: () => _showCreateTeamDialog(team),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Stack(
            children: [
              // Main content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // Team logo with contrasting background
              Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.1),
                          Theme.of(context).primaryColor.withOpacity(0.2),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: SVGAvatar(
                        imageUrl: team.logo,
                        size: 100,
                        backgroundColor: Colors.transparent,
                        fallbackText: team.name,
                        fallbackTextStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
                  // Primary team badge
                  if (team.isPrimary)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).cardColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(Icons.star, color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),

              // Team name
              Expanded(
                child: Center(
                  child: Text(
                    team.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
                ],
              ),
              
              // QR Button positioned in top-right corner
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showTeamQR(team),
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.15)
                          : Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.qr_code,
                      size: 18,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.9)
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
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
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  SizedBox(height: 16),
                  Text(
                    'Error loading teams',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadTeams, child: Text('Retry')),
                ],
              ),
            )
          : _teams.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_cricket, size: 64, color: Colors.grey[400]),
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
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
          : Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.grey[200],
              child: RefreshIndicator(
                onRefresh: _loadTeams,
                child: GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _teams.length,
                  itemBuilder: (context, index) {
                    return _buildTeamCard(_teams[index]);
                  },
                ),
              ),
            ),
    );
  }
}
