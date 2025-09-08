import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/api_service.dart';

class ClubTransactionsScreen extends StatefulWidget {
  final dynamic club; // Using dynamic to avoid dependency issues for now

  const ClubTransactionsScreen({
    super.key,
    required this.club,
  });

  @override
  ClubTransactionsScreenState createState() => ClubTransactionsScreenState();
}

class ClubTransactionsScreenState extends State<ClubTransactionsScreen> {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<Transaction> _transactions = [];
  String _selectedType = 'all';
  String _selectedPeriod = 'all';
  String _searchQuery = '';
  bool _showSearch = false;
  
  // API Response data
  Map<String, dynamic> _summaryByCurrency = {};
  Map<String, dynamic> _pagination = {
    'currentPage': 1,
    'totalPages': 1,
    'totalCount': 0,
    'hasNextPage': false,
    'hasPrevPage': false
  };
  
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _pagination['hasNextPage'] == true) {
        _loadMoreTransactions();
      }
    }
  }

  Future<void> _loadTransactions([bool isRefresh = false]) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _transactions.clear();
      });
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Build API endpoint with query parameters
      final params = {
        'page': _currentPage.toString(),
        'limit': _itemsPerPage.toString(),
        'clubId': widget.club.id,
      };
      
      if (_selectedType != 'all') {
        params['type'] = _selectedType.toUpperCase();
      }
      if (_selectedPeriod != 'all') {
        params['period'] = _selectedPeriod;
      }
      if (_searchQuery.isNotEmpty) {
        params['search'] = _searchQuery;
      }
      
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final response = await ApiService.get('/transactions?$queryString');
      
      if (response['transactions'] != null) {
        final List<dynamic> transactionData = response['transactions'];
        final newTransactions = transactionData.map((data) => Transaction.fromJson(data)).toList();
        
        setState(() {
          if (isRefresh || _currentPage == 1) {
            _transactions = newTransactions;
          } else {
            _transactions.addAll(newTransactions);
          }
          
          _pagination = response['pagination'] ?? _pagination;
          _summaryByCurrency = response['summary']?['byCurrency'] ?? {};
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      // Fall back to mock data on error
      if (_transactions.isEmpty) {
        _transactions = _generateMockTransactions().map((ct) => Transaction(
          id: ct.id,
          amount: ct.amount,
          type: ct.type == 'Credit' ? 'CREDIT' : 'DEBIT',
          purpose: ct.category,
          description: ct.description,
          createdAt: ct.date.toIso8601String(),
          club: ClubInfo(
            id: widget.club.id,
            name: widget.club.name,
            logo: widget.club.logo,
            membershipFeeCurrency: widget.club.membershipFeeCurrency ?? 'INR',
          ),
        )).toList();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || _pagination['hasNextPage'] != true) return;
    
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadTransactions();
    setState(() => _isLoadingMore = false);
  }

  List<ClubTransaction> _generateMockTransactions() {
    return [
      ClubTransaction(
        id: '1',
        amount: 2500.0,
        type: 'Credit',
        category: 'Membership Fee',
        description: 'Monthly membership fee from John Doe',
        memberName: 'John Doe',
        memberId: 'M001',
        date: DateTime.now().subtract(Duration(hours: 2)),
        status: 'Completed',
      ),
      ClubTransaction(
        id: '2',
        amount: 450.0,
        type: 'Debit',
        category: 'Equipment',
        description: 'Purchase of cricket balls and stumps',
        memberName: null,
        memberId: null,
        date: DateTime.now().subtract(Duration(hours: 5)),
        status: 'Completed',
      ),
    ];
  }

  String _formatCurrency(double amount, String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      case 'GBP':
        return '£${amount.toStringAsFixed(2)}';
      case 'INR':
      default:
        return '₹${amount.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.club.membershipFeeCurrency ?? 'INR';
    final summary = _summaryByCurrency[currency] ?? {
      'totalCredits': 0.0,
      'totalDebits': 0.0,
      'netBalance': 0.0
    };
    
    final totalCredit = summary['totalCredits']?.toDouble() ?? 0.0;
    final totalDebit = summary['totalDebits']?.toDouble() ?? 0.0;
    final netBalance = summary['netBalance']?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Club Transactions',
        customActions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _loadTransactions();
                }
              });
            },
            tooltip: _showSearch ? 'Hide Search' : 'Search',
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar (conditionally shown)
          if (_showSearch)
            Container(
              padding: EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                            _loadTransactions();
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                onSubmitted: (value) {
                  _loadTransactions();
                },
              ),
            ),

          // Summary Cards
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Income',
                    _formatCurrency(totalCredit, currency),
                    Colors.green,
                    Icons.trending_up,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Expense',
                    _formatCurrency(totalDebit, currency),
                    Colors.red,
                    Icons.trending_down,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Net Balance',
                    _formatCurrency(netBalance, currency),
                    netBalance >= 0 ? Colors.green : Colors.red,
                    Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All', 'all'),
                SizedBox(width: 8),
                _buildFilterChip('Credits', 'credit'),
                SizedBox(width: 8),
                _buildFilterChip('Debits', 'debit'),
                SizedBox(width: 16),
                if (_selectedPeriod != 'all')
                  Chip(
                    label: Text(
                      _getPeriodDisplayName(_selectedPeriod),
                      style: TextStyle(fontSize: 12),
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedPeriod = 'all';
                      });
                      _loadTransactions();
                    },
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                  ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadTransactions(true),
              color: Theme.of(context).primaryColor,
              child: _isLoading && _transactions.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : _transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Theme.of(context).disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions found',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty || _selectedType != 'all' || _selectedPeriod != 'all'
                                ? 'Try adjusting your filters or search query'
                                : 'Club transactions will appear here',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _transactions.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _transactions.length) {
                          return Container(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          );
                        }
                        final transaction = _transactions[index];
                        return _buildTransactionCard(transaction, currency);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getPeriodDisplayName(String period) {
    switch (period) {
      case 'week':
        return 'Last Week';
      case 'month':
        return 'Last Month';
      case '3months':
        return '3 Months';
      case 'year':
        return 'Last Year';
      default:
        return 'All Time';
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedType = value;
          _currentPage = 1;
          _transactions.clear();
        });
        _loadTransactions();
      },
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction, String currency) {
    final isCredit = transaction.type == 'CREDIT';
    final color = isCredit ? Colors.green : Colors.red;
    final icon = isCredit ? Icons.add_circle : Icons.remove_circle;
    final createdAt = DateTime.parse(transaction.createdAt);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transaction Icon
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),

                SizedBox(width: 12),

                // Transaction Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount
                      Text(
                        '${isCredit ? '+' : '-'}${_formatCurrency(transaction.amount, currency)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),

                      SizedBox(height: 4),

                      // Purpose
                      if (transaction.purpose.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.purpose,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),

                      SizedBox(height: 6),

                      // Description
                      Text(
                        transaction.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 8),

                      // Date and Time
                      Text(
                        _formatDateTime(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
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
    );
  }


  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Transaction Type
            ListTile(
              leading: Icon(Icons.swap_horiz),
              title: Text('Transaction Type'),
              subtitle: DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: 'all', child: Text('All Types')),
                  DropdownMenuItem(value: 'credit', child: Text('Credits Only')),
                  DropdownMenuItem(value: 'debit', child: Text('Debits Only')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value ?? 'all';
                  });
                },
              ),
            ),
            
            // Time Period
            ListTile(
              leading: Icon(Icons.date_range),
              title: Text('Time Period'),
              subtitle: DropdownButton<String>(
                value: _selectedPeriod,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: 'week', child: Text('Last Week')),
                  DropdownMenuItem(value: 'month', child: Text('Last Month')),
                  DropdownMenuItem(value: '3months', child: Text('3 Months')),
                  DropdownMenuItem(value: 'year', child: Text('Last Year')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value ?? 'all';
                  });
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedType = 'all';
                _selectedPeriod = 'all';
                _currentPage = 1;
                _transactions.clear();
              });
              _loadTransactions();
              Navigator.pop(context);
            },
            child: Text('Clear All'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentPage = 1;
                _transactions.clear();
              });
              _loadTransactions();
              Navigator.pop(context);
            },
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }
}

