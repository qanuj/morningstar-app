import 'package:flutter/material.dart';

/// Screen for creating a new practice session
class CreatePracticeScreen extends StatefulWidget {
  final VoidCallback? onPracticeCreated;

  const CreatePracticeScreen({
    super.key,
    this.onPracticeCreated,
  });

  @override
  State<CreatePracticeScreen> createState() => _CreatePracticeScreenState();
}

class _CreatePracticeScreenState extends State<CreatePracticeScreen> {
  final _titleController = TextEditingController(text: 'Practice Session');
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _durationController = TextEditingController(text: '2 hours');
  
  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay(hour: 18, minute: 0);
  String _practiceType = 'Training';
  int _maxParticipants = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Practice Session'),
        backgroundColor: Color(0xFF003f9b),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _createPractice,
            child: Text(
              'Create',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            _buildInputField(
              label: 'Practice Title',
              controller: _titleController,
              required: true,
            ),
            SizedBox(height: 16),

            // Description
            _buildInputField(
              label: 'Description',
              controller: _descriptionController,
              maxLines: 3,
            ),
            SizedBox(height: 16),

            // Practice Type
            _buildDropdownField(
              label: 'Practice Type',
              value: _practiceType,
              items: ['Training', 'Fitness', 'Skills', 'Bowling', 'Batting', 'Fielding'],
              onChanged: (value) => setState(() => _practiceType = value!),
            ),
            SizedBox(height: 16),

            // Date
            _buildDateField(),
            SizedBox(height: 16),

            // Time
            _buildTimeField(),
            SizedBox(height: 16),

            // Venue
            _buildInputField(
              label: 'Venue',
              controller: _venueController,
              required: true,
            ),
            SizedBox(height: 16),

            // Duration
            _buildInputField(
              label: 'Duration',
              controller: _durationController,
              required: true,
            ),
            SizedBox(height: 16),

            // Max Participants
            _buildParticipantsField(),
            SizedBox(height: 32),

            // Create Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createPractice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4CAF50),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
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
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
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
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF4CAF50)),
                SizedBox(width: 12),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _selectTime,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Color(0xFF4CAF50)),
                SizedBox(width: 12),
                Text(
                  _selectedTime.format(context),
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Max Participants',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: _maxParticipants > 1 ? () => setState(() => _maxParticipants--) : null,
              icon: Icon(Icons.remove_circle_outline),
              color: Color(0xFF4CAF50),
            ),
            Container(
              width: 60,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _maxParticipants.toString(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              onPressed: _maxParticipants < 50 ? () => setState(() => _maxParticipants++) : null,
              icon: Icon(Icons.add_circle_outline),
              color: Color(0xFF4CAF50),
            ),
            Expanded(
              child: Text(
                _maxParticipants == 1 ? 'participant' : 'participants',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
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

  void _createPractice() {
    // Validate required fields
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a practice title');
      return;
    }
    
    if (_venueController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a venue');
      return;
    }
    
    if (_durationController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter duration');
      return;
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Practice session created successfully!'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );

    // Call the callback and close screen
    widget.onPracticeCreated?.call();
    Navigator.of(context).pop();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}