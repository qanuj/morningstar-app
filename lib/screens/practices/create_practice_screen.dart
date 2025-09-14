import 'package:flutter/material.dart';
import '../../services/practice_service.dart';
import '../../models/venue.dart';
import '../matches/venue_picker_screen.dart';

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

  // Location picker variables
  Venue? _selectedVenue;
  bool _isCreatingPractice = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Practice Session'),
        backgroundColor: Color(0xFF003f9b),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isCreatingPractice ? null : _createPractice,
            child: _isCreatingPractice
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
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
            TextFormField(
              controller: _durationController,
              decoration: InputDecoration(
                hintText: 'Duration (e.g., 2 hours, 90 minutes)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
            ),
            SizedBox(height: 16),

            // Max Participants
            _buildParticipantsField(),
            SizedBox(height: 32),

            // Create Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreatingPractice ? null : _createPractice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4CAF50),
                  disabledBackgroundColor: Colors.grey[400],
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreatingPractice
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Creating Practice...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Create Practice Session',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
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
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF4CAF50)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedVenue?.name ?? 'Select location',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedVenue == null
                      ? Colors.grey[600]
                      : Colors.black87,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
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
          child: InkWell(
            onTap: _selectDate,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Color(0xFF4CAF50)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Time Field
        Expanded(
          child: InkWell(
            onTap: _selectTime,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Color(0xFF4CAF50)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedTime.format(context),
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsField() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.group, color: Color(0xFF4CAF50)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Max participants: ${_maxParticipants == 1 ? '$_maxParticipants participant' : '$_maxParticipants participants'}',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
          IconButton(
            onPressed: _maxParticipants > 1
                ? () => setState(() => _maxParticipants--)
                : null,
            icon: Icon(Icons.remove_circle_outline),
            color: Color(0xFF4CAF50),
          ),
          Container(
            width: 50,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                _maxParticipants.toString(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            onPressed: _maxParticipants < 50
                ? () => setState(() => _maxParticipants++)
                : null,
            icon: Icon(Icons.add_circle_outline),
            color: Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  void _showLocationPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VenuePickerScreen(
          title: 'Select Location',
          onVenueSelected: (venue) {
            setState(() {
              _selectedVenue = venue;
            });
          },
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _createPractice() async {
    // Validate required fields
    if (_selectedVenue == null) {
      _showErrorSnackBar('Please select a location');
      return;
    }

    if (_durationController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter duration');
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
        duration: _durationController.text.trim(),
        maxParticipants: _maxParticipants,
        notifyMembers: true, // Server handles chat notification automatically
      );

      if (result != null) {
        // Success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Practice session created successfully!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );

          // Practice created successfully - server handles chat notification
          // No need to call onPracticeCreated callback to avoid duplicate messages
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
