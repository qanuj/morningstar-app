import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../models/club.dart';
import '../../models/team.dart';
import '../../models/venue.dart';
import '../../services/match_service.dart';
import '../../services/tournament_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import 'team_selector_screen.dart';
import 'venue_picker_screen.dart';
import 'tournament_picker_screen.dart';

class CreateMatchScreen extends StatefulWidget {
  final VoidCallback? onMatchCreated;

  const CreateMatchScreen({super.key, this.onMatchCreated});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form controllers
  final _opponentController = TextEditingController();

  // Selected data
  Team? _selectedHomeTeam;
  Team? _selectedOpponentTeam;
  Venue? _selectedVenue;
  Tournament? _selectedTournament;

  // Form values
  String _selectedType = 'GAME'; // Updated to match API enum
  String _selectedBall = 'Red';
  DateTime _matchDate = DateTime.now().add(Duration(days: 1));
  late TimeOfDay _matchTime;

  @override
  void initState() {
    super.initState();
    _matchTime = _getDefaultMatchTime(); // Set intelligent default time
  }

  TimeOfDay _getDefaultMatchTime() {
    final now = DateTime.now();
    final currentMinutes = now.minute;

    // Calculate next 15 or 45 minute mark that's at least 30 minutes from now
    int targetMinutes;
    int targetHour = now.hour;

    if (currentMinutes < 15) {
      // If before :15, set to :15 if that's 30+ minutes away, otherwise :45
      if (15 - currentMinutes >= 30) {
        targetMinutes = 15;
      } else {
        targetMinutes = 45;
      }
    } else if (currentMinutes < 45) {
      // If before :45, set to :45 if that's 30+ minutes away, otherwise next hour :15
      if (45 - currentMinutes >= 30) {
        targetMinutes = 45;
      } else {
        targetMinutes = 15;
        targetHour = (targetHour + 1) % 24;
      }
    } else {
      // If after :45, set to next hour :15 or :45
      targetHour = (targetHour + 1) % 24;
      if (60 - currentMinutes + 15 >= 30) {
        targetMinutes = 15;
      } else {
        targetMinutes = 45;
      }
    }

    return TimeOfDay(hour: targetHour, minute: targetMinutes);
  }

