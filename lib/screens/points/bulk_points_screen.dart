import 'package:flutter/material.dart';

class BulkPointsScreen extends StatefulWidget {
  final List<dynamic> selectedMembers;
  final Function(Map<String, dynamic>, String) onSubmit;

  const BulkPointsScreen({
    super.key,
    required this.selectedMembers,
    required this.onSubmit,
  });

  @override
  BulkPointsScreenState createState() => BulkPointsScreenState();
}

class BulkPointsScreenState extends State<BulkPointsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pointsController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _action = 'add'; // add or remove
  String _category = 'OUTSTANDING_PERFORMANCE';
  bool _isSubmitting = false;
  bool _categorySelected = false;

  // Categories for adding points
  final List<Map<String, dynamic>> _addCategoryOptions = [
    {
      'value': 'OUTSTANDING_PERFORMANCE',
      'label': 'Outstanding Performance',
      'icon': Icons.star,
      'description': 'Outstanding performance in matches',
    },
    {
      'value': 'PRACTICE_ATTENDED',
      'label': 'Practice Attended',
      'icon': Icons.event_available,
      'description': 'Regular attendance and participation',
    },
    {
      'value': 'MATCH_PARTICIPATION',
      'label': 'Match Participation',
      'icon': Icons.sports_cricket,
      'description': 'Active participation in matches',
    },
    {
      'value': 'TEAM_CONTRIBUTION',
      'label': 'Team Contribution',
      'icon': Icons.emoji_events,
      'description': 'Valuable contribution to team efforts',
    },
    {
      'value': 'MATCH_BEHAVIOUR',
      'label': 'Good Behaviour',
      'icon': Icons.sentiment_satisfied,
      'description': 'Positive behaviour during matches',
    },
    {
      'value': 'OTHER',
      'label': 'Other',
      'icon': Icons.more_horiz,
      'description': 'Other point adjustments',
    },
  ];

  // Categories for deducting points
  final List<Map<String, dynamic>> _deductCategoryOptions = [
    {
      'value': 'MISCONDUCT',
      'label': 'Misconduct',
      'icon': Icons.report,
      'description': 'Disciplinary action for misconduct',
    },
    {
      'value': 'LATE_ARRIVAL',
      'label': 'Late Arrival',
      'icon': Icons.schedule,
      'description': 'Penalty for arriving late',
    },
    {
      'value': 'OTHER',
      'label': 'Other',
      'icon': Icons.more_horiz,
      'description': 'Other point adjustments',
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateDescriptionFromCategory();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _currentCategoryOptions {
    return _action == 'add' ? _addCategoryOptions : _deductCategoryOptions;
  }

  void _updateDescriptionFromCategory() {
    final selectedCategory = _currentCategoryOptions.firstWhere(
      (option) => option['value'] == _category,
      orElse: () => {'description': ''},
    );

    final description = selectedCategory['description'] ?? '';
    _descriptionController.text = description;
  }

  String get _currentTitle {
    return _action == 'add' ? 'Add Points' : 'Deduct Points';
  }

  IconData get _currentIcon {
    return _action == 'add' ? Icons.add : Icons.remove;
  }

  Color get _currentColor {
    return _action == 'add' ? Colors.green : Colors.red;
  }

  int get _totalPoints {
    final points = int.tryParse(_pointsController.text) ?? 0;
    return points * widget.selectedMembers.length;
  }

  String _getSelectedCategoryLabel() {
    if (!_categorySelected) {
      return 'Select category';
    }
    final selectedCategory = _currentCategoryOptions.firstWhere(
      (option) => option['value'] == _category,
      orElse: () => {'label': 'Select category'},
    );
    return selectedCategory['label'] ?? 'Select category';
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    Text(
                      'Select Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _currentCategoryOptions.length,
                  itemBuilder: (context, index) {
                    final option = _currentCategoryOptions[index];
                    final isSelected = _category == option['value'];
                    return ListTile(
                      leading: Icon(option['icon']),
                      title: Text(option['label']),
                      subtitle: option['description'].isNotEmpty
                          ? Text(option['description'])
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          _category = option['value'];
                          _categorySelected = true;
                          _updateDescriptionFromCategory();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_currentTitle),
        backgroundColor: Color(0xFF003f9b),
        foregroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitPoints,
            child: _isSubmitting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // Header info
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Color(0xFF003f9b).withOpacity(0.05),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _currentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _currentIcon,
                          color: _currentColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _action == 'add'
                                ? 'Add points for ${widget.selectedMembers.length} selected members'
                                : 'Deduct points from ${widget.selectedMembers.length} selected members',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Per Member: ',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${int.tryParse(_pointsController.text) ?? 0} pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _currentColor,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Total: ${_totalPoints} pts',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Action toggle buttons
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _action = 'add';
                                _category = 'OUTSTANDING_PERFORMANCE';
                                _categorySelected = false;
                                _updateDescriptionFromCategory();
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _action == 'add'
                                    ? Colors.green
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: _action == 'add'
                                        ? Colors.white
                                        : Colors.green,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Points',
                                    style: TextStyle(
                                      color: _action == 'add'
                                          ? Colors.white
                                          : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _action = 'remove';
                                _category = 'MISCONDUCT';
                                _categorySelected = false;
                                _updateDescriptionFromCategory();
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _action == 'remove'
                                    ? Colors.red
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.remove,
                                    color: _action == 'remove'
                                        ? Colors.white
                                        : Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Points',
                                    style: TextStyle(
                                      color: _action == 'remove'
                                          ? Colors.white
                                          : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Points field card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _pointsController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter points per member',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.emoji_events),
                                ),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                onChanged: (value) =>
                                    setState(() {}), // Update calculations
                                onFieldSubmitted: (value) {
                                  FocusScope.of(context).nextFocus();
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Points is required';
                                  }
                                  final points = int.tryParse(value);
                                  if (points == null || points <= 0) {
                                    return 'Enter a valid number greater than 0';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Category selection card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _showCategoryPicker,
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[400]!),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.category, color: Colors.grey[600]),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _getSelectedCategoryLabel(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _category == 'OUTSTANDING_PERFORMANCE' && !_categorySelected
                                                ? Colors.grey[600]
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Description field card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter description',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.description),
                                ),
                                maxLines: 2,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (value) {
                                  FocusScope.of(context).unfocus();
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Description is required';
                                  }
                                  if (value.length < 3) {
                                    return 'Description must be at least 3 characters';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Summary card
                      Card(
                        color: Theme.of(context).primaryColor.withOpacity(0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Points Summary',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This will ${_action == 'add' ? 'add' : 'deduct'} ${int.tryParse(_pointsController.text) ?? 0} points ${_action == 'add' ? 'to' : 'from'} ${widget.selectedMembers.length} selected member${widget.selectedMembers.length == 1 ? '' : 's'}.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24), // Bottom spacing
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitPoints() async {
    if (_formKey.currentState!.validate()) {
      if (!_categorySelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a category'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final pointsData = {
          'points': _pointsController.text,
          'description': _descriptionController.text,
          'category': _category,
        };

        await widget.onSubmit(pointsData, _action);

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process points: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
