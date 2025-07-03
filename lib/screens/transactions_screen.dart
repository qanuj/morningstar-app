import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';

class TransactionsScreen extends StatefulWidget {
  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final clubId = await AuthService.getCurrentClubId();
      if (clubId != null) {
        final response = await ApiService.get('/clubs/$clubId/transactions');
        setState(() {
          _transactions = (response['transactions'] as List)
              .map((tx) => Transaction.fromJson(tx))
              .toList();
          _balance = (response['balance'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: Column(
        children: [
          // Balance Card
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.cricketGreen, AppTheme.darkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cricketGreen.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '₹${_balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showTopUpDialog(),
                        icon: Icon(Icons.add, color: AppTheme.cricketGreen),
                        label: Text(
                          'Add Money',
                          style: TextStyle(color: AppTheme.cricketGreen),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.cricketGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          return _buildTransactionCard(transaction);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isCredit = transaction.type == 'CREDIT';
    final icon = _getTransactionIcon(transaction.purpose);
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCredit ? Colors.green[100] : Colors.red[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isCredit ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          transaction.description,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getPurposeText(transaction.purpose),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(transaction.createdAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransactionIcon(String purpose) {
    switch (purpose) {
      case 'MATCH_FEE':
        return Icons.sports_cricket;
      case 'MEMBERSHIP':
        return Icons.card_membership;
      case 'ORDER':
        return Icons.shopping_cart;
      case 'CLUB_TOPUP':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt;
    }
  }

  String _getPurposeText(String purpose) {
    switch (purpose) {
      case 'MATCH_FEE':
        return 'Match Fee';
      case 'MEMBERSHIP':
        return 'Membership Fee';
      case 'ORDER':
        return 'Store Order';
      case 'CLUB_TOPUP':
        return 'Wallet Top-up';
      default:
        return 'Other';
    }
  }

  void _showTopUpDialog() {
    final _amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Money to Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Note: This will create a transaction record. Please coordinate with your club admin for actual payment.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_amountController.text);
              if (amount != null && amount > 0) {
                Navigator.of(context).pop();
                await _topUpWallet(amount);
              }
            },
            child: Text('Add Money'),
          ),
        ],
      ),
    );
  }

  Future<void> _topUpWallet(double amount) async {
    try {
      final clubId = await AuthService.getCurrentClubId();
      await ApiService.post('/clubs/$clubId/topup', {'amount': amount});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Top-up request created successfully')),
      );
      
      await _loadTransactions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create top-up request: $e')),
      );
    }
  }
}
