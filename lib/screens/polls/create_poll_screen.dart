import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../models/poll.dart';
import '../../models/club.dart';
import '../../services/poll_service.dart';
import '../../widgets/custom_app_bar.dart';

class CreatePollScreen extends StatefulWidget {
  final String clubId;
  final ValueChanged<Poll>? onPollCreated;

  const CreatePollScreen({
    super.key,
    required this.clubId,
    this.onPollCreated,
  });

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
  bool _hasExpiration = false;

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
    if (_optionControllers.length < 6) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
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

  void _moveOptionUp(int index) {
    if (index > 0) {
      setState(() {
        final controller = _optionControllers.removeAt(index);
        _optionControllers.insert(index - 1, controller);
      });
    }
  }

  void _moveOptionDown(int index) {
    if (index < _optionControllers.length - 1) {
      setState(() {
        final controller = _optionControllers.removeAt(index);
        _optionControllers.insert(index + 1, controller);
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
        // Call the callback first to send the poll message
        widget.onPollCreated?.call(poll);

        // Then pop the screen with the poll as result
        Navigator.of(context).pop(poll);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
    DateTime tempPickedDate = _expiresAt ?? DateTime.now().add(const Duration(days: 7));

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
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.background
          : const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.background
            : const Color(0xFFF2F2F2),
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.green,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          'Create poll',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _canCreatePoll && !_isLoading ? _createPoll : null,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                : Text(
                    'Send',
                    style: TextStyle(
                      color: _canCreatePoll ? Theme.of(context).colorScheme.primary : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(key: _formKey, child: _buildCreatePollForm()),
    );
  }

  Widget _buildCreatePollForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Section
          _buildSectionLabel('QUESTION'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _questionController,
            decoration: InputDecoration(
              hintText: 'Ask question',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(fontSize: 16),
            maxLines: null,
            maxLength: null,
            onChanged: (_) => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a question';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Options Section
          _buildSectionLabel('OPTIONS'),
          const SizedBox(height: 12),
          ...List.generate(_optionControllers.length, (index) {
            return _buildSimpleOptionField(index);
          }),
          const SizedBox(height: 12),

          // Add Option Button
          if (_optionControllers.length < 6)
            GestureDetector(
              onTap: _addOption,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey[600],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSimpleOptionField(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Reorder controls
          if (_optionControllers.length > 2)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: index > 0 ? () => _moveOptionUp(index) : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: index > 0 ? Colors.grey[600] : Colors.grey[300],
                      size: 20,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: index < _optionControllers.length - 1 ? () => _moveOptionDown(index) : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: index < _optionControllers.length - 1 ? Colors.grey[600] : Colors.grey[300],
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _optionControllers[index],
              decoration: InputDecoration(
                hintText: 'Add',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                counterText: '', // Remove character counter
              ),
              style: const TextStyle(fontSize: 16),
              maxLength: 100,
              onChanged: (value) {
                // Auto-remove option if text is cleared and we have more than 2 options
                if (value.trim().isEmpty && _optionControllers.length > 2 && index >= 2) {
                  _removeOption(index);
                } else {
                  setState(() {});
                }
              },
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
          if (_optionControllers.length > 2 && index >= 2)
            IconButton(
              onPressed: () => _removeOption(index),
              icon: const Icon(Icons.close),
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  Widget _buildOptionField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _optionControllers[index],
              decoration: InputDecoration(
                hintText: 'Option ${index + 1}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              maxLength: 100,
              onChanged: (_) => setState(() {}),
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
          if (_optionControllers.length > 2)
            IconButton(
              onPressed: () => _removeOption(index),
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.red,
            ),
        ],
      ),
    );
  }
}