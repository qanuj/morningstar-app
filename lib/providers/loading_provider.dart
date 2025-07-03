import 'package:flutter/material.dart';

class LoadingProvider with ChangeNotifier {
  final Map<String, bool> _loadingStates = {};
  
  bool isLoading(String key) => _loadingStates[key] ?? false;
  
  bool get isAnyLoading => _loadingStates.values.any((loading) => loading);
  
  List<String> get currentlyLoadingKeys => 
    _loadingStates.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

  void setLoading(String key, bool loading) {
    _loadingStates[key] = loading;
    notifyListeners();
  }

  void startLoading(String key) {
    _loadingStates[key] = true;
    notifyListeners();
  }

  void stopLoading(String key) {
    _loadingStates[key] = false;
    notifyListeners();
  }

  void clearLoading(String key) {
    _loadingStates.remove(key);
    notifyListeners();
  }

  void clearAllLoading() {
    _loadingStates.clear();
    notifyListeners();
  }

  Future<T> withLoading<T>(String key, Future<T> Function() operation) async {
    try {
      startLoading(key);
      final result = await operation();
      return result;
    } finally {
      stopLoading(key);
    }
  }

  // Predefined loading keys for common operations
  static const String LOADING_CLUBS = 'loading_clubs';
  static const String LOADING_MATCHES = 'loading_matches';
  static const String LOADING_TRANSACTIONS = 'loading_transactions';
  static const String LOADING_STORE = 'loading_store';
  static const String LOADING_ORDERS = 'loading_orders';
  static const String LOADING_POLLS = 'loading_polls';
  static const String LOADING_NOTIFICATIONS = 'loading_notifications';
  static const String LOADING_PROFILE = 'loading_profile';
  static const String LOADING_RSVP = 'loading_rsvp';
  static const String LOADING_VOTE = 'loading_vote';
  static const String LOADING_ORDER_PLACEMENT = 'loading_order_placement';
  static const String LOADING_NOTIFICATION_ACTION = 'loading_notification_action';
  static const String LOADING_PROFILE_UPDATE = 'loading_profile_update';
  static const String LOADING_CLUB_SWITCH = 'loading_club_switch';
  static const String LOADING_REFRESH = 'loading_refresh';
  static const String LOADING_PAGINATION = 'loading_pagination';

  // Helper methods for common operations
  bool get isLoadingClubs => isLoading(LOADING_CLUBS);
  bool get isLoadingMatches => isLoading(LOADING_MATCHES);
  bool get isLoadingTransactions => isLoading(LOADING_TRANSACTIONS);
  bool get isLoadingStore => isLoading(LOADING_STORE);
  bool get isLoadingOrders => isLoading(LOADING_ORDERS);
  bool get isLoadingPolls => isLoading(LOADING_POLLS);
  bool get isLoadingNotifications => isLoading(LOADING_NOTIFICATIONS);
  bool get isLoadingProfile => isLoading(LOADING_PROFILE);
  bool get isLoadingRSVP => isLoading(LOADING_RSVP);
  bool get isLoadingVote => isLoading(LOADING_VOTE);
  bool get isLoadingOrderPlacement => isLoading(LOADING_ORDER_PLACEMENT);
  bool get isLoadingNotificationAction => isLoading(LOADING_NOTIFICATION_ACTION);
  bool get isLoadingProfileUpdate => isLoading(LOADING_PROFILE_UPDATE);
  bool get isLoadingClubSwitch => isLoading(LOADING_CLUB_SWITCH);
  bool get isLoadingRefresh => isLoading(LOADING_REFRESH);
  bool get isLoadingPagination => isLoading(LOADING_PAGINATION);

  void setLoadingClubs(bool loading) => setLoading(LOADING_CLUBS, loading);
  void setLoadingMatches(bool loading) => setLoading(LOADING_MATCHES, loading);
  void setLoadingTransactions(bool loading) => setLoading(LOADING_TRANSACTIONS, loading);
  void setLoadingStore(bool loading) => setLoading(LOADING_STORE, loading);
  void setLoadingOrders(bool loading) => setLoading(LOADING_ORDERS, loading);
  void setLoadingPolls(bool loading) => setLoading(LOADING_POLLS, loading);
  void setLoadingNotifications(bool loading) => setLoading(LOADING_NOTIFICATIONS, loading);
  void setLoadingProfile(bool loading) => setLoading(LOADING_PROFILE, loading);
  void setLoadingRSVP(bool loading) => setLoading(LOADING_RSVP, loading);
  void setLoadingVote(bool loading) => setLoading(LOADING_VOTE, loading);
  void setLoadingOrderPlacement(bool loading) => setLoading(LOADING_ORDER_PLACEMENT, loading);
  void setLoadingNotificationAction(bool loading) => setLoading(LOADING_NOTIFICATION_ACTION, loading);
  void setLoadingProfileUpdate(bool loading) => setLoading(LOADING_PROFILE_UPDATE, loading);
  void setLoadingClubSwitch(bool loading) => setLoading(LOADING_CLUB_SWITCH, loading);
  void setLoadingRefresh(bool loading) => setLoading(LOADING_REFRESH, loading);
  void setLoadingPagination(bool loading) => setLoading(LOADING_PAGINATION, loading);
}