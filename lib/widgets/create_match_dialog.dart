// lib/widgets/create_match_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/club.dart';
import '../services/match_service.dart';

class CreateMatchDialog extends StatefulWidget {
  final Club club;
  final VoidCallback? onMatchCreated;

  const CreateMatchDialog({
    super.key,
    required this.club,
    this.onMatchCreated,
  });

  @override
  State<CreateMatchDialog> createState() => _CreateMatchDialogState();
}

class _CreateMatchDialogState extends State<CreateMatchDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form controllers
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _opponentController = TextEditingController();
  final _notesController = TextEditingController();
  final _spotsController = TextEditingController(text: '13');

  // Form values
  String _selectedType = 'Friendly';
  DateTime _matchDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _matchTime = TimeOfDay(hour: 14, minute: 0);
  bool _hideUntilRSVP = false;
  bool _notifyMembers = true;
  DateTime? _rsvpAfterDate;
  TimeOfDay? _rsvpAfterTime;
  DateTime? _rsvpBeforeDate;
  TimeOfDay? _rsvpBeforeTime;

  @override
  void dispose() {
    _locationController.dispose();
    _cityController.dispose();
    _opponentController.dispose();
    _notesController.dispose();
    _spotsController.dispose();
    super.dispose();
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) {
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
        location: _locationController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        opponent: _opponentController.text.trim().isEmpty ? null : _opponentController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Match created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Create Match for ${widget.club.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Match Type
                      _buildSectionTitle('Match Type'),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        items: MatchService.getMatchTypes().map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                        decoration: _inputDecoration('Select match type'),
                      ),
                      SizedBox(height: 16),

                      // Location
                      _buildSectionTitle('Location'),
                      TextFormField(
                        controller: _locationController,
                        decoration: _inputDecoration('Match venue'),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Location is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 12),

                      // City (optional)
                      TextFormField(
                        controller: _cityController,
                        decoration: _inputDecoration('City (optional)'),
                      ),
                      SizedBox(height: 16),

                      // Opponent (optional)
                      _buildSectionTitle('Opponent'),
                      TextFormField(
                        controller: _opponentController,
                        decoration: _inputDecoration('Opponent team name (optional)'),
                      ),
                      SizedBox(height: 16),

                      // Date and Time
                      _buildSectionTitle('Match Date & Time'),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                                    SizedBox(width: 8),
                                    Text(DateFormat('MMM dd, yyyy').format(_matchDate)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                                    SizedBox(width: 8),
                                    Text(_matchTime.format(context)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Spots
                      _buildSectionTitle('Team Spots'),
                      TextFormField(
                        controller: _spotsController,
                        decoration: _inputDecoration('Number of spots'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final spots = int.tryParse(value ?? '');
                          if (spots == null || spots < 1 || spots > 50) {
                            return 'Spots must be between 1 and 50';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Notes (optional)
                      _buildSectionTitle('Notes (Optional)'),
                      TextFormField(
                        controller: _notesController,
                        decoration: _inputDecoration('Match notes or additional information'),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),

                      // RSVP Settings
                      _buildSectionTitle('RSVP Settings'),
                      SwitchListTile(
                        title: Text('Hide match details until RSVP opens'),
                        subtitle: Text('Members won\'t see location/opponent until RSVP time'),
                        value: _hideUntilRSVP,
                        onChanged: (value) => setState(() => _hideUntilRSVP = value),
                        activeColor: Theme.of(context).primaryColor,
                        inactiveTrackColor: Colors.grey[300],
                        inactiveThumbColor: Colors.white,
                      ),

                      // RSVP After Date/Time (optional)
                      if (_hideUntilRSVP) ...[
                        SizedBox(height: 8),
                        Text(
                          'RSVP Opens At (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, isRsvpAfter: true),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _rsvpAfterDate != null 
                                        ? DateFormat('MMM dd, yyyy').format(_rsvpAfterDate!)
                                        : 'Select date',
                                    style: TextStyle(
                                      color: _rsvpAfterDate != null ? null : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(context, isRsvpAfter: true),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _rsvpAfterTime != null 
                                        ? _rsvpAfterTime!.format(context)
                                        : 'Select time',
                                    style: TextStyle(
                                      color: _rsvpAfterTime != null ? null : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                      ],

                      SwitchListTile(
                        title: Text('Notify club members'),
                        subtitle: Text('Send notification to all club members about this match'),
                        value: _notifyMembers,
                        onChanged: (value) => setState(() => _notifyMembers = value),
                        activeColor: Theme.of(context).primaryColor,
                        inactiveTrackColor: Colors.grey[300],
                        inactiveThumbColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createMatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                          : Text('Create Match'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).textTheme.titleMedium?.color,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[600]),
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