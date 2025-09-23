import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';

class CreatePollScreen extends StatefulWidget {
  final String clubId;
  final ValueChanged<Poll>? onPollCreated;

  const CreatePollScreen({super.key, required this.clubId, this.onPollCreated});

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form controllers
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Form values
  DateTime? _expiresAt;
  bool _hasExpiration = true;

  @override
  void initState() {
    super.initState();
    // Set default expiry to 2 days from now
    _expiresAt = DateTime.now().add(const Duration(days: 2));
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canCreatePoll {
    if (_questionController.text.trim().isEmpty) return false;

    final validOptions = _optionControllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .length;

    return validOptions >= 2;
  }

  void _addOption() {
    if (_optionControllers.length < 10) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _onOptionChanged(int index, String value) {
    setState(() {});

    // If this is the last option and has text, add a new option
    if (index == _optionControllers.length - 1 &&
        value.trim().isNotEmpty &&
        _optionControllers.length < 10) {
      _addOption();
    }

    // If option is empty and we have more than 2 options, consider removing it
    // But only if it's not one of the first two required options
    if (value.trim().isEmpty && _optionControllers.length > 2 && index >= 2) {
      // Check if this is the last option or if there are empty options after this
      bool hasTextInLaterOptions = false;
      for (int i = index + 1; i < _optionControllers.length; i++) {
        if (_optionControllers[i].text.trim().isNotEmpty) {
          hasTextInLaterOptions = true;
          break;
        }
      }

      // Only remove if there are no non-empty options after this one
      if (!hasTextInLaterOptions) {
        _removeOption(index);
      }
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _createPoll() async {
    if (!_formKey.currentState!.validate() || !_canCreatePoll) return;

    setState(() => _isLoading = true);

    try {
      final options = _optionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final poll = await PollService.createPoll(
        clubId: widget.clubId,
        question: _questionController.text.trim(),
        options: options,
        expiresAt: _hasExpiration ? _expiresAt : null,
      );

      if (mounted) {
        // Pop the screen and return the created poll to the poll picker
        Navigator.of(context).pop(poll);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create poll: ${e.toString().replaceAll('Exception: ', '')}',
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

  Future<void> _selectExpirationDate() async {
    if (Platform.isIOS) {
      await _showCupertinoDatePicker();
    } else {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
        firstDate: DateTime.now().add(const Duration(hours: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (picked != null) {
        setState(() {
          _expiresAt = picked;
        });
      }
    }
  }

  Future<void> _showCupertinoDatePicker() async {
    DateTime tempPickedDate =
        _expiresAt ?? DateTime.now().add(const Duration(days: 7));

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: CupertinoColors.systemBlue,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const Text(
                      'Select Expiration Date',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        setState(() => _expiresAt = tempPickedDate);
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: CupertinoColors.systemBlue,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempPickedDate,
                  minimumDate: DateTime.now().add(const Duration(hours: 1)),
                  maximumDate: DateTime.now().add(const Duration(days: 365)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? theme.scaffoldBackgroundColor
          : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? theme.scaffoldBackgroundColor
            : Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
        ),
        title: Text(
          'Create poll',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _canCreatePoll && !_isLoading ? _createPoll : null,
              style: TextButton.styleFrom(
                backgroundColor: _canCreatePoll && !_isLoading
                    ? theme.colorScheme.primary
                    : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Create',
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
      body: Form(key: _formKey, child: _buildCreatePollForm()),
    );
  }

  Widget _buildCreatePollForm() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Section
          _buildSectionCard(
            title: 'QUESTION',
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              child: TextFormField(
                controller: _questionController,
                decoration: InputDecoration(
                  hintText: 'What would you like to ask?',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  counterText: '',
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
                maxLines: null,
                minLines: 1,
                maxLength: 200,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a question';
                  }
                  if (value.trim().length < 5) {
                    return 'Question must be at least 5 characters';
                  }
                  return null;
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Options Section
          _buildSectionCard(
            title: 'OPTIONS',
            child: Column(
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _optionControllers.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final controller = _optionControllers.removeAt(oldIndex);
                      _optionControllers.insert(newIndex, controller);
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildDraggableOptionField(index);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Expiration Section (Optional)
          _buildExpirationSection(),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDraggableOptionField(int index) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      key: ValueKey('option_$index'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Text field with slight left padding
          Expanded(
            child: TextFormField(
              controller: _optionControllers[index],
              decoration: InputDecoration(
                hintText: 'Add option',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                counterText: '',
              ),
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              maxLength: 100,
              onChanged: (value) => _onOptionChanged(index, value),
              validator: index < 2
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    }
                  : null,
            ),
          ),

          // Drag handle wrapped in ReorderableDragStartListener
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.drag_handle,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationSection() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXPIRATION',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              Switch(
                value: _hasExpiration,
                onChanged: (value) {
                  setState(() {
                    _hasExpiration = value;
                    if (!value) {
                      _expiresAt = null;
                    }
                  });
                },
                activeColor: theme.colorScheme.primary,
                activeTrackColor: theme.colorScheme.primary.withOpacity(0.3),
                inactiveThumbColor: isDarkMode ? Colors.grey[300] : Colors.grey[400],
                inactiveTrackColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              ),
            ],
          ),
          if (_hasExpiration) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _selectExpirationDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _expiresAt != null
                          ? 'Expires ${DateFormat('MMM d, yyyy').format(_expiresAt!)}'
                          : 'Select expiration date',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
