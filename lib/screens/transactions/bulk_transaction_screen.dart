import 'package:flutter/material.dart';

class BulkTransactionScreen extends StatefulWidget {
  final List<dynamic> selectedMembers;
  final Function(Map<String, dynamic>, String) onSubmit;

  const BulkTransactionScreen({
    super.key,
    required this.selectedMembers,
    required this.onSubmit,
  });

  @override
  BulkTransactionScreenState createState() => BulkTransactionScreenState();
}

class BulkTransactionScreenState extends State<BulkTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Transaction type toggle
  String _transactionType = 'CREDIT'; // CREDIT for funds, DEBIT for expenses

  // For expenses only
  String _chargeType = 'EXACT'; // EXACT or SPLIT
  String _purpose = 'MATCH_FEE';

  // For funds only
  String _paymentMethod = 'CASH';

  bool _isSubmitting = false;
  bool _userEditedDescription = false;
  bool _purposeSelected = false;

  final List<Map<String, dynamic>> _purposeOptions = [
    {
      'value': 'MATCH_FEE',
      'label': 'Match Fee',
      'icon': Icons.sports_cricket,
      'description': 'Match participation fee',
    },
    {
      'value': 'MEMBERSHIP',
      'label': 'Membership',
      'icon': Icons.card_membership,
      'description': 'Club membership fee payment',
    },
    {
      'value': 'JERSEY_ORDER',
      'label': 'Jersey Order',
      'icon': Icons.shopping_cart,
      'description': 'Team jersey order payment',
    },
    {
      'value': 'GEAR_PURCHASE',
      'label': 'Gear Purchase',
      'icon': Icons.sports,
      'description': 'Cricket equipment and gear purchase',
    },
    {
      'value': 'TRAINING',
      'label': 'Training',
      'icon': Icons.fitness_center,
      'description': 'Training session fee',
    },
    {
      'value': 'EVENT',
      'label': 'Event',
      'icon': Icons.event,
      'description': 'Club event participation fee',
    },
    {
      'value': 'FOOD_BEVERAGE',
      'label': 'Food & Beverage',
      'icon': Icons.restaurant,
      'description': 'Food and refreshment expenses',
    },
    {
      'value': 'MAINTENANCE',
      'label': 'Maintenance',
      'icon': Icons.build,
      'description': 'Equipment and facility maintenance',
    },
    {
      'value': 'OTHER',
      'label': 'Other',
      'icon': Icons.more_horiz,
      'description': 'Other expense',
    },
  ];

  final List<Map<String, dynamic>> _paymentMethodOptions = [
    {'value': 'CASH', 'label': 'Cash', 'icon': Icons.money},
    {'value': 'UPI', 'label': 'UPI', 'icon': Icons.qr_code},
  ];

  @override
  void initState() {
    super.initState();
    _updateDescriptionFromPurpose(_purpose);
    _purposeSelected = true; // Initialize with default purpose selected
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateDescriptionFromPurpose(String purposeValue) {
    if (!_userEditedDescription) {
      final selectedPurpose = _purposeOptions.firstWhere(
        (option) => option['value'] == purposeValue,
        orElse: () => {'description': ''},
      );

      final description = selectedPurpose['description'] ?? '';
      _descriptionController.text = description;

      if (purposeValue != 'OTHER' && description.isNotEmpty) {
        _userEditedDescription = false;
      }
    }
  }

  void _onDescriptionChanged(String value) {
    _userEditedDescription = true;
  }

  String _getSelectedPurposeLabel() {
    if (!_purposeSelected && _purpose == 'MATCH_FEE') {
      return 'Select expense purpose';
    }
    final selectedPurpose = _purposeOptions.firstWhere(
      (option) => option['value'] == _purpose,
      orElse: () => {'label': 'Select expense purpose'},
    );
    return selectedPurpose['label'] ?? 'Select expense purpose';
  }

  void _showPurposePicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Select Expense Purpose',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _purposeOptions.length,
                  itemBuilder: (context, index) {
                    final option = _purposeOptions[index];
                    final isSelected = _purpose == option['value'];

                    return ListTile(
                      leading: Icon(
                        option['icon'],
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
                      ),
                      title: Text(
                        option['label'],
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Theme.of(context).primaryColor : Colors.black,
                        ),
                      ),
                      subtitle: option['description'].isNotEmpty
                          ? Text(
                              option['description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _purpose = option['value'];
                          _purposeSelected = true;
                          _updateDescriptionFromPurpose(_purpose);
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

  String get _currentTitle {
    return _transactionType == 'CREDIT' ? 'Funds' : 'Expense';
  }

  IconData get _currentIcon {
    return _transactionType == 'CREDIT' ? Icons.add : Icons.remove;
  }

  Color get _currentColor {
    return _transactionType == 'CREDIT' ? Colors.green : Colors.red;
  }

  double get _amountPerMember {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (_transactionType == 'DEBIT' && _chargeType == 'SPLIT') {
      return amount / widget.selectedMembers.length;
    }
    return amount;
  }

  double get _totalAmount {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (_transactionType == 'DEBIT' && _chargeType == 'EXACT') {
      return amount * widget.selectedMembers.length;
    }
    return amount;
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
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // Type selector (Funds/Expenses)
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
                            _transactionType == 'CREDIT'
                                ? 'Add funds to ${widget.selectedMembers.length} selected members'
                                : 'Charge expense to ${widget.selectedMembers.length} selected members',
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
                                '₹${_amountPerMember.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _currentColor,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Total: ₹${_totalAmount.toStringAsFixed(0)}',
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

                  // Transaction type toggle buttons
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
                                _transactionType = 'CREDIT';
                                _descriptionController.text =
                                    'Add funds to club account';
                                _userEditedDescription = false;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _transactionType == 'CREDIT'
                                    ? Colors.green
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: _transactionType == 'CREDIT'
                                        ? Colors.white
                                        : Colors.green,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Funds',
                                    style: TextStyle(
                                      color: _transactionType == 'CREDIT'
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
                                _transactionType = 'DEBIT';
                                _updateDescriptionFromPurpose(_purpose);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _transactionType == 'DEBIT'
                                    ? Colors.red
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.remove,
                                    color: _transactionType == 'DEBIT'
                                        ? Colors.white
                                        : Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Expense',
                                    style: TextStyle(
                                      color: _transactionType == 'DEBIT'
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
                      // Charge type for expenses only
                      if (_transactionType == 'DEBIT') ...[
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Radio<String>(
                                            value: 'SPLIT',
                                            groupValue: _chargeType,
                                            onChanged: (value) {
                                              setState(() {
                                                _chargeType = value!;
                                              });
                                            },
                                          ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _chargeType = 'SPLIT';
                                                });
                                              },
                                              child: Text('Split total equally'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Radio<String>(
                                            value: 'EXACT',
                                            groupValue: _chargeType,
                                            onChanged: (value) {
                                              setState(() {
                                                _chargeType = value!;
                                              });
                                            },
                                          ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _chargeType = 'EXACT';
                                                });
                                              },
                                              child: Text('Exact per member'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

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
                                decoration: InputDecoration(
                                  hintText:
                                      _transactionType == 'DEBIT' &&
                                          _chargeType == 'SPLIT'
                                      ? 'Enter total amount (₹)'
                                      : 'Enter amount per member (₹)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.next,
                                onChanged: (value) =>
                                    setState(() {}), // Update calculations
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

                      // Purpose selection for expenses only
                      if (_transactionType == 'DEBIT') ...[
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
                                  onTap: _showPurposePicker,
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
                                            _getSelectedPurposeLabel(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: _purpose == 'MATCH_FEE' && !_purposeSelected
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
                      ],

                      // Payment method selection for funds only
                      if (_transactionType == 'CREDIT') ...[
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _paymentMethod = 'CASH';
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _paymentMethod == 'CASH'
                                                ? Theme.of(context).primaryColor.withOpacity(0.1)
                                                : Colors.grey[50],
                                            border: Border.all(
                                              color: _paymentMethod == 'CASH'
                                                  ? Theme.of(context).primaryColor
                                                  : Colors.grey[300]!,
                                              width: _paymentMethod == 'CASH' ? 2 : 1,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.money,
                                                size: 32,
                                                color: _paymentMethod == 'CASH'
                                                    ? Theme.of(context).primaryColor
                                                    : Colors.grey[600],
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Cash',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: _paymentMethod == 'CASH'
                                                      ? Theme.of(context).primaryColor
                                                      : Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _paymentMethod = 'UPI';
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _paymentMethod == 'UPI'
                                                ? Theme.of(context).primaryColor.withOpacity(0.1)
                                                : Colors.grey[50],
                                            border: Border.all(
                                              color: _paymentMethod == 'UPI'
                                                  ? Theme.of(context).primaryColor
                                                  : Colors.grey[300]!,
                                              width: _paymentMethod == 'UPI' ? 2 : 1,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.qr_code,
                                                size: 32,
                                                color: _paymentMethod == 'UPI'
                                                    ? Theme.of(context).primaryColor
                                                    : Colors.grey[600],
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'UPI',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: _paymentMethod == 'UPI'
                                                      ? Theme.of(context).primaryColor
                                                      : Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

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
                                    'Transaction Summary',
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
                                'This ${_transactionType.toLowerCase() == 'credit' ? 'fund addition' : 'expense'} will be applied to ${widget.selectedMembers.length} selected member${widget.selectedMembers.length == 1 ? '' : 's'}.',
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
    // Validate purpose selection for expenses
    if (_transactionType == 'DEBIT' && !_purposeSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select expense purpose'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final transactionData = {
          'amount': _amountController.text,
          'description': _descriptionController.text,
          'purpose': _transactionType == 'CREDIT' ? 'CLUB_TOPUP' : _purpose,
          'paymentMethod': _transactionType == 'CREDIT' ? _paymentMethod : null,
          'chargeType': _transactionType == 'DEBIT' ? _chargeType : null,
        };

        await widget.onSubmit(transactionData, _transactionType);

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
