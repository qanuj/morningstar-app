import 'package:flutter/material.dart';

class FilterProvider with ChangeNotifier {
  // Transaction filters
  String _transactionType = 'all';
  String _transactionPeriod = 'all';
  String? _transactionClubId;
  
  // Match filters
  String _matchType = 'all';
  String _matchStatus = 'all';
  DateTime? _matchDateFrom;
  DateTime? _matchDateTo;
  
  // Store filters
  String _storeCategory = 'all';
  String _storeAvailability = 'all';
  double _storePriceMin = 0;
  double _storePriceMax = 10000;
  
  // Poll filters
  String _pollStatus = 'all';
  String _pollType = 'all';
  bool _pollShowVoted = true;
  bool _pollShowUnvoted = true;
  
  // Notification filters
  String _notificationStatus = 'all';
  String _notificationType = 'all';
  String? _notificationClubId;
  
  // General filters
  String _sortBy = 'date';
  String _sortOrder = 'desc';

  // Transaction filter getters
  String get transactionType => _transactionType;
  String get transactionPeriod => _transactionPeriod;
  String? get transactionClubId => _transactionClubId;
  
  // Match filter getters
  String get matchType => _matchType;
  String get matchStatus => _matchStatus;
  DateTime? get matchDateFrom => _matchDateFrom;
  DateTime? get matchDateTo => _matchDateTo;
  
  // Store filter getters
  String get storeCategory => _storeCategory;
  String get storeAvailability => _storeAvailability;
  double get storePriceMin => _storePriceMin;
  double get storePriceMax => _storePriceMax;
  
  // Poll filter getters
  String get pollStatus => _pollStatus;
  String get pollType => _pollType;
  bool get pollShowVoted => _pollShowVoted;
  bool get pollShowUnvoted => _pollShowUnvoted;
  
  // Notification filter getters
  String get notificationStatus => _notificationStatus;
  String get notificationType => _notificationType;
  String? get notificationClubId => _notificationClubId;
  
  // General filter getters
  String get sortBy => _sortBy;
  String get sortOrder => _sortOrder;

  // Transaction filter setters
  void setTransactionType(String type) {
    _transactionType = type;
    notifyListeners();
  }

  void setTransactionPeriod(String period) {
    _transactionPeriod = period;
    notifyListeners();
  }

  void setTransactionClubId(String? clubId) {
    _transactionClubId = clubId;
    notifyListeners();
  }

  // Match filter setters
  void setMatchType(String type) {
    _matchType = type;
    notifyListeners();
  }

  void setMatchStatus(String status) {
    _matchStatus = status;
    notifyListeners();
  }

  void setMatchDateRange(DateTime? from, DateTime? to) {
    _matchDateFrom = from;
    _matchDateTo = to;
    notifyListeners();
  }

  // Store filter setters
  void setStoreCategory(String category) {
    _storeCategory = category;
    notifyListeners();
  }

  void setStoreAvailability(String availability) {
    _storeAvailability = availability;
    notifyListeners();
  }

  void setStorePriceRange(double min, double max) {
    _storePriceMin = min;
    _storePriceMax = max;
    notifyListeners();
  }

  // Poll filter setters
  void setPollStatus(String status) {
    _pollStatus = status;
    notifyListeners();
  }

  void setPollType(String type) {
    _pollType = type;
    notifyListeners();
  }

  void setPollShowVoted(bool show) {
    _pollShowVoted = show;
    notifyListeners();
  }

  void setPollShowUnvoted(bool show) {
    _pollShowUnvoted = show;
    notifyListeners();
  }

  // Notification filter setters
  void setNotificationStatus(String status) {
    _notificationStatus = status;
    notifyListeners();
  }

  void setNotificationType(String type) {
    _notificationType = type;
    notifyListeners();
  }

  void setNotificationClubId(String? clubId) {
    _notificationClubId = clubId;
    notifyListeners();
  }

  // General filter setters
  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void setSortOrder(String order) {
    _sortOrder = order;
    notifyListeners();
  }

  void toggleSortOrder() {
    _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
    notifyListeners();
  }

  // Reset methods
  void resetTransactionFilters() {
    _transactionType = 'all';
    _transactionPeriod = 'all';
    _transactionClubId = null;
    notifyListeners();
  }

  void resetMatchFilters() {
    _matchType = 'all';
    _matchStatus = 'all';
    _matchDateFrom = null;
    _matchDateTo = null;
    notifyListeners();
  }

  void resetStoreFilters() {
    _storeCategory = 'all';
    _storeAvailability = 'all';
    _storePriceMin = 0;
    _storePriceMax = 10000;
    notifyListeners();
  }

