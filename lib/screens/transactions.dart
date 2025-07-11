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
  String _selectedType = 'all';
  String _selectedPeriod = 'all';
  String _searchQuery = '';
  String? _selectedClubId;
  TextEditingController _searchController = TextEditingController();

  // Summary data
  double _totalCredits = 0.0;
  double _totalDebits = 0.0;
  double _netBalance = 0.0;
  int _totalTransactions = 0;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _hasPrevPage = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
    }

    setState(() => _isLoading = true);

    try {
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'limit': '20',
      };

      if (_selectedType != 'all') {
        queryParams['type'] = _selectedType;
      }

      if (_selectedPeriod != 'all') {
        queryParams['period'] = _selectedPeriod;
      }

      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }

      if (_selectedClubId != null) {
        queryParams['clubId'] = _selectedClubId!;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await ApiService.get('/transactions?$queryString');
      
      setState(() {
        _transactions = (response['transactions'] as List)
            .map((tx) => Transaction.fromJson(tx))
            .toList();
        
        // Update pagination info
        final pagination = response['pagination'];
        _currentPage = pagination['currentPage'];
        _totalPages = pagination['totalPages'];
        _hasNextPage = pagination['hasNextPage'];
        _hasPrevPage = pagination['hasPrevPage'];
        _totalTransactions = pagination['totalCount'];

        // Update summary
        final summary = response['summary'];
        _totalCredits = (summary['totalCredits'] ?? 0).toDouble();
        _totalDebits = (summary['totalDebits'] ?? 0).toDouble();
        _netBalance = (summary['netBalance'] ?? 0).toDouble();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  void _applyFilters() {
    _currentPage = 1;
    _loadTransactions();
  }

  void _loadNextPage() {
    if (_hasNextPage) {
      _currentPage++;
      _loadTransactions();
    }
  }

  void _loadPreviousPage() {
    if (_hasPrevPage) {
      _currentPage--;
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Transactions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.primaryTextColor,
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cricketGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.filter_list,
                color: AppTheme.cricketGreen,
                size: 20,
              ),
            ),
            onPressed: _showFilterBottomSheet,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadTransactions(isRefresh: true),
        color: AppTheme.cricketGreen,
        child: Column(
          children: [
            // Search Bar
            Container(
              margin: EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.cricketGreen,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppTheme.secondaryTextColor,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _applyFilters();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.dividerColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.dividerColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.cricketGreen,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                ),
                onSubmitted: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
              ),
            ),

            // Summary Card
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(24),
              decoration: AppTheme.gradientDecoration.copyWith(
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cricketGreen.withOpacity(0.2),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Net Balance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '₹${_netBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Credits',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹${_totalCredits.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Debits',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹${_totalDebits.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$_totalTransactions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

            SizedBox(height: 16),

            // Transactions List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppTheme.cricketGreen,
                      ),
                    )
                  : _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: AppTheme.cricketGreen.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: AppTheme.cricketGreen,
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                'No transactions found',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryTextColor,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Your transaction history will appear here',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _transactions.length + 1, // +1 for pagination
                          itemBuilder: (context, index) {
                            if (index == _transactions.length) {
                              return _buildPaginationWidget();
                            }
                            final transaction = _transactions[index];
                            return _buildTransactionCard(transaction);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isCredit = transaction.type == 'CREDIT';
    final icon = _getTransactionIcon(transaction.purpose);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: AppTheme.softCardDecoration,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCredit 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCredit 
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                color: isCredit ? Colors.green : Colors.red,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            
            // Transaction Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cricketGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getPurposeText(transaction.purpose),
                          style: TextStyle(
                            color: AppTheme.cricketGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (transaction.club != null) ...[
                        SizedBox(width: 8),
                        Text(
                          '• ${transaction.club!.name}',
                          style: TextStyle(
                            color: AppTheme.secondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(transaction.createdAt),
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationWidget() {
    if (_totalPages <= 1) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: AppTheme.softCardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _hasPrevPage ? _loadPreviousPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cricketGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text('Previous'),
          ),
          Text(
            'Page $_currentPage of $_totalPages',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryTextColor,
            ),
          ),
          ElevatedButton(
            onPressed: _hasNextPage ? _loadNextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cricketGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text('Next'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cricketGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.filter_list,
                    color: AppTheme.cricketGreen,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Filter Transactions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Type Filter
            Text(
              'Transaction Type',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildFilterChip('All', 'all', _selectedType),
                SizedBox(width: 8),
                _buildFilterChip('Credit', 'CREDIT', _selectedType),
                SizedBox(width: 8),
                _buildFilterChip('Debit', 'DEBIT', _selectedType),
              ],
            ),
            SizedBox(height: 24),
            
            // Period Filter
            Text(
              'Time Period',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('All', 'all', _selectedPeriod),
                _buildFilterChip('Week', 'week', _selectedPeriod),
                _buildFilterChip('Month', 'month', _selectedPeriod),
                _buildFilterChip('3 Months', '3months', _selectedPeriod),
                _buildFilterChip('Year', 'year', _selectedPeriod),
              ],
            ),
            SizedBox(height: 32),
            
            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _applyFilters();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cricketGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Apply Filters',
                  style: TextStyle(
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

  Widget _buildFilterChip(String label, String value, String currentValue) {
    final isSelected = currentValue == value;
    return Container(
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isSelected ? AppTheme.cricketGreen : AppTheme.primaryTextColor,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (label == 'All' || label == 'Week' || label == 'Month' || label == '3 Months' || label == 'Year') {
              _selectedPeriod = value;
            } else {
              _selectedType = value;
            }
          });
        },
        selectedColor: AppTheme.cricketGreen.withOpacity(0.2),
        backgroundColor: AppTheme.backgroundColor,
        checkmarkColor: AppTheme.cricketGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected 
              ? AppTheme.cricketGreen.withOpacity(0.5)
              : AppTheme.dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
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
}