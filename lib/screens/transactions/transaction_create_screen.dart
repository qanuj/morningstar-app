import 'package:flutter/material.dart';

class TransactionCreateScreen extends StatefulWidget {
  final String type;
  final String title;
  final bool isBulk;
  final List<dynamic> selectedMembers;
  final Function(Map<String, dynamic>) onSubmit;
  
  const TransactionCreateScreen({
    super.key,
    required this.type,
    required this.title,
    required this.isBulk,
    required this.selectedMembers,
    required this.onSubmit,
  });
  
  @override
  TransactionCreateScreenState createState() => TransactionCreateScreenState();
}

class TransactionCreateScreenState extends State<TransactionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _purpose = 'OTHER';
  String _paymentMethod = 'CASH';
  bool _isSubmitting = false;
  bool _userEditedDescription = false;
  
  final List<Map<String, dynamic>> _purposeOptions = [
    {
      'value': 'MATCH_FEE', 
      'label': 'Match Fee', 
      'icon': Icons.sports_cricket,
      'description': 'Match participation fee'
    },
    {
      'value': 'MEMBERSHIP', 
      'label': 'Membership', 
      'icon': Icons.card_membership,
      'description': 'Club membership fee payment'
    },
    {
      'value': 'JERSEY_ORDER', 
      'label': 'Jersey Order', 
      'icon': Icons.shopping_cart,
      'description': 'Team jersey order payment'
    },
    {
      'value': 'GEAR_PURCHASE', 
      'label': 'Gear Purchase', 
      'icon': Icons.sports,
      'description': 'Cricket equipment and gear purchase'
    },
    {
      'value': 'TRAINING', 
      'label': 'Training', 
      'icon': Icons.fitness_center,
      'description': 'Training session fee'
    },
    {
      'value': 'EVENT', 
      'label': 'Event', 
      'icon': Icons.event,
      'description': 'Club event participation fee'
    },
    {
      'value': 'FOOD_BEVERAGE', 
      'label': 'Food & Beverage', 
      'icon': Icons.restaurant,
      'description': 'Food and refreshment expenses'
    },
    {
      'value': 'MAINTENANCE', 
      'label': 'Maintenance', 
      'icon': Icons.build,
      'description': 'Equipment and facility maintenance'
    },
    {
      'value': 'OTHER', 
      'label': 'Other', 
      'icon': Icons.more_horiz,
      'description': ''
    },
  ];
  
  final List<Map<String, dynamic>> _paymentMethodOptions = [
    {'value': 'CASH', 'label': 'Cash', 'icon': Icons.money},
    {'value': 'UPI', 'label': 'UPI', 'icon': Icons.qr_code},
    {'value': 'BANK_TRANSFER', 'label': 'Bank Transfer', 'icon': Icons.account_balance},
    {'value': 'CARD', 'label': 'Card', 'icon': Icons.credit_card},
    {'value': 'ONLINE', 'label': 'Online Payment', 'icon': Icons.computer},
    {'value': 'CHEQUE', 'label': 'Cheque', 'icon': Icons.receipt},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize description based on default purpose
    _updateDescriptionFromPurpose(_purpose);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateDescriptionFromPurpose(String purposeValue) {
    // Only auto-fill if the user hasn't manually edited the description
    if (!_userEditedDescription) {
      final selectedPurpose = _purposeOptions.firstWhere(
        (option) => option['value'] == purposeValue,
        orElse: () => {'description': ''},
      );
      
      final description = selectedPurpose['description'] ?? '';
      _descriptionController.text = description;
      
      // Reset user edited flag when we auto-fill (except for OTHER which stays empty)
      if (purposeValue != 'OTHER' && description.isNotEmpty) {
        _userEditedDescription = false;
      }
    }
  }

  void _onDescriptionChanged(String value) {
    // Mark that user has manually edited the description
    _userEditedDescription = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Color(0xFF003f9b), // Brand blue
        foregroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitTransaction,
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
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // Member count header for bulk operations
            if (widget.isBulk)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color: Color(0xFF003f9b).withOpacity(0.05),
                child: Row(
                  children: [
                    Icon(
                      Icons.group,
                      color: Color(0xFF003f9b),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${widget.selectedMembers.length} members selected',
                      style: TextStyle(
                        color: Color(0xFF003f9b),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
                      // Amount field card
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
                                controller: _amountController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter amount (₹)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (value) {
                                  FocusScope.of(context).nextFocus();
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Amount is required';
                                  }
                                  final amount = double.tryParse(value);
                                  if (amount == null || amount <= 0) {
                                    return 'Enter a valid amount greater than 0';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),

                      // Purpose selection card
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _purposeOptions.map((option) {
                                  final isSelected = _purpose == option['value'];
                                  return FilterChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          option['icon'],
                                          size: 16,
                                          color: isSelected
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(option['label']),
                                      ],
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _purpose = option['value'];
                                        _updateDescriptionFromPurpose(_purpose);
                                      });
                                    },
                                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    checkmarkColor: Theme.of(context).primaryColor,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Payment method selection (only for CREDIT transactions)
                      if (widget.type == 'CREDIT') ...[
                        const SizedBox(height: 12),
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _paymentMethodOptions.map((option) {
                                    final isSelected = _paymentMethod == option['value'];
                                    return FilterChip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            option['icon'],
                                            size: 16,
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(option['label']),
                                        ],
                                      ),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          _paymentMethod = option['value'];
                                        });
                                      },
                                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                      checkmarkColor: Theme.of(context).primaryColor,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      
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
                                  hintText: 'Enter transaction description',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.description),
                                ),
                                maxLines: 1,
                                textInputAction: TextInputAction.done,
                                onChanged: _onDescriptionChanged,
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
                      
                      // Summary card for bulk operations
                      if (widget.isBulk)
                        Card(
                          color: Theme.of(context).primaryColor.withOpacity(0.05),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                      'Transaction Summary',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This ${widget.type.toLowerCase()} transaction will be applied to ${widget.selectedMembers.length} selected member${widget.selectedMembers.length == 1 ? '' : 's'}.',
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

  void _submitTransaction() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final transactionData = {
          'amount': _amountController.text,
          'description': _descriptionController.text,
          'purpose': _purpose,
          'paymentMethod': _paymentMethod,
        };
        
        await widget.onSubmit(transactionData);
        
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
              content: Text('Failed to process transaction: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}