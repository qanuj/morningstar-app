import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/club.dart';
import '../../services/match_service.dart';
import '../../services/ground_service.dart';
import '../../services/tournament_service.dart';
import '../../services/club_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/autocomplete_field.dart';

class CreateMatchScreen extends StatefulWidget {
  final Club club;
  final VoidCallback? onMatchCreated;

  const CreateMatchScreen({
    super.key,
    required this.club,
    this.onMatchCreated,
  });

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isLoading = false;

  // Form controllers
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _opponentController = TextEditingController();
  final _notesController = TextEditingController();
  final _spotsController = TextEditingController(text: '13');

  // Selected data
  GroundLocation? _selectedGroundLocation;
  City? _selectedCity;
  Tournament? _selectedTournament;
  Club? _selectedOpponentClub;

  // Form values
  String _selectedType = 'Match/Game';
  DateTime _matchDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _matchTime = TimeOfDay(hour: 10, minute: 0);
  
  // RSVP Settings
  bool _hideUntilRSVP = false;
  bool _notifyMembers = false;
  DateTime? _rsvpAfterDate;
  TimeOfDay? _rsvpAfterTime;
  DateTime? _rsvpBeforeDate;
  TimeOfDay? _rsvpBeforeTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Set default RSVP before date to match time minus 2 hours
    _rsvpBeforeDate = _matchDate;
    _rsvpBeforeTime = TimeOfDay(
      hour: _matchTime.hour >= 2 ? _matchTime.hour - 2 : 18,
      minute: 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _opponentController.dispose();
    _notesController.dispose();
    _spotsController.dispose();
    super.dispose();
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) {
      // Switch to Basic Details tab if validation fails there
      if (_locationController.text.trim().isEmpty ||
          (int.tryParse(_spotsController.text) ?? 0) < 1) {
        _tabController.animateTo(0);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Combine date and time
      final matchDateTime = DateTime(
        _matchDate.year,
        _matchDate.month,
        _matchDate.day,
        _matchTime.hour,
        _matchTime.minute,
      );

      DateTime? rsvpAfterDateTime;
      if (_rsvpAfterDate != null && _rsvpAfterTime != null) {
        rsvpAfterDateTime = DateTime(
          _rsvpAfterDate!.year,
          _rsvpAfterDate!.month,
          _rsvpAfterDate!.day,
          _rsvpAfterTime!.hour,
          _rsvpAfterTime!.minute,
        );
      }

      DateTime? rsvpBeforeDateTime;
      if (_rsvpBeforeDate != null && _rsvpBeforeTime != null) {
        rsvpBeforeDateTime = DateTime(
          _rsvpBeforeDate!.year,
          _rsvpBeforeDate!.month,
          _rsvpBeforeDate!.day,
          _rsvpBeforeTime!.hour,
          _rsvpBeforeTime!.minute,
        );
      }

      await MatchService.createMatch(
        clubId: widget.club.id,
        type: _selectedType,
        tournamentId: _selectedTournament?.id,
        location: _locationController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        opponent: _opponentController.text.trim().isEmpty ? null : _opponentController.text.trim(),
        opponentClubId: _selectedOpponentClub?.id,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        matchDate: matchDateTime,
        spots: int.tryParse(_spotsController.text) ?? 13,
        hideUntilRSVP: _hideUntilRSVP,
        rsvpAfterDate: rsvpAfterDateTime,
        rsvpBeforeDate: rsvpBeforeDateTime,
        notifyMembers: _notifyMembers,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onMatchCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create match: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectMatchType(BuildContext context) async {
    final types = ['Match/Game', 'Training', 'Practice', 'Tournament'];
    final selectedIndex = types.indexOf(_selectedType);
    
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Select Match Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              ...types.map((type) => ListTile(
                title: Text(type),
                trailing: _selectedType == type 
                    ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                    : null,
                onTap: () => Navigator.pop(context, type),
              )).toList(),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedType = result;
        // Clear tournament selection when type changes
        if (result != 'Tournament') {
          _selectedTournament = null;
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context, {bool isRsvpAfter = false, bool isRsvpBefore = false}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isRsvpAfter 
          ? _rsvpAfterDate ?? DateTime.now()
          : isRsvpBefore 
              ? _rsvpBeforeDate ?? DateTime.now()
              : _matchDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isRsvpAfter) {
          _rsvpAfterDate = picked;
        } else if (isRsvpBefore) {
          _rsvpBeforeDate = picked;
        } else {
          _matchDate = picked;
          // Update RSVP before date to match
          if (_rsvpBeforeDate != null) {
            _rsvpBeforeDate = picked;
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, {bool isRsvpAfter = false, bool isRsvpBefore = false}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isRsvpAfter
          ? _rsvpAfterTime ?? TimeOfDay.now()
          : isRsvpBefore
              ? _rsvpBeforeTime ?? TimeOfDay.now()
              : _matchTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isRsvpAfter) {
          _rsvpAfterTime = picked;
        } else if (isRsvpBefore) {
          _rsvpBeforeTime = picked;
        } else {
          _matchTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Create Match',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
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
                Tab(text: 'Basic Details'),
                Tab(text: 'RSVP Settings'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicDetailsTab(),
                  _buildRSVPSettingsTab(),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createMatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match Type
          _buildSectionTitle('Match Type', required: true),
          InkWell(
            onTap: () => _selectMatchType(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedType,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),

          // Tournament Selection (only when type is Tournament)
          if (_selectedType == 'Tournament') ...[
            _buildSectionTitle('Tournament', required: true),
            FutureBuilder<List<Tournament>>(
              future: TournamentService.getParticipatingTournaments(widget.club.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Loading tournaments...', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                final tournaments = snapshot.data ?? [];
                
                // Remove any duplicate tournaments to prevent dropdown issues
                final uniqueTournaments = <Tournament>[];
                final seenIds = <String>{};
                
                for (final tournament in tournaments) {
                  if (!seenIds.contains(tournament.id)) {
                    uniqueTournaments.add(tournament);
                    seenIds.add(tournament.id);
                  }
                }
                
                // Ensure selected tournament exists in the list
                if (_selectedTournament != null && 
                    uniqueTournaments.isNotEmpty && 
                    !uniqueTournaments.any((t) => t.id == _selectedTournament!.id)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _selectedTournament = null);
                  });
                }
                
                if (uniqueTournaments.isEmpty) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 12),
                        Text('No tournaments available', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return DropdownButtonFormField<Tournament>(
                  value: _selectedTournament,
                  items: uniqueTournaments.map((tournament) {
                    return DropdownMenuItem(
                      value: tournament,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          '${tournament.name} • ${tournament.organizer.name}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (tournament) {
                    setState(() => _selectedTournament = tournament);
                  },
                  decoration: _inputDecoration('Select tournament...'),
                  validator: (value) {
                    if (_selectedType == 'Tournament' && value == null) {
                      return 'Tournament is required when match type is Tournament';
                    }
                    return null;
                  },
                );
              },
            ),
            SizedBox(height: 24),
          ],

          // Number of Spots
          _buildSectionTitle('Number of Spots', required: true),
          TextFormField(
            controller: _spotsController,
            decoration: _inputDecoration('13').copyWith(
              helperText: 'Maximum players for this match (1-50)',
              helperStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              final spots = int.tryParse(value ?? '');
              if (spots == null || spots < 1 || spots > 50) {
                return 'Spots must be between 1 and 50';
              }
              return null;
            },
          ),
          SizedBox(height: 24),

          // Opponent Team
          _buildSectionTitle('Opponent Team'),
          AutocompleteField<Club>(
            controller: _opponentController,
            hintText: 'Type opponent team name or search existing clubs...',
            helperText: 'You can select an existing club or type any team name as opponent',
            searchFunction: (query) => ClubService.searchClubs(query, excludeClubId: widget.club.id),
            displayStringForOption: (club) => club.name,
            onSelected: (club) {
              setState(() {
                _selectedOpponentClub = club;
              });
            },
            onChanged: (value) {
              // Clear selected club when user types manually
              if (_selectedOpponentClub != null && value != _selectedOpponentClub!.name) {
                setState(() {
                  _selectedOpponentClub = null;
                });
              }
            },
          ),
          SizedBox(height: 24),

          // Location & City
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Location', required: true),
                    AutocompleteField<GroundLocation>(
                      controller: _locationController,
                      hintText: 'Search for venue/ground name',
                      searchFunction: (query) => GroundService.searchGroundLocations(query),
                      displayStringForOption: (location) => location.name,
                      onSelected: (location) {
                        setState(() {
                          _selectedGroundLocation = location;
                          // Auto-fill city if ground location has city
                          if (location.city.isNotEmpty && _cityController.text.isEmpty) {
                            _cityController.text = location.city;
                            _selectedCity = City(
                              id: '',
                              name: location.city,
                              state: '',
                              country: '',
                            );
                          }
                        });
                      },
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Location is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('City'),
                    AutocompleteField<City>(
                      controller: _cityController,
                      hintText: 'Search for city',
                      helperText: 'Required for new locations',
                      searchFunction: (query) => GroundService.searchCities(query),
                      displayStringForOption: (city) => city.displayName,
                      onSelected: (city) {
                        setState(() {
                          _selectedCity = city;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Match Date & Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Match Date', required: true),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_matchDate),
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Match Time', required: true),
                    InkWell(
                      onTap: () => _selectTime(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Text(
                              _matchTime.format(context),
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Additional Notes
          _buildSectionTitle('Additional Notes'),
          TextFormField(
            controller: _notesController,
            decoration: _inputDecoration('Any additional information about the match...'),
            maxLines: 4,
            minLines: 3,
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRSVPSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle switches
          Card(
            elevation: 0,
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Hide match details until RSVP opens',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Send notifications to club members',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    value: _hideUntilRSVP,
                    onChanged: (value) => setState(() => _hideUntilRSVP = value),
                    activeColor: Theme.of(context).primaryColor,
                    inactiveTrackColor: Colors.grey[300],
                    inactiveThumbColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                  ),
                  Divider(height: 1),
                  SwitchListTile(
                    title: Text(
                      'Send notifications to club members',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    value: _notifyMembers,
                    onChanged: (value) => setState(() => _notifyMembers = value),
                    activeColor: Theme.of(context).primaryColor,
                    inactiveTrackColor: Colors.grey[300],
                    inactiveThumbColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),

          // RSVP Opens At (Optional)
          _buildSectionTitle('RSVP Opens At (Optional)'),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, isRsvpAfter: true),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          _rsvpAfterDate != null 
                              ? DateFormat('dd/MM/yyyy').format(_rsvpAfterDate!)
                              : '05/09/2025',
                          style: TextStyle(
                            color: _rsvpAfterDate != null ? null : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(context, isRsvpAfter: true),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          _rsvpAfterTime != null 
                              ? _rsvpAfterTime!.format(context)
                              : '10:00 AM',
                          style: TextStyle(
                            color: _rsvpAfterTime != null ? null : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Members can only RSVP after this time',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          SizedBox(height: 24),

          // RSVP Closes At (Optional)
          _buildSectionTitle('RSVP Closes At (Optional)'),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, isRsvpBefore: true),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          _rsvpBeforeDate != null 
                              ? DateFormat('dd/MM/yyyy').format(_rsvpBeforeDate!)
                              : DateFormat('dd/MM/yyyy').format(_matchDate),
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectTime(context, isRsvpBefore: true),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          _rsvpBeforeTime != null 
                              ? _rsvpBeforeTime!.format(context)
                              : '06:00 PM',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'RSVP deadline (cannot be after match time)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool required = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          children: required ? [
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] : null,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }
}