import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String _selectedType = 'all';
  String _selectedPeriod = 'all';
  String _searchQuery = '';
  String? _selectedClubId;
  
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

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String get selectedType => _selectedType;
  String get selectedPeriod => _selectedPeriod;
  String get searchQuery => _searchQuery;
  String? get selectedClubId => _selectedClubId;
  
  double get totalCredits => _totalCredits;
  double get totalDebits => _totalDebits;
  double get netBalance => _netBalance;
  int get totalTransactions => _totalTransactions;
  
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasNextPage => _hasNextPage;
  bool get hasPrevPage => _hasPrevPage;

  void setSelectedType(String type) {
    _selectedType = type;
    notifyListeners();
  }

  void setSelectedPeriod(String period) {
    _selectedPeriod = period;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedClubId(String? clubId) {
    _selectedClubId = clubId;
    notifyListeners();
  }

  void clearFilters() {
    _selectedType = 'all';
    _selectedPeriod = 'all';
    _searchQuery = '';
    _selectedClubId = null;
    notifyListeners();
  }

  Future<void> loadTransactions({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
    }

    _isLoading = true;
    notifyListeners();

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
    } catch (e) {
      print('Error loading transactions: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadNextPage() async {
    if (_hasNextPage && !_isLoading) {
      _currentPage++;
      await loadTransactions();
    }
  }

  Future<void> loadPreviousPage() async {
    if (_hasPrevPage && !_isLoading) {
      _currentPage--;
      await loadTransactions();
    }
  }

  Future<void> applyFilters() async {
    _currentPage = 1;
    await loadTransactions();
  }

  String getTransactionPurposeText(String purpose) {
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