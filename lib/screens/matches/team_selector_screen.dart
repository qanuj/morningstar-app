import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/team.dart';
import '../../models/club.dart';
import '../../services/team_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import '../qr_scanner.dart';

class TeamSelectorScreen extends StatefulWidget {
  final String title;
  final String? clubId;
  final Function(Team) onTeamSelected;
  final Function(List<Team>)? onMultipleTeamsSelected;
  final bool Function(Team team)? filterTeams;
  final bool multiSelect;
  final List<Team>? preSelectedTeams;

  const TeamSelectorScreen({
    super.key,
    required this.title,
    this.clubId,
    required this.onTeamSelected,
    this.onMultipleTeamsSelected,
    this.filterTeams,
    this.multiSelect = false,
    this.preSelectedTeams,
  }) : assert(
          (!multiSelect && onTeamSelected != null) || 
          (multiSelect && onMultipleTeamsSelected != null),
          'Single select requires onTeamSelected, multi-select requires onMultipleTeamsSelected',
        );

  @override
  State<TeamSelectorScreen> createState() => _TeamSelectorScreenState();
}

class _TeamSelectorScreenState extends State<TeamSelectorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Team> _searchResults = [];
  List<Team> _allTeams = [];
  bool _isSearching = false;
  bool _showSearch = false;
  bool _isLoading = true;
  String? _error;
  late Set<String> _selectedTeamIds;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedTeamIds = widget.preSelectedTeams?.map((team) => team.id).toSet() ?? {};
    _loadTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get both user teams and opponent teams
      final userTeams = await TeamService.getUserTeams();
      final opponentTeams = await TeamService.getOpponentTeams();
      
      if (mounted) {
        setState(() {
          _allTeams = [...userTeams, ...opponentTeams];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Filter teams based on search query
      final filteredTeams = _allTeams.where((team) {
        final teamName = team.name.toLowerCase();
        final clubName = team.club?.name?.toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        
        return teamName.contains(searchQuery) || clubName.contains(searchQuery);
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = filteredTeams;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _scanQRCode() async {
    try {
      final String? qrData = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const QRScanner(title: 'Scan Team QR Code'),
        ),
      );

      if (qrData != null && mounted) {
        final Team? parsedTeam = _parseTeamFromQRData(qrData);

        if (parsedTeam != null) {
          // Call the selection callback and close the screen
          widget.onTeamSelected(parsedTeam);
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR code does not contain valid team information'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Team? _parseTeamFromQRData(String qrData) {
    try {
      final jsonData = json.decode(qrData);
      if (jsonData is Map<String, dynamic>) {
        final type = jsonData['type'] as String?;

        if (type == 'team_info') {
          final teamId = jsonData['id'] as String?;
          final teamName = jsonData['name'] as String?;
          final teamLogo = jsonData['logo'] as String?;
          final sport = jsonData['sport'] as String?;
          final isPrimary = jsonData['isPrimary'] as bool? ?? false;
          final provider = jsonData['provider'] as String?;
          final providerId = jsonData['providerId'] as String?;
          final isVerified = jsonData['isVerified'] as bool? ?? false;
          final city = jsonData['city'] as String?;
          final state = jsonData['state'] as String?;
          final country = jsonData['country'] as String?;
          
          // Parse club info if available
          final clubData = jsonData['club'] as Map<String, dynamic>?;
          Club? club;
          if (clubData != null) {
            final clubId = clubData['id'] as String?;
            final clubName = clubData['name'] as String?;
            final clubLogo = clubData['logo'] as String?;
            
            if (clubId != null && clubName != null) {
              club = Club(
                id: clubId,
                name: clubName,
                logo: clubLogo,
                isVerified: false,
                membershipFee: 0.0,
                membershipFeeCurrency: 'INR',
                upiIdCurrency: 'INR',
                owners: [],
              );
            }
          }

          if (teamId != null && teamName != null) {
            return Team(
              id: teamId,
              name: teamName,
              logo: teamLogo,
              sport: sport ?? 'cricket',
              isPrimary: isPrimary,
              provider: provider ?? 'manual',
              providerId: providerId ?? teamId,
              createdAt: DateTime.now(),
              isVerified: isVerified,
              city: city,
              state: state,
              country: country,
              owners: [],
              club: club,
            );
          }
        }
      }
    } catch (e) {
      // Not valid JSON
    }

    return null; // Could not parse team data
  }

  Widget _buildTeamTile(Team team) {
    final isSelected = _selectedTeamIds.contains(team.id);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (widget.multiSelect) {
            setState(() {
              if (isSelected) {
                _selectedTeamIds.remove(team.id);
              } else {
                _selectedTeamIds.add(team.id);
              }
            });
          } else {
            widget.onTeamSelected(team);
            Navigator.of(context).pop();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Team Avatar
              Stack(
                children: [
                  SVGAvatar(
                    imageUrl: team.logo,
                    size: 50,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    iconColor: Theme.of(context).primaryColor,
                    fallbackIcon: Icons.groups,
                    showBorder: false,
                    borderColor: Theme.of(context).primaryColor,
                    borderWidth: 2,
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
                  // Selection indicator for multi-select
                  if (widget.multiSelect)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected 
                              ? Theme.of(context).primaryColor 
                              : Theme.of(context).scaffoldBackgroundColor,
                          border: Border.all(
                            color: isSelected 
                                ? Theme.of(context).primaryColor 
                                : Theme.of(context).dividerColor,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16),

              // Team Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 4),
                    if (team.club?.name?.isNotEmpty ?? false)
                      Text(
                        team.club!.name,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 14,
                        ),
                      ),
                    if (team.city?.isNotEmpty ?? false) ...[
                      SizedBox(height: 2),
                      Text(
                        team.city!,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow or selection indicator
              if (!widget.multiSelect)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyTeamsTab() {
    // Get user teams only
    final myTeams = _allTeams.where((team) {
      // If clubId is provided, filter teams for that club
      if (widget.clubId != null) {
        return team.club?.id == widget.clubId;
      }
      // Otherwise, show teams where user has ownership/membership
      return team.owners.isNotEmpty; // This would need to be refined based on actual membership logic
    }).toList();

    // Apply additional filtering if provided
    final filteredTeams = widget.filterTeams != null
        ? myTeams.where(widget.filterTeams!).toList()
        : myTeams;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTeams();
      },
      color: Theme.of(context).primaryColor,
      child: _isLoading
          ? ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  height: MediaQuery.of(context).size.height - 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            )
          : _error != null
              ? ListView(
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height - 300,
                      child: Center(
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
                              'Error loading teams',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : filteredTeams.isEmpty
                  ? ListView(
                      physics: AlwaysScrollableScrollPhysics(),
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height - 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.groups,
                                  size: 64,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                      : Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No teams found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Pull down to refresh or create a team',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      physics: AlwaysScrollableScrollPhysics(),
                      itemCount: filteredTeams.length,
                      itemBuilder: (context, index) {
                        return _buildTeamTile(filteredTeams[index]);
                      },
                    ),
    );
  }

  Widget _buildOpponentTeamsTab() {
    // Get opponent teams only (teams user doesn't own/belong to)
    final opponentTeams = _allTeams.where((team) {
      // If clubId is provided, show teams from other clubs
      if (widget.clubId != null) {
        return team.club?.id != widget.clubId;
      }
      // Otherwise, show teams where user doesn't have ownership/membership
      return team.owners.isEmpty; // This would need to be refined based on actual membership logic
    }).toList();
    
    // Apply filtering if provided
    final filteredTeams = widget.filterTeams != null
        ? opponentTeams.where(widget.filterTeams!).toList()
        : opponentTeams;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTeams();
      },
      color: Theme.of(context).primaryColor,
      child: _isLoading
          ? ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  height: MediaQuery.of(context).size.height - 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            )
          : _error != null
              ? ListView(
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height - 300,
                      child: Center(
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
                              'Error loading teams',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : filteredTeams.isEmpty
                  ? ListView(
                      physics: AlwaysScrollableScrollPhysics(),
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height - 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.groups,
                                  size: 64,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                      : Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No teams available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Pull down to refresh',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      physics: AlwaysScrollableScrollPhysics(),
                      itemCount: filteredTeams.length,
                      itemBuilder: (context, index) {
                        return _buildTeamTile(filteredTeams[index]);
                      },
                    ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching teams...'),
          ],
        ),
      );
    }

    if (_searchController.text.trim().isNotEmpty && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            SizedBox(height: 16),
            Text(
              'No teams found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search terms',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            SizedBox(height: 16),
            Text(
              'Search for teams',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter team name to search',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildTeamTile(_searchResults[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: widget.title,
        showBackButton: true,
        customActions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
          if (widget.multiSelect && _selectedTeamIds.isNotEmpty)
            TextButton(
              onPressed: () {
                final selectedTeams = _allTeams
                    .where((team) => _selectedTeamIds.contains(team.id))
                    .toList();
                widget.onMultipleTeamsSelected!(selectedTeams);
                Navigator.of(context).pop();
              },
              child: Text(
                'Done (${_selectedTeamIds.length})',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Field (when visible)
          if (_showSearch) ...[
            Container(
              color: Theme.of(context).cardColor,
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for teams...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).primaryColor,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).primaryColor,
                    ),
                    onPressed: _scanQRCode,
                    tooltip: 'Scan QR Code',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (query) {
                  _performSearch(query);
                },
              ),
            ),
            Divider(height: 1),
          ],

          // Tab Bar (when not searching)
          if (!_showSearch) ...[
            Container(
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                tabs: [
                  Tab(text: 'My Teams'),
                  Tab(text: 'Opponent Teams'),
                ],
              ),
            ),
          ],

          // Content Area
          Expanded(
            child: _showSearch
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: [_buildMyTeamsTab(), _buildOpponentTeamsTab()],
                  ),
          ),
        ],
      ),
    );
  }
}