import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../widgets/svg_avatar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/transactions_list_widget.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  TransactionsScreenState createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String _selectedType = 'all';
  String _selectedPeriod = 'all';
  String _searchQuery = '';
  String? _selectedClubId;

  // Temporary filter state for the filter sheet (before Apply is pressed)
  String _tempSelectedType = 'all';
  String _tempSelectedPeriod = 'all';
  String? _tempSelectedClubId;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  // Club balances from API

  final PageController _balancePageController = PageController();
  int _currentBalanceIndex = 0;

  // Club balances from API
  List<Map<String, dynamic>> _clubBalances = [
    {
      'id': 'all',
      'name': 'Total Balance',
      'logo': null,
      'credits': 0.0,
      'debits': 0.0,
      'balance': 0.0,
      'currency': 'Multi',
    },
  ];

  List<Map<String, dynamic>> _userClubs = [];

  // Infinite scroll
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadUserClubs();
    _loadTransactions();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadUserClubs() async {
    try {
      final response = await ApiService.get('/my/clubs');
      setState(() {
        _userClubs = (response['clubs'] as List<dynamic>? ?? [])
            .map((club) => club as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      // Handle error silently - fall back to existing logic
      // Error loading user clubs, will use fallback logic
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      _hasMoreData = true;
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
        final newTransactions = (response['transactions'] as List)
            .map((tx) => Transaction.fromJson(tx))
            .toList();

        if (isRefresh || _currentPage == 1) {
          _transactions = newTransactions;
        } else {
          _transactions.addAll(newTransactions);
        }

        // Update infinite scroll info
        final pagination = response['pagination'];
        _hasMoreData = pagination['hasNextPage'] ?? false;

        // Update summary and club balances from API response
        final summary = response['summary'];
        _updateClubBalancesFromApi(summary);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transactions: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  void _updateClubBalancesFromApi(Map<String, dynamic> summary) {
    final List<Map<String, dynamic>> balances = [];

    // Calculate total across all currencies (convert to a base currency or show separately)
    double totalCredits = 0.0;
    double totalDebits = 0.0;
    double totalBalance = 0.0;

    // Sum up all currencies for total (simplified - in real app might want to handle currencies separately)
    final byCurrency = summary['byCurrency'] as Map<String, dynamic>? ?? {};
    for (final currencyData in byCurrency.values) {
      totalCredits += (currencyData['totalCredits'] ?? 0).toDouble();
      totalDebits += (currencyData['totalDebits'] ?? 0).toDouble();
      totalBalance += (currencyData['netBalance'] ?? 0).toDouble();
    }

    // Add total balance card first
    balances.add({
      'id': 'all',
      'name': 'Total Balance',
      'logo': null,
      'credits': totalCredits,
      'debits': totalDebits,
      'balance': totalBalance,
      'currency': 'Multi', // Indicate multiple currencies but default to INR
    });

    // Add individual club balances from API
    final byClub = summary['byClub'] as List<dynamic>? ?? [];
    for (final club in byClub) {
      balances.add({
        'id': club['clubId'],
        'name': club['clubName'],
        'logo': club['clubLogo'],
        'credits': (club['totalCredits'] ?? 0).toDouble(),
        'debits': (club['totalDebits'] ?? 0).toDouble(),
        'balance': (club['netBalance'] ?? 0).toDouble(),
        'currency': club['currency'],
      });
    }

    _clubBalances = balances;
  }

  void _applyFilters() {
    _currentPage = 1;
    _hasMoreData = true;
    _loadTransactions();
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
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
        final newTransactions = (response['transactions'] as List)
            .map((tx) => Transaction.fromJson(tx))
            .toList();
        _transactions.addAll(newTransactions);

        final pagination = response['pagination'];
        _hasMoreData = pagination['hasNextPage'] ?? false;
      });
    } catch (e) {
      setState(() => _currentPage--); // Rollback page increment on error
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DuggyAppBar(
        subtitle: 'Kitty',
        actions: [
          // Search toggle button
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _searchController.clear();
                  _searchQuery = '';
                  _applyFilters();
                }
              });
            },
          ),
          // Filter button
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Collapsible Search Bar
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: _isSearchExpanded ? 60 : 0,
            child: _isSearchExpanded
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 16,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (value) {
                          _searchQuery = value;
                          _applyFilters();
                        },
                      ),
                    ),
                  )
                : SizedBox.shrink(),
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
                  ? Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surface
                          : Colors.grey[200],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
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
                                color: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.color,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Your transaction history will appear here',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surface
                          : Colors.grey[200],
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.all(16),
                        children: [
                          // Scrollable Balance Card
                          _buildBalanceCard(),

                          SizedBox(height: 16),

                          // Club Filter Indicator (only shown when explicitly filtered)
                          if (_selectedClubId != null) ...[
                            _buildClubFilterIndicator(),
                            SizedBox(height: 16),
                          ],

                          // Transaction List
                          ...TransactionsListWidget(
                            transactions: _transactions,
                            listType: TransactionListType.my,
                            isLoadingMore: _isLoadingMore,
                            hasMoreData: _hasMoreData,
                            currency: _clubBalances.isNotEmpty
                                ? _clubBalances[_currentBalanceIndex]['currency']
                                : null,
                          ).buildTransactionListItems(context),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    // Initialize temporary filters with current values
    setState(() {
      _tempSelectedType = _selectedType;
      _tempSelectedPeriod = _selectedPeriod;
      _tempSelectedClubId = _selectedClubId;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              // Fixed header with title and apply button
              Container(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.filter_list,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Filter Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.color,
                        ),
                      ),
                    ),
                    // Apply Button
                    ElevatedButton(
                      onPressed: () {
                        // Apply the temporary filters to actual filters
                        setState(() {
                          _selectedType = _tempSelectedType;
                          _selectedPeriod = _tempSelectedPeriod;
                          _selectedClubId = _tempSelectedClubId;
                        });
                        Navigator.pop(context);
                        _applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable filter content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          _buildTempFilterChip(
                            'All',
                            'all',
                            _tempSelectedType,
                            setModalState,
                            'type',
                          ),
                          SizedBox(width: 8),
                          _buildTempFilterChip(
                            'Credit',
                            'CREDIT',
                            _tempSelectedType,
                            setModalState,
                            'type',
                          ),
                          SizedBox(width: 8),
                          _buildTempFilterChip(
                            'Debit',
                            'DEBIT',
                            _tempSelectedType,
                            setModalState,
                            'type',
                          ),
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
                          _buildTempFilterChip(
                            'All',
                            'all',
                            _tempSelectedPeriod,
                            setModalState,
                            'period',
                          ),
                          _buildTempFilterChip(
                            'Week',
                            'week',
                            _tempSelectedPeriod,
                            setModalState,
                            'period',
                          ),
                          _buildTempFilterChip(
                            'Month',
                            'month',
                            _tempSelectedPeriod,
                            setModalState,
                            'period',
                          ),
                          _buildTempFilterChip(
                            '3 Months',
                            '3months',
                            _tempSelectedPeriod,
                            setModalState,
                            'period',
                          ),
                          _buildTempFilterChip(
                            'Year',
                            'year',
                            _tempSelectedPeriod,
                            setModalState,
                            'period',
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Club Filter
                      Text(
                        'Club',
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
                          _buildTempClubFilterChip(
                            'All Clubs',
                            null,
                            setModalState,
                          ),
                          ..._clubBalances
                              .where((club) => club['id'] != 'all')
                              .map(
                                (club) => _buildTempClubFilterChip(
                                  club['name'],
                                  club['id'],
                                  setModalState,
                                ),
                              ),
                        ],
                      ),
                      SizedBox(
                        height: 24,
                      ), // Space at the bottom for better scrolling
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method for temporary filter chips in the modal (before Apply is pressed)
  Widget _buildTempFilterChip(
    String label,
    String value,
    String currentValue,
    Function setModalState,
    String filterType,
  ) {
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
        setModalState(() {
          if (filterType == 'period') {
            _tempSelectedPeriod = value;
          } else if (filterType == 'type') {
            _tempSelectedType = value;
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
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor.withOpacity(0.3),
          width: 1,
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

  // Method for temporary club filter chips in the modal (before Apply is pressed)
  Widget _buildTempClubFilterChip(
    String label,
    String? clubId,
    Function setModalState,
  ) {
    final isSelected = _tempSelectedClubId == clubId;

    // Find the club data to get the logo
    final club = clubId == null
        ? null
        : _clubBalances.firstWhere(
            (club) => club['id'] == clubId,
            orElse: () => <String, dynamic>{},
          );

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (club != null && club['logo'] != null) ...[
            SVGAvatar(
              imageUrl: club['logo'],
              size: 16,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.1),
              fallbackIcon: Icons.account_balance,
              iconSize: 8,
            ),
            SizedBox(width: 6),
          ] else if (clubId == null) ...[
            Icon(
              Icons.all_inclusive,
              size: 14,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
            SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 11,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          _tempSelectedClubId = selected ? clubId : null;
        });
      },
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildClubFilterChip(String label, String? clubId) {
    final isSelected = _selectedClubId == clubId;

    // Find the club data to get the logo
    final club = clubId == null
        ? null
        : _clubBalances.firstWhere(
            (club) => club['id'] == clubId,
            orElse: () => <String, dynamic>{},
          );

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (club != null && club['logo'] != null) ...[
            SVGAvatar(
              imageUrl: club['logo'],
              size: 16,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.1),
              fallbackIcon: Icons.account_balance,
              iconSize: 8,
            ),
            SizedBox(width: 6),
          ] else if (clubId == null) ...[
            Icon(
              Icons.all_inclusive,
              size: 14,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
            SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 11,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedClubId = selected ? clubId : null;
        });
      },
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    // Use actual user clubs from API, fallback to balance clubs if not loaded yet
    final userClubCount = _userClubs.isNotEmpty
        ? _userClubs.length
        : _clubBalances.where((club) => club['id'] != 'all').length;
    final hasOnlyOneClub = userClubCount == 1;

    // If club filter is applied, show only that club's balance
    List<Map<String, dynamic>> displayBalances;
    if (_selectedClubId != null) {
      // Find the specific club and show only that club's balance
      displayBalances = _clubBalances
          .where((club) => club['id'] == _selectedClubId)
          .toList();
    } else if (hasOnlyOneClub) {
      // If user has only one club, show only that club (no total balance)
      displayBalances = _clubBalances
          .where((club) => club['id'] != 'all')
          .toList();
    } else {
      // Show all balances when no filter is applied and user has multiple clubs
      displayBalances = _clubBalances;
    }

    // If no balances to show, return empty container
    if (displayBalances.isEmpty) {
      displayBalances = [_clubBalances.first]; // Fallback to total balance
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          // Use flexible container instead of fixed height to avoid Android overflow
          displayBalances.length == 1
              ? _buildSingleBalanceCard(
                  displayBalances.first,
                ) // Show single card when filtered
              : SizedBox(
                  height: 120, // Keep fixed height only for PageView
                  child: PageView.builder(
                    // Show PageView when showing all balances
                    controller: _balancePageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentBalanceIndex = index;
                      });
                    },
                    itemCount: displayBalances.length,
                    itemBuilder: (context, index) {
                      final club = displayBalances[index];
                      return _buildSingleBalanceCard(club);
                    },
                  ),
                ),

          // Page indicators
          if (displayBalances.length > 1)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  displayBalances.length,
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
            ),
        ],
      ),
    );
  }

  Widget _buildSingleBalanceCard(Map<String, dynamic> club) {
    // Use actual user clubs from API to determine if pin should be shown
    final userClubCount = _userClubs.isNotEmpty
        ? _userClubs.length
        : _clubBalances.where((club) => club['id'] != 'all').length;
    final hasMultipleClubs = userClubCount > 1;

    return Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Club Info Row
          Row(
            children: [
              if (club['logo'] != null) ...[
                SVGAvatar(
                  imageUrl: club['logo'],
                  size: 24,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  fallbackIcon: Icons.account_balance,
                  iconSize: 12,
                ),
                SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  club['name'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Pin icon to apply club filter (only show for individual clubs when user has multiple clubs)
              if (club['id'] != 'all' && hasMultipleClubs)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedClubId = _selectedClubId == club['id']
                          ? null
                          : club['id'];
                    });
                    _applyFilters();
                  },
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      _selectedClubId == club['id']
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 16,
                      color: _selectedClubId == club['id']
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),

          // Balance Amount
          Text(
            _formatCurrencyAmount(club['balance'], club['currency']),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: club['balance'] >= 0
                  ? AppTheme.successGreen
                  : AppTheme.errorRed,
            ),
          ),
          Text(
            club['id'] == 'all' ? 'Total Balance' : 'Club Balance',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          SizedBox(height: 4),

          // Credits and Debits Row
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatCurrencyAmount(club['credits'], club['currency']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    Text(
                      'Credits',
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: Theme.of(context).dividerColor.withOpacity(0.3),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatCurrencyAmount(club['debits'], club['currency']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorRed,
                      ),
                    ),
                    Text(
                      'Debits',
                      style: TextStyle(
                        fontSize: 9,
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
    );
  }

  Widget _buildClubFilterIndicator() {
    final currentClub = _clubBalances.firstWhere(
      (club) => club['id'] == _selectedClubId,
      orElse: () => {'name': 'Unknown Club'},
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing transactions for: ${currentClub['name']}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Reset to show all clubs
              setState(() {
                _selectedClubId = null;
              });

              // Reload transactions to show all clubs
              _loadTransactions();
            },
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrencyAmount(double amount, String? currency) {
    switch (currency) {
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'GBP':
        return '£${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      case 'INR':
        return '₹${amount.toStringAsFixed(2)}';
      case 'Multi':
        return '₹${amount.toStringAsFixed(2)}'; // Fallback to INR for multi-currency totals
      default:
        return '₹${amount.toStringAsFixed(2)}'; // Default to INR
    }
  }
}