  @override
  void dispose() {
    _opponentController.dispose();
    super.dispose();
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if both teams are selected
    if (_selectedHomeTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select home team'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedOpponentTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select opponent team'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedVenue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a venue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate tournament selection for Tournament matches
    if (_selectedType == 'TOURNAMENT' && _selectedTournament == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a tournament'),
          backgroundColor: Colors.red,
        ),
      );
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

      // Ensure match is in the future
      if (matchDateTime.isBefore(DateTime.now().add(Duration(hours: 1)))) {
        throw Exception('Match time must be at least 1 hour in the future');
      }

      await MatchService.createMatch(
        clubId: _selectedHomeTeam!.club?.id ?? '',
        type: _selectedType,
        tournamentId: _selectedTournament?.id,
        location: _selectedVenue!.name,
        city: _selectedVenue!.city,
        opponent: _selectedOpponentTeam!.name,
        opponentClubId: _selectedOpponentTeam!.club?.id,
        notes: 'Ball Type: $_selectedBall | Home Team: ${_selectedHomeTeam!.name} vs ${_selectedOpponentTeam!.name}',
        matchDate: matchDateTime,
        spots: 13,
        hideUntilRSVP: false,
        rsvpAfterDate: null,
        rsvpBeforeDate: null,
        notifyMembers: false,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onMatchCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create match: ${e.toString().replaceAll('Exception: ', '')}',
            ),
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
    final types = ['GAME', 'TOURNAMENT']; // Updated to match API enum

    final result = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Select Match Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(height: 16),
              ...types
                  .map(
                    (type) => ListTile(
                      title: Text(
                        type == 'GAME'
                            ? 'Match'
                            : (type == 'TOURNAMENT' ? 'Tournament' : type),
                      ),
                      trailing: _selectedType == type
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      onTap: () {
                        // Reset tournament selection when switching to GAME
                        if (type == 'GAME' && _selectedTournament != null) {
                          setState(() {
                            _selectedTournament = null;
                          });
                        }
                        Navigator.pop(context, type);
                      },
                    ),
                  )
                  .toList(),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedType = result;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime.now().add(Duration(hours: 1)),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _matchDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _matchTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _matchTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(pageTitle: 'Create Match', showBackButton: true),
      body: Column(
        children: [
          // Content
          Expanded(
            child: Form(key: _formKey, child: _buildCreateMatchForm()),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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

  Widget _buildCreateMatchForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match Type Selection (no label)
          Row(
            children: [
              _buildTypeButton('GAME', Icons.sports_cricket),
              SizedBox(width: 16),
              _buildTypeButton('TOURNAMENT', Icons.emoji_events),
            ],
          ),
          SizedBox(height: 20),

          // Team Circles
          Row(
            children: [
              Expanded(
                child: _buildTeamCircle(
                  title: 'Home Team',
                  team: _selectedHomeTeam,
                  onTap: () => _selectHomeTeam(),
                ),
              ),
              SizedBox(width: 16),
              Text(
                'VS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildTeamCircle(
                  title: 'Opponent Team',
                  team: _selectedOpponentTeam,
                  onTap: () => _selectOpponentTeam(),
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
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 22,
                              color: Theme.of(context).primaryColor,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(_matchDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _selectTime(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 22,
                              color: Theme.of(context).primaryColor,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _matchTime.format(context),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
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
          SizedBox(height: 20),

          // Venue Selection
          InkWell(
            onTap: () => _selectVenue(),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedVenue == null
                      ? Theme.of(context).dividerColor.withOpacity(0.5)
                      : Theme.of(context).primaryColor,
                  width: _selectedVenue == null ? 1 : 2,
                ),
                color: _selectedVenue == null
                    ? Theme.of(context).inputDecorationTheme.fillColor
                    : Theme.of(context).primaryColor.withOpacity(0.05),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: _selectedVenue == null
                        ? Theme.of(context).textTheme.bodyMedium?.color
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).primaryColor),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedVenue?.name ?? 'Select venue',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedVenue == null
                                ? Theme.of(context).textTheme.bodySmall?.color
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: _selectedVenue == null
                                ? FontWeight.normal
                                : FontWeight.w500,
                          ),
                        ),
                        if (_selectedVenue?.fullAddress.isNotEmpty ?? false)
                          Text(
                            _selectedVenue!.fullAddress,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Tournament Selection (only for Tournament type)
          if (_selectedType == 'TOURNAMENT') ...[
            InkWell(
              onTap: () => _selectTournament(),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedTournament == null
                        ? Theme.of(context).dividerColor.withOpacity(0.5)
                        : Theme.of(context).primaryColor,
                    width: _selectedTournament == null ? 1 : 2,
                  ),
                  color: _selectedTournament == null
                      ? Theme.of(context).inputDecorationTheme.fillColor
                      : Theme.of(context).primaryColor.withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: _selectedTournament == null
                          ? Theme.of(context).textTheme.bodyMedium?.color
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).primaryColor),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTournament?.name ?? 'Select tournament',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedTournament == null
                                  ? Theme.of(context).textTheme.bodySmall?.color
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: _selectedTournament == null
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                            ),
                          ),
                          if (_selectedTournament != null) ...[
                            SizedBox(height: 4),
                            Text(
                              '${_selectedTournament!.location}, ${_selectedTournament!.city}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${DateFormat('MMM dd').format(_selectedTournament!.startDate)} - ${DateFormat('MMM dd, yyyy').format(_selectedTournament!.endDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
          ],

          // Ball Selection
          Container(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildBallOption('Pink', Color(0xFFFF1493), useSvg: true),
                SizedBox(width: 12),
                _buildBallOption('White', Color(0xFFF5F5F5), useSvg: true),
                SizedBox(width: 12),
                _buildBallOption(
                  'Red',
                  Color.fromARGB(255, 88, 0, 25),
                  useSvg: true,
                ),
                SizedBox(width: 12),
                _buildBallOption(
                  'Tennis',
                  Color(0xFFC7D32B),
                  useSvg: true,
                  svgAsset: 'assets/images/tennis.svg',
                ),
                SizedBox(width: 12),
                _buildBallOption('Other', Colors.orange),
              ],
            ),
          ),

          // Selected ball name
          SizedBox(height: 6),
          Center(
            child: Text(
              _selectedBall,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, IconData icon) {
    final isSelected = _selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            // Reset tournament selection when switching to GAME
            if (type == 'GAME') {
              _selectedTournament = null;
            }
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Theme.of(context).inputDecorationTheme.fillColor,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).dividerColor.withOpacity(0.5),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).primaryColor)
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
              SizedBox(height: 4),
              Text(
                type == 'GAME'
                    ? 'Match'
                    : (type == 'TOURNAMENT' ? 'Tournament' : type),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).primaryColor)
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBallOption(
    String ballType,
    Color ballColor, {
    bool useSvg = false,
    String? svgAsset,
  }) {
    final isSelected = _selectedBall == ballType;
    final ballSize = isSelected ? 75.0 : 50.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBall = ballType;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: ballSize,
        height: ballSize,
        decoration: BoxDecoration(
          color: ballColor,
          shape: BoxShape.circle,
          border: ballType == 'White'
              ? Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                  width: 1,
                )
              : null,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: useSvg
            ? ClipOval(
                child: SvgPicture.asset(
                  svgAsset ?? 'assets/images/ball.svg',
                  width: ballSize,
                  height: ballSize,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.3),
                    BlendMode.overlay,
                  ),
                  fit: BoxFit.contain,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildTeamCircle({
    required String title,
    Team? team,
    required VoidCallback onTap,
  }) {
    final bool hasTeam = team != null;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: hasTeam
              ? Column(
                  children: [
                    // Team logo with badges
                    Stack(
                      children: [
                        SVGAvatar(
                          imageUrl: team!.logo,
                          size: 120,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          iconColor: Theme.of(context).primaryColor,
                          fallbackIcon: Icons.sports_cricket,
                          showBorder: false,
                          fit: BoxFit.contain,
                          child: team!.logo == null
                              ? Text(
                                  team!.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        // Verified Badge
                        if (team!.isVerified)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        // Primary team badge
                        if (team!.isPrimary)
                          Positioned(
                            left: 2,
                            top: 2,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  width: 3,
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
                    SizedBox(height: 8),
                    // Team name below the circle
                    Text(
                      team!.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (team!.club != null) ...[
                      SizedBox(height: 2),
                      Text(
                        team!.club!.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                )
              : Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          size: 32,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    // Placeholder text below the circle
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _selectHomeTeam() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamSelectorScreen(
          title: 'Select Home Team',
          onTeamSelected: (team) {
            setState(() {
              _selectedHomeTeam = team;
            });
          },
        ),
      ),
    );
  }

  void _selectOpponentTeam() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamSelectorScreen(
          title: 'Select Opponent Team',
          onTeamSelected: (team) {
            setState(() {
              _selectedOpponentTeam = team;
            });
          },
        ),
      ),
    );
  }

  void _selectVenue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VenuePickerScreen(
          title: 'Select Venue',
          onVenueSelected: (venue) {
            setState(() {
              _selectedVenue = venue;
            });
          },
        ),
      ),
    );
  }

  void _selectTournament() {
    if (_selectedHomeTeam == null || _selectedHomeTeam!.club == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select home team first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TournamentPickerScreen(
          clubId: _selectedHomeTeam!.club!.id,
          title: 'Select Tournament',
          onTournamentSelected: (tournament) {
            setState(() {
              _selectedTournament = tournament;
            });
          },
        ),
      ),
    );
  }

}