  void resetPollFilters() {
    _pollStatus = 'all';
    _pollType = 'all';
    _pollShowVoted = true;
    _pollShowUnvoted = true;
    notifyListeners();
  }

  void resetNotificationFilters() {
    _notificationStatus = 'all';
    _notificationType = 'all';
    _notificationClubId = null;
    notifyListeners();
  }

  void resetAllFilters() {
    resetTransactionFilters();
    resetMatchFilters();
    resetStoreFilters();
    resetPollFilters();
    resetNotificationFilters();
    _sortBy = 'date';
    _sortOrder = 'desc';
    notifyListeners();
  }

  // Filter state checking methods
  bool get hasTransactionFilters => 
    _transactionType != 'all' || 
    _transactionPeriod != 'all' || 
    _transactionClubId != null;

  bool get hasMatchFilters => 
    _matchType != 'all' || 
    _matchStatus != 'all' || 
    _matchDateFrom != null || 
    _matchDateTo != null;

  bool get hasStoreFilters => 
    _storeCategory != 'all' || 
    _storeAvailability != 'all' || 
    _storePriceMin != 0 || 
    _storePriceMax != 10000;

  bool get hasPollFilters => 
    _pollStatus != 'all' || 
    _pollType != 'all' || 
    !_pollShowVoted || 
    !_pollShowUnvoted;

  bool get hasNotificationFilters => 
    _notificationStatus != 'all' || 
    _notificationType != 'all' || 
    _notificationClubId != null;

  bool get hasAnyFilters => 
    hasTransactionFilters || 
    hasMatchFilters || 
    hasStoreFilters || 
    hasPollFilters || 
    hasNotificationFilters;

  // Filter count methods
  int get activeFilterCount {
    int count = 0;
    if (hasTransactionFilters) count++;
    if (hasMatchFilters) count++;
    if (hasStoreFilters) count++;
    if (hasPollFilters) count++;
    if (hasNotificationFilters) count++;
    return count;
  }

  // Get filter parameters for API calls
  Map<String, dynamic> getTransactionFilterParams() {
    final params = <String, dynamic>{};
    
    if (_transactionType != 'all') params['type'] = _transactionType;
    if (_transactionPeriod != 'all') params['period'] = _transactionPeriod;
    if (_transactionClubId != null) params['clubId'] = _transactionClubId;
    if (_sortBy != 'date') params['sortBy'] = _sortBy;
    if (_sortOrder != 'desc') params['sortOrder'] = _sortOrder;
    
    return params;
  }

  Map<String, dynamic> getMatchFilterParams() {
    final params = <String, dynamic>{};
    
    if (_matchType != 'all') params['type'] = _matchType;
    if (_matchStatus != 'all') params['status'] = _matchStatus;
    if (_matchDateFrom != null) params['dateFrom'] = _matchDateFrom!.toIso8601String();
    if (_matchDateTo != null) params['dateTo'] = _matchDateTo!.toIso8601String();
    if (_sortBy != 'date') params['sortBy'] = _sortBy;
    if (_sortOrder != 'desc') params['sortOrder'] = _sortOrder;
    
    return params;
  }

  Map<String, dynamic> getStoreFilterParams() {
    final params = <String, dynamic>{};
    
    if (_storeCategory != 'all') params['category'] = _storeCategory;
    if (_storeAvailability != 'all') params['availability'] = _storeAvailability;
    if (_storePriceMin != 0) params['priceMin'] = _storePriceMin;
    if (_storePriceMax != 10000) params['priceMax'] = _storePriceMax;
    if (_sortBy != 'date') params['sortBy'] = _sortBy;
    if (_sortOrder != 'desc') params['sortOrder'] = _sortOrder;
    
    return params;
  }

  Map<String, dynamic> getPollFilterParams() {
    final params = <String, dynamic>{};
    
    if (_pollStatus != 'all') params['status'] = _pollStatus;
    if (_pollType != 'all') params['type'] = _pollType;
    if (!_pollShowVoted) params['excludeVoted'] = true;
    if (!_pollShowUnvoted) params['excludeUnvoted'] = true;
    if (_sortBy != 'date') params['sortBy'] = _sortBy;
    if (_sortOrder != 'desc') params['sortOrder'] = _sortOrder;
    
    return params;
  }

