import 'package:flutter/material.dart';

class TransactionCreateWidget extends StatefulWidget {
  final String type;
  final String title;
  final bool isBulk;
  final List<dynamic> selectedMembers;
  final Function(Map<String, dynamic>) onSubmit;
  final ScrollController scrollController;
  
  const TransactionCreateWidget({
    super.key,
    required this.type,
    required this.title,
    required this.isBulk,
    required this.selectedMembers,
    required this.onSubmit,
    required this.scrollController,
  });
  
  @override
  TransactionCreateWidgetState createState() => TransactionCreateWidgetState();
}

class TransactionCreateWidgetState extends State<TransactionCreateWidget> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _purpose = 'OTHER';
  String _paymentMethod = 'CASH';
  
  final List<Map<String, dynamic>> _purposeOptions = [
    {'value': 'MATCH_FEE', 'label': 'Match Fee', 'icon': Icons.sports_cricket},
    {'value': 'MEMBERSHIP', 'label': 'Membership', 'icon': Icons.card_membership},
    {'value': 'JERSEY_ORDER', 'label': 'Jersey Order', 'icon': Icons.shopping_cart},
    {'value': 'GEAR_PURCHASE', 'label': 'Gear Purchase', 'icon': Icons.sports},
    {'value': 'TRAINING', 'label': 'Training', 'icon': Icons.fitness_center},
    {'value': 'EVENT', 'label': 'Event', 'icon': Icons.event},
    {'value': 'FOOD_BEVERAGE', 'label': 'Food & Beverage', 'icon': Icons.restaurant},
    {'value': 'MAINTENANCE', 'label': 'Maintenance', 'icon': Icons.build},
    {'value': 'OTHER', 'label': 'Other', 'icon': Icons.more_horiz},
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
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.isBulk)
                        Text(
                          'Selected: ${widget.selectedMembers.length} members',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Scrollable content
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping outside text fields
                FocusScope.of(context).unfocus();
              },
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount field
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                          helperText: 'Enter the transaction amount',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (value) {
                          // Move focus to next field or close keyboard
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
                      
                      const SizedBox(height: 24),
                      
                      // Purpose selection
                      Text(
                        'Purpose',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select the category that best describes this transaction',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
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
                              });
                            },
                            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                            checkmarkColor: Theme.of(context).primaryColor,
                          );
                        }).toList(),
                      ),
                      
                      // Payment method selection (only for CREDIT transactions)
                      if (widget.type == 'CREDIT') ...[
                        const SizedBox(height: 24),
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'How was this payment received?',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
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
                      
                      const SizedBox(height: 24),
                      
                      // Description field (last field)
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          helperText: 'Describe the transaction purpose',
                        ),
                        maxLines: 1,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (value) {
                          // Close keyboard when done
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
                      
                      const SizedBox(height: 32),
                      
                      // Summary card
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
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _submitTransaction(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        widget.type == 'CREDIT' ? 'Add Funds' : 'Record Expense',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitTransaction() {
    if (_formKey.currentState!.validate()) {
      final transactionData = {
        'amount': _amountController.text,
        'description': _descriptionController.text,
        'purpose': _purpose,
        'paymentMethod': _paymentMethod,
      };
      
      widget.onSubmit(transactionData);
      Navigator.pop(context);
    } else {
      // Scroll to first error field
      widget.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}