// Model classes matching the API response
class Transaction {
  final String id;
  final double amount;
  final String type; // 'CREDIT' or 'DEBIT'
  final String purpose;
  final String description;
  final String createdAt;
  final ClubInfo club;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.purpose,
    required this.description,
    required this.createdAt,
    required this.club,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type']?.toString() ?? 'DEBIT',
      purpose: json['purpose']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      club: ClubInfo.fromJson(json['club'] ?? {}),
    );
  }
}

class ClubInfo {
  final String id;
  final String name;
  final String? logo;
  final String membershipFeeCurrency;

  ClubInfo({
    required this.id,
    required this.name,
    this.logo,
    required this.membershipFeeCurrency,
  });

  factory ClubInfo.fromJson(Map<String, dynamic> json) {
    return ClubInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString(),
      membershipFeeCurrency: json['membershipFeeCurrency']?.toString() ?? 'INR',
    );
  }
}

// Mock model class for ClubTransaction (fallback)
class ClubTransaction {
  final String id;
  final double amount;
  final String type; // 'Credit' or 'Debit'
  final String category;
  final String description;
  final String? memberName;
  final String? memberId;
  final DateTime date;
  final String status; // 'Completed', 'Pending', 'Failed'

  ClubTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    this.memberName,
    this.memberId,
    required this.date,
    required this.status,
  });
}