  Map<String, dynamic> getNotificationFilterParams() {
    final params = <String, dynamic>{};
    
    if (_notificationStatus != 'all') params['status'] = _notificationStatus;
    if (_notificationType != 'all') params['type'] = _notificationType;
    if (_notificationClubId != null) params['clubId'] = _notificationClubId;
    if (_sortBy != 'date') params['sortBy'] = _sortBy;
    if (_sortOrder != 'desc') params['sortOrder'] = _sortOrder;
    
    return params;
  }

  // Available filter options
  List<String> get transactionTypes => ['all', 'CREDIT', 'DEBIT'];
  List<String> get transactionPeriods => ['all', 'today', 'week', 'month', '3months', 'year'];
  List<String> get matchTypes => ['all', 'game', 'practice', 'tournament', 'friendly', 'league'];
  List<String> get matchStatuses => ['all', 'upcoming', 'ongoing', 'completed', 'cancelled'];
  List<String> get storeCategories => ['all', 'jerseys', 'kits', 'equipment', 'accessories'];
  List<String> get storeAvailabilities => ['all', 'available', 'out_of_stock', 'disabled'];
  List<String> get pollStatuses => ['all', 'active', 'expired'];
  List<String> get pollTypes => ['all', 'single_choice', 'multiple_choice'];
  List<String> get notificationStatuses => ['all', 'unread', 'read'];
  List<String> get notificationTypes => ['all', 'RSVP_REMINDER', 'FEE_DUE', 'MATCH_UPDATE', 'ORDER_UPDATE', 'POLL_CREATED', 'CLUB_ANNOUNCEMENT'];
  List<String> get sortByOptions => ['date', 'name', 'amount', 'type'];
  List<String> get sortOrderOptions => ['asc', 'desc'];

  // Filter display names
  String getTransactionTypeDisplayName(String type) {
    switch (type) {
      case 'CREDIT': return 'Credit';
      case 'DEBIT': return 'Debit';
      default: return 'All';
    }
  }

  String getTransactionPeriodDisplayName(String period) {
    switch (period) {
      case 'today': return 'Today';
      case 'week': return 'This Week';
      case 'month': return 'This Month';
      case '3months': return 'Last 3 Months';
      case 'year': return 'This Year';
      default: return 'All Time';
    }
  }

  String getMatchTypeDisplayName(String type) {
    switch (type) {
      case 'game': return 'Game';
      case 'practice': return 'Practice';
      case 'tournament': return 'Tournament';
      case 'friendly': return 'Friendly';
      case 'league': return 'League';
      default: return 'All';
    }
  }

  String getMatchStatusDisplayName(String status) {
    switch (status) {
      case 'upcoming': return 'Upcoming';
      case 'ongoing': return 'Ongoing';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return 'All';
    }
  }

  String getStoreCategoryDisplayName(String category) {
    switch (category) {
      case 'jerseys': return 'Jerseys';
      case 'kits': return 'Kits';
      case 'equipment': return 'Equipment';
      case 'accessories': return 'Accessories';
      default: return 'All';
    }
  }

  String getStoreAvailabilityDisplayName(String availability) {
    switch (availability) {
      case 'available': return 'Available';
      case 'out_of_stock': return 'Out of Stock';
      case 'disabled': return 'Disabled';
      default: return 'All';
    }
  }

  String getPollStatusDisplayName(String status) {
    switch (status) {
      case 'active': return 'Active';
      case 'expired': return 'Expired';
      default: return 'All';
    }
  }

  String getPollTypeDisplayName(String type) {
    switch (type) {
      case 'single_choice': return 'Single Choice';
      case 'multiple_choice': return 'Multiple Choice';
      default: return 'All';
    }
  }

  String getNotificationStatusDisplayName(String status) {
    switch (status) {
      case 'unread': return 'Unread';
      case 'read': return 'Read';
      default: return 'All';
    }
  }

  String getNotificationTypeDisplayName(String type) {
    switch (type) {
      case 'RSVP_REMINDER': return 'RSVP Reminder';
      case 'FEE_DUE': return 'Fee Due';
      case 'MATCH_UPDATE': return 'Match Update';
      case 'ORDER_UPDATE': return 'Order Update';
      case 'POLL_CREATED': return 'New Poll';
      case 'CLUB_ANNOUNCEMENT': return 'Club Announcement';
      default: return 'All';
    }
  }

  String getSortByDisplayName(String sortBy) {
    switch (sortBy) {
      case 'date': return 'Date';
      case 'name': return 'Name';
      case 'amount': return 'Amount';
      case 'type': return 'Type';
      default: return 'Date';
    }
  }

  String getSortOrderDisplayName(String order) {
    switch (order) {
      case 'asc': return 'Ascending';
      case 'desc': return 'Descending';
      default: return 'Descending';
    }
  }
}