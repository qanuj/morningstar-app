// lib/screens/matches/match_fee_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/match_fee.dart';
import '../../services/match_fee_service.dart';
import '../../utils/theme.dart';

class MatchFeePaymentScreen extends StatefulWidget {
  final String matchId;
  final double amount;
  final String clubName;
  final String? clubUpiId;

  const MatchFeePaymentScreen({
    super.key,
    required this.matchId,
    required this.amount,
    required this.clubName,
    this.clubUpiId,
  });

  @override
  State<MatchFeePaymentScreen> createState() => _MatchFeePaymentScreenState();
}

class _MatchFeePaymentScreenState extends State<MatchFeePaymentScreen> {
  PaymentMethod? _selectedPaymentMethod;
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) return;

    setState(() => _isProcessing = true);

    try {
      if (_selectedPaymentMethod == PaymentMethod.UPI) {
        await _processUpiPayment();
      } else {
        await _processDirectPayment();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processUpiPayment() async {
    if (widget.clubUpiId == null || widget.clubUpiId!.isEmpty) {
      throw Exception('Club UPI ID not available');
    }

    // Generate UPI payment link
    final upiLink = MatchFeeService.generateUpiLink(
      upiId: widget.clubUpiId!,
      amount: widget.amount,
      note: 'Match fee for ${widget.clubName}',
      matchId: widget.matchId,
    );

    // Launch UPI app
    final uri = Uri.parse(upiLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);

      // Show confirmation dialog after UPI app opens
      if (mounted) {
        _showUpiConfirmationDialog();
      }
    } else {
      throw Exception('No UPI app found');
    }
  }

  void _showUpiConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Status'),
        content: const Text('Did you complete the UPI payment?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close payment screen
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              await _recordUpiPayment();
            },
            child: const Text('Yes, Paid'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordUpiPayment() async {
    final response = await MatchFeeService.payMatchFee(
      matchId: widget.matchId,
      paymentMethod: PaymentMethod.UPI,
      amount: widget.amount,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    if (mounted) {
      _showSuccessDialog(
        'UPI Payment Recorded',
        'Your payment has been recorded. Admin will confirm once they verify the transaction.',
        response['requiresConfirmation'] ?? false,
      );
    }
  }

  Future<void> _processDirectPayment() async {
    final response = await MatchFeeService.payMatchFee(
      matchId: widget.matchId,
      paymentMethod: _selectedPaymentMethod!,
      amount: widget.amount,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    if (mounted) {
      final isKitty = _selectedPaymentMethod == PaymentMethod.KITTY;
      _showSuccessDialog(
        isKitty ? 'Payment Confirmed' : 'Payment Recorded',
        isKitty
            ? 'Amount has been deducted from your kitty balance.'
            : 'Your payment has been recorded. Admin will confirm once they verify the cash payment.',
        !isKitty,
      );
    }
  }

  void _showSuccessDialog(String title, String message, bool requiresConfirmation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              requiresConfirmation ? Icons.hourglass_empty : Icons.check_circle,
              color: requiresConfirmation ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close payment screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Match Fee'),
        backgroundColor: AppTheme.cricketGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount to Pay',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          MatchFeeService.formatCurrency(widget.amount),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.cricketGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'For: ${widget.clubName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Methods
            Text(
              'Choose Payment Method',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // UPI Option
            if (widget.clubUpiId != null && widget.clubUpiId!.isNotEmpty)
              _buildPaymentMethodTile(
                paymentMethod: PaymentMethod.UPI,
                icon: Icons.smartphone,
                title: 'UPI Payment',
                subtitle: 'Pay directly through UPI apps',
                color: Colors.blue,
              ),

            const SizedBox(height: 12),

            // Cash Option
            _buildPaymentMethodTile(
              paymentMethod: PaymentMethod.CASH,
              icon: Icons.money,
              title: 'Cash Payment',
              subtitle: 'Pay cash to admin (requires confirmation)',
              color: Colors.green,
            ),

            const SizedBox(height: 12),

            // Kitty Option
            _buildPaymentMethodTile(
              paymentMethod: PaymentMethod.KITTY,
              icon: Icons.account_balance_wallet,
              title: 'Kitty Balance',
              subtitle: 'Deduct from your club balance (instant)',
              color: Colors.orange,
            ),

            const SizedBox(height: 24),

            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any notes about this payment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const Spacer(),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedPaymentMethod != null && !_isProcessing
                    ? _processPayment
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cricketGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _selectedPaymentMethod == PaymentMethod.UPI
                            ? 'Open UPI App'
                            : _selectedPaymentMethod == PaymentMethod.KITTY
                                ? 'Pay from Kitty'
                                : 'Record Cash Payment',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPaymentMethod == PaymentMethod.KITTY
                          ? 'Payment will be deducted immediately from your kitty balance.'
                          : 'Your payment will be confirmed by club admin.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
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

  Widget _buildPaymentMethodTile({
    required PaymentMethod paymentMethod,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedPaymentMethod == paymentMethod;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = paymentMethod;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withOpacity(0.1) : null,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: isSelected
              ? Icon(Icons.check_circle, color: color)
              : Icon(Icons.radio_button_unchecked, color: Colors.grey[400]),
        ),
      ),
    );
  }
}