import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../../services/practice_service.dart';
import '../../models/venue.dart';
import '../matches/venue_picker_screen.dart';
import '../../utils/theme.dart';

/// Screen for creating a new practice session
class CreatePracticeScreen extends StatefulWidget {
  final String clubId;
  final Function(Map<String, dynamic>)? onPracticeCreated;

  const CreatePracticeScreen({
    super.key,
    required this.clubId,
    this.onPracticeCreated,
  });

  @override
  State<CreatePracticeScreen> createState() => _CreatePracticeScreenState();
}

class _CreatePracticeScreenState extends State<CreatePracticeScreen> {
  final _durationController = TextEditingController(text: '2 hours');

  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay(hour: 18, minute: 0);
  int _maxParticipants = 20;
  String _selectedDuration = '2 hours'; // Default duration

  // Location picker variables
  Venue? _selectedVenue;
  bool _isCreatingPractice = false;

  // Duration options in 15-minute intervals
  final List<String> _durationOptions = [
    '30 minutes',
    '45 minutes',
    '1 hour',
    '1 hour 15 minutes',
    '1 hour 30 minutes',
    '1 hour 45 minutes',
    '2 hours',
    '2 hours 15 minutes',
    '2 hours 30 minutes',
    '2 hours 45 minutes',
    '3 hours',
    '3 hours 15 minutes',
    '3 hours 30 minutes',
    '3 hours 45 minutes',
    '4 hours',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.background
          : const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: Text('Create Practice Session'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).appBarTheme.backgroundColor
            : AppTheme.cricketGreen,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).appBarTheme.foregroundColor
            : Colors.white,
        actions: [
          IconButton(
            onPressed: _isCreatingPractice ? null : _createPractice,
            icon: _isCreatingPractice
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check),
            tooltip: 'Create Practice Session',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Picker
              _buildLocationField(),
              SizedBox(height: 16),

              // Date & Time
              _buildDateTimeField(),
              SizedBox(height: 16),

              // Duration
              _buildDurationField(),
              SizedBox(height: 16),

              // Max Participants
              _buildParticipantsField(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return InkWell(
      onTap: _showLocationPicker,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedVenue == null
                ? Theme.of(context).dividerColor.withOpacity(0.5)
                : Theme.of(context).primaryColor,
            width: _selectedVenue == null ? 1 : 2,
          ),
          borderRadius: BorderRadius.circular(12),
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
                  : Theme.of(context).primaryColor,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedVenue?.name ?? 'Select location',
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
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).textTheme.bodySmall?.color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeField() {
    return Row(
      children: [
        // Date Field
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _selectDate,
            icon: Icon(
              Icons.calendar_today,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            label: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
              foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
              elevation: 0,
              side: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Time Field
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _selectTime,
            icon: Icon(
              Icons.access_time,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            label: Text(
              _selectedTime.format(context),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
              foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
              elevation: 0,
              side: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationField() {
    return InkWell(
      onTap: _showDurationPicker,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
              Icons.schedule,
              color: Theme.of(context).primaryColor,
              size: 22,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDuration,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).textTheme.bodySmall?.color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsField() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).inputDecorationTheme.fillColor,
      ),
      child: Row(
        children: [
          Icon(Icons.group, color: Theme.of(context).primaryColor, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Max Players',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: _maxParticipants > 1
                ? () => setState(() => _maxParticipants--)
                : null,
            icon: Icon(Icons.remove_circle_outline),
            color: _maxParticipants > 1
                ? Theme.of(context).primaryColor
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
          Container(
            width: 50,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).cardColor,
            ),
            child: Center(
              child: Text(
                _maxParticipants.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _maxParticipants < 50
                ? () => setState(() => _maxParticipants++)
                : null,
            icon: Icon(Icons.add_circle_outline),
            color: _maxParticipants < 50
                ? Theme.of(context).primaryColor
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ],
      ),
    );
  }

  void _showLocationPicker() async {
    final selectedVenue = await VenuePickerScreen.showVenuePicker(
      context: context,
      title: 'Select Location',
    );

    if (selectedVenue != null) {
      setState(() {
        _selectedVenue = selectedVenue;
      });
    }
  }

  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                'Select Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _durationOptions.length,
                  itemBuilder: (context, index) {
                    final duration = _durationOptions[index];
                    final isSelected = _selectedDuration == duration;

                    return ListTile(
                      title: Text(
                        duration,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedDuration = duration;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate() async {
    if (Platform.isIOS) {
      await _showCupertinoDatePicker();
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime.now(),
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
        setState(() => _selectedDate = picked);
      }
    }
  }

  Future<void> _showCupertinoDatePicker() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        DateTime tempPickedDate = _selectedDate;

        return Container(
          height: 300,
          padding: EdgeInsets.only(top: 16),
          child: Column(
            children: [
              // Header with buttons
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    Text(
                      'Select Date',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        setState(() => _selectedDate = tempPickedDate);
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Date picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate,
                  minimumDate: DateTime.now(),
                  maximumDate: DateTime.now().add(Duration(days: 365)),
                  onDateTimeChanged: (DateTime newDate) {
                    tempPickedDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTime() async {
    if (Platform.isIOS) {
      await _showCupertinoTimePicker();
    } else {
      final picked = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
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
        setState(() => _selectedTime = picked);
      }
    }
  }

  Future<void> _showCupertinoTimePicker() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        DateTime tempPickedTime = DateTime(
          2025,
          1,
          1,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        return Container(
          height: 300,
          padding: EdgeInsets.only(top: 16),
          child: Column(
            children: [
              // Header with buttons
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    Text(
                      'Select Time',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        setState(() {
                          _selectedTime = TimeOfDay(
                            hour: tempPickedTime.hour,
                            minute: tempPickedTime.minute,
                          );
                        });
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Time picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: tempPickedTime,
                  use24hFormat: false,
                  onDateTimeChanged: (DateTime newTime) {
                    tempPickedTime = newTime;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createPractice() async {
    // Validate required fields
    if (_selectedVenue == null) {
      _showErrorSnackBar('Please select a location');
      return;
    }

    if (_selectedDuration.isEmpty) {
      _showErrorSnackBar('Please select duration');
      return;
    }

    setState(() => _isCreatingPractice = true);

    try {
      // Create practice session using API - server will handle chat notification
      final result = await PracticeService.createPractice(
        clubId: widget.clubId,
        title: 'Net Practice',
        description: 'Regular training session',
        practiceType: 'Training',
        practiceDate: _selectedDate,
        practiceTime:
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        venue: _selectedVenue!.name,
        locationId: _selectedVenue!.id,
        city: _selectedVenue!.city,
        duration: _selectedDuration,
        maxParticipants: _maxParticipants,
        notifyMembers: true, // Server handles chat notification automatically
      );

      if (result != null) {
        // Success - call the callback to send chat message
        if (widget.onPracticeCreated != null) {
          widget.onPracticeCreated!(result);
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showErrorSnackBar('Failed to create practice session');
      }
    } catch (e) {
      print('❌ Error creating practice: $e');
      _showErrorSnackBar('Failed to create practice session');
    } finally {
      if (mounted) {
        setState(() => _isCreatingPractice = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }
}
