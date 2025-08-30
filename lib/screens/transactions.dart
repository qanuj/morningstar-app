import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/duggy_logo.dart';

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

  PageController _balancePageController = PageController();
  int _currentBalanceIndex = 0;

  // Sample club balances - in real app this would come from API
  List<Map<String, dynamic>> _clubBalances = [
    {
      'id': 'all',
      'name': 'Total Balance',
      'logo': null,
      'credits': 0.0,
      'debits': 0.0,
      'balance': 0.0,
    },
  ];
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

        // Update club balances
        _updateClubBalances();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  void _updateClubBalances() {
    // Get unique clubs from transactions
    final clubMap = <String, Map<String, dynamic>>{};

    // Initialize total balance
    clubMap['all'] = {
      'id': 'all',
      'name': 'Total Balance',
      'logo': null,
      'credits': _totalCredits,
      'debits': _totalDebits,
      'balance': _netBalance,
    };

    // Calculate individual club balances
    for (final transaction in _transactions) {
      if (transaction.club != null) {
        final clubId = transaction.club!.id;
        if (!clubMap.containsKey(clubId)) {
          clubMap[clubId] = {
            'id': clubId,
            'name': transaction.club!.name,
            'logo': transaction.club!.logo,
            'credits': 0.0,
            'debits': 0.0,
            'balance': 0.0,
          };
        }

        if (transaction.type == 'CREDIT') {
          clubMap[clubId]!['credits'] += transaction.amount;
        } else {
          clubMap[clubId]!['debits'] += transaction.amount;
        }

        clubMap[clubId]!['balance'] =
            clubMap[clubId]!['credits'] - clubMap[clubId]!['debits'];
      }
    }

    _clubBalances = clubMap.values.toList();
  }

  Map<String, List<Transaction>> _groupTransactionsByDate(
    List<Transaction> transactions,
  ) {
    final Map<String, List<Transaction>> groupedTransactions = {};

    for (final transaction in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.createdAt);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    return groupedTransactions;
  }

  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  Widget _buildDateHeader(String dateKey) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatDateHeader(dateKey),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)
              : Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  int _getChildCount() {
    final groupedTransactions = _groupTransactionsByDate(_transactions);
    int count = 0;

    // Date headers + transactions count
    for (final entry in groupedTransactions.entries) {
      count += 1; // Date header
      count += entry.value.length; // Transactions
    }

    count += 1; // Pagination widget
    return count;
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
    return Column(
        children: [
          // Search header
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).iconTheme.color,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1,
                          ),
                        ),
                      ),
                      onSubmitted: (value) {
                        _searchQuery = value;
                        _applyFilters();
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)
                        : Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadTransactions(isRefresh: true),
              color: Theme.of(context).colorScheme.primary,
              child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
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
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No transactions found',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your transaction history will appear here',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  // Swipeable Balance Cards
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Container(
                          height: 180,
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: PageView.builder(
                            controller: _balancePageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentBalanceIndex = index;
                              });
                            },
                            itemCount: _clubBalances.length,
                            itemBuilder: (context, index) {
                              final club = _clubBalances[index];
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      AppTheme.darkBlue,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Club info
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (club['logo'] != null) ...[
                                          Container(
                                            width: 24,
                                            height: 24,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child:
                                                  club['logo'].startsWith(
                                                    'http',
                                                  )
                                                  ? Image.network(
                                                      club['logo'],
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return DuggyLogoVariant.small();
                                                          },
                                                    )
                                                  : DuggyLogoVariant.small(),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                        ],
                                        Text(
                                          club['name'],
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '₹${club['balance'].toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
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
                                                  color: Theme.of(context).colorScheme.onPrimary
                                                      .withOpacity(0.8),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                '₹${club['credits'].toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 40,
                                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
                                        ),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                'Debits',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onPrimary
                                                      .withOpacity(0.8),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                '₹${club['debits'].toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Page indicators
                        if (_clubBalances.length > 1) ...[
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _clubBalances.length,
                              (index) => Container(
                                width: 8,
                                height: 8,
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentBalanceIndex == index
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Transaction List with Date Groups
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final groupedTransactions = _groupTransactionsByDate(
                        _transactions,
                      );
                      final sortedDateKeys = groupedTransactions.keys.toList()
                        ..sort((a, b) => b.compareTo(a)); // Latest first

                      int currentIndex = 0;

                      for (final dateKey in sortedDateKeys) {
                        final transactions = groupedTransactions[dateKey]!;

                        // Date header
                        if (index == currentIndex) {
                          return _buildDateHeader(dateKey);
                        }
                        currentIndex++;

                        // Transaction cards for this date
                        for (int i = 0; i < transactions.length; i++) {
                          if (index == currentIndex) {
                            return _buildTransactionCard(transactions[i]);
                          }
                          currentIndex++;
                        }
                      }

                      // Pagination widget at the end
                      if (index == currentIndex) {
                        return _buildPaginationWidget();
                      }

                      return Container(); // Should never reach here
                    }, childCount: _getChildCount()),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isCredit = transaction.type == 'CREDIT';
    final icon = _getTransactionIcon(transaction.purpose);

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
            // Club Icon with Transaction Badge
            Stack(
              children: [
                // Club Icon (bigger)
                Container(
                  width: 40,
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child:
                        transaction.club != null &&
                            transaction.club!.logo != null
                        ? (transaction.club!.logo!.startsWith('http')
                              ? Image.network(
                                  transaction.club!.logo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return DuggyLogoVariant.medium();
                                  },
                                )
                              : DuggyLogoVariant.medium())
                        : DuggyLogoVariant.medium(),
                  ),
                ),
                // Transaction Badge
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context).cardColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 10),
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
                    transaction.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      height: 1.2,
                    ),
                  ),
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
                  '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  DateFormat('hh:mm a').format(transaction.createdAt),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
              fontWeight: FontWeight.w400,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          ElevatedButton(
            onPressed: _hasNextPage ? _loadNextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.filter_list,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Filter Transactions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).textTheme.headlineSmall?.color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Type Filter
            Text(
              'Transaction Type',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: Theme.of(context).textTheme.titleMedium?.color,
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
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: Theme.of(context).textTheme.titleMedium?.color,
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Apply Filters',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
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
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w400,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (label == 'All' ||
              label == 'Week' ||
              label == 'Month' ||
              label == '3 Months' ||
              label == 'Year') {
            _selectedPeriod = value;
          } else {
            _selectedType = value;
          }
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).dividerColor.withOpacity(0.3),
          width: 0.5,
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
