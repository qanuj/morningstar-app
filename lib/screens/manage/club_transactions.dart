import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../widgets/svg_avatar.dart';
import '../../services/api_service.dart';
import '../../widgets/transactions_list_widget.dart';
import '../../models/transaction.dart';

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
      // Build API endpoint with query parameters for club transactions
      final params = {
        'page': _currentPage.toString(),
        'limit': _itemsPerPage.toString(),
        'all': 'true', // Get all club transactions for admin view
      };
      
      if (_selectedPeriod != 'all') {
        params['period'] = _selectedPeriod;
      }
      if (_searchQuery.isNotEmpty) {
        params['search'] = _searchQuery;
      }
      
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final response = await ApiService.get('/clubs/${widget.club.id}/transactions?$queryString');
      
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
        _transactions = _generateMockTransactions();
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

  List<Transaction> _generateMockTransactions() {
    return [
      Transaction(
        id: '1',
        userId: 'M001',
        clubId: widget.club.id,
        amount: 2500.0,
        type: 'CREDIT',
        purpose: 'Membership Fee',
        description: 'Monthly membership fee from John Doe',
        createdAt: DateTime.now().subtract(Duration(hours: 2)),
        user: UserModel(
          id: 'M001',
          name: 'John Doe',
          profilePicture: null,
        ),
        club: ClubModel(
          id: widget.club.id,
          name: widget.club.name,
          logo: widget.club.logo,
        ),
      ),
      Transaction(
        id: '2',
        userId: 'system',
        clubId: widget.club.id,
        amount: 450.0,
        type: 'DEBIT',
        purpose: 'Equipment',
        description: 'Purchase of cricket balls and stumps',
        createdAt: DateTime.now().subtract(Duration(hours: 5)),
        user: null,
        club: ClubModel(
          id: widget.club.id,
          name: widget.club.name,
          logo: widget.club.logo,
        ),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF003f9b),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            // Club Logo
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: widget.club.logo != null && widget.club.logo!.isNotEmpty
                    ? _buildClubLogo()
                    : _buildDefaultClubLogo(),
              ),
            ),
            const SizedBox(width: 12),
            // Club Name and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.club.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Transactions',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off : Icons.search, color: Colors.white),
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
            icon: Icon(Icons.filter_list, color: Colors.white),
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

          // Summary Card - Wallet Style
          _buildBalanceCard(currency, totalCredit, totalDebit, netBalance),

          // Filter Chips - Only Period filter
          if (_selectedPeriod != 'all')
            Container(
              height: 50,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
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
              color: Color(0xFF003f9b),
              backgroundColor: Colors.white,
              child: _isLoading && _transactions.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF003f9b),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _transactions.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF003f9b).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_outlined,
                                    size: 64,
                                    color: Color(0xFF003f9b),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No transactions found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                    color: Theme.of(context).textTheme.titleLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedPeriod != 'all'
                                      ? 'Try adjusting your filters or search query'
                                      : 'Club transactions will appear here',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ...TransactionsListWidget(
                          transactions: _transactions,
                          listType: TransactionListType.club,
                          isLoadingMore: _isLoadingMore,
                          hasMoreData: _pagination['hasNextPage'] ?? false,
                          currency: widget.club.membershipFeeCurrency,
                        ).buildTransactionListItems(context),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String currency, double totalCredits, double totalDebits, double netBalance) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.06),
            blurRadius: 16,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Club Info Row
            Row(
              children: [
                // Club Avatar
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.club.logo != null && widget.club.logo!.isNotEmpty
                        ? _buildSmallClubLogo()
                        : _buildSmallDefaultClubLogo(),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.club.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            // Balance Amount
            Text(
              _formatCurrency(netBalance, currency),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: netBalance >= 0 ? Colors.green : Colors.red,
              ),
            ),
            Text(
              'Club Balance',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 12),
            
            // Credits and Debits Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _formatCurrency(totalCredits, currency),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Total Income',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _formatCurrency(totalDebits, currency),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Total Expense',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
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

  Widget _buildSmallClubLogo() {
    // Check if the URL is an SVG
    if (widget.club.logo!.toLowerCase().contains('.svg') || 
        widget.club.logo!.toLowerCase().contains('svg?')) {
      return SvgPicture.network(
        widget.club.logo!,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildSmallDefaultClubLogo(),
      );
    } else {
      // Regular image (PNG, JPG, etc.)
      return Image.network(
        widget.club.logo!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildSmallDefaultClubLogo();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildSmallDefaultClubLogo();
        },
      );
    }
  }

  Widget _buildSmallDefaultClubLogo() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.club.name.isNotEmpty
              ? widget.club.name.substring(0, 1).toUpperCase()
              : 'C',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
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



  Widget _buildDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (transactionDate == today) {
      dateText = 'Today';
    } else if (transactionDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM dd, yyyy').format(date);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        dateText,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)
              : Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildWalletStyleTransactionCard(Transaction transaction) {
    final isCredit = transaction.type == 'CREDIT';
    final icon = _getTransactionIcon(transaction.purpose);
    final createdAt = transaction.createdAt;
    final currency = widget.club.membershipFeeCurrency ?? 'INR';

    return Container(
      margin: EdgeInsets.only(bottom: 8, left: 12, right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // User Avatar with Transaction Badge
            Stack(
              children: [
                // User Avatar from transaction data
                SVGAvatar(
                  imageUrl: transaction.user?.profilePicture,
                  size: 40,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  fallbackIcon: transaction.user != null ? Icons.person : Icons.account_balance,
                  iconSize: 24,
                ),
                // Transaction Badge
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isCredit ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).cardColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12),

            // Transaction Info (Center)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    transaction.user != null 
                        ? transaction.user!.name
                        : transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      height: 1.2,
                    ),
                  ),
                  if (transaction.user != null) ...[
                    SizedBox(height: 2),
                    Text(
                      transaction.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        height: 1.2,
                      ),
                    ),
                  ],
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.15)
                          : Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getPurposeText(transaction.purpose),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.9)
                            : Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Amount and Time (Right)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}${_formatCurrency(transaction.amount, currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  DateFormat('hh:mm a').format(createdAt),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF003f9b),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading more transactions...',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
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



  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  Widget _buildClubLogo() {
    // Check if the URL is an SVG
    if (widget.club.logo!.toLowerCase().contains('.svg') || 
        widget.club.logo!.toLowerCase().contains('svg?')) {
      return SvgPicture.network(
        widget.club.logo!,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildDefaultClubLogo(),
      );
    } else {
      // Regular image (PNG, JPG, etc.)
      return Image.network(
        widget.club.logo!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultClubLogo();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildDefaultClubLogo();
        },
      );
    }
  }

  Widget _buildDefaultClubLogo() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.club.name.isNotEmpty
              ? widget.club.name.substring(0, 1).toUpperCase()
              : 'C',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}