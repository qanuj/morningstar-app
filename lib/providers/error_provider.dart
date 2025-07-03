import 'package:flutter/material.dart';

class ErrorProvider with ChangeNotifier {
  final Map<String, String> _errors = {};
  List<AppError> _errorHistory = [];
  
  Map<String, String> get errors => _errors;
  List<AppError> get errorHistory => _errorHistory;
  
  bool hasError(String key) => _errors.containsKey(key);
  String? getError(String key) => _errors[key];
  
  bool get hasAnyError => _errors.isNotEmpty;
  List<String> get currentErrors => _errors.values.toList();

  void setError(String key, String message) {
    _errors[key] = message;
    _addToHistory(key, message);
    notifyListeners();
  }

  void clearError(String key) {
    _errors.remove(key);
    notifyListeners();
  }

  void clearAllErrors() {
    _errors.clear();
    notifyListeners();
  }

  void _addToHistory(String key, String message) {
    _errorHistory.insert(0, AppError(
      key: key,
      message: message,
      timestamp: DateTime.now(),
    ));
    
    // Keep only last 50 errors
    if (_errorHistory.length > 50) {
      _errorHistory = _errorHistory.take(50).toList();
    }
  }

  void clearErrorHistory() {
    _errorHistory.clear();
    notifyListeners();
  }

  // Predefined error keys for common operations
  static const String ERROR_NETWORK = 'error_network';
  static const String ERROR_AUTH = 'error_auth';
  static const String ERROR_CLUBS = 'error_clubs';
  static const String ERROR_MATCHES = 'error_matches';
  static const String ERROR_TRANSACTIONS = 'error_transactions';
  static const String ERROR_STORE = 'error_store';
  static const String ERROR_ORDERS = 'error_orders';
  static const String ERROR_POLLS = 'error_polls';
  static const String ERROR_NOTIFICATIONS = 'error_notifications';
  static const String ERROR_PROFILE = 'error_profile';
  static const String ERROR_RSVP = 'error_rsvp';
  static const String ERROR_VOTE = 'error_vote';
  static const String ERROR_ORDER_PLACEMENT = 'error_order_placement';
  static const String ERROR_NOTIFICATION_ACTION = 'error_notification_action';
  static const String ERROR_PROFILE_UPDATE = 'error_profile_update';
  static const String ERROR_CLUB_SWITCH = 'error_club_switch';
  static const String ERROR_VALIDATION = 'error_validation';
  static const String ERROR_UNKNOWN = 'error_unknown';

  // Helper methods for common operations
  bool get hasNetworkError => hasError(ERROR_NETWORK);
  bool get hasAuthError => hasError(ERROR_AUTH);
  bool get hasClubsError => hasError(ERROR_CLUBS);
  bool get hasMatchesError => hasError(ERROR_MATCHES);
  bool get hasTransactionsError => hasError(ERROR_TRANSACTIONS);
  bool get hasStoreError => hasError(ERROR_STORE);
  bool get hasOrdersError => hasError(ERROR_ORDERS);
  bool get hasPollsError => hasError(ERROR_POLLS);
  bool get hasNotificationsError => hasError(ERROR_NOTIFICATIONS);
  bool get hasProfileError => hasError(ERROR_PROFILE);
  bool get hasRSVPError => hasError(ERROR_RSVP);
  bool get hasVoteError => hasError(ERROR_VOTE);
  bool get hasOrderPlacementError => hasError(ERROR_ORDER_PLACEMENT);
  bool get hasNotificationActionError => hasError(ERROR_NOTIFICATION_ACTION);
  bool get hasProfileUpdateError => hasError(ERROR_PROFILE_UPDATE);
  bool get hasClubSwitchError => hasError(ERROR_CLUB_SWITCH);
  bool get hasValidationError => hasError(ERROR_VALIDATION);
  bool get hasUnknownError => hasError(ERROR_UNKNOWN);

  String? get networkError => getError(ERROR_NETWORK);
  String? get authError => getError(ERROR_AUTH);
  String? get clubsError => getError(ERROR_CLUBS);
  String? get matchesError => getError(ERROR_MATCHES);
  String? get transactionsError => getError(ERROR_TRANSACTIONS);
  String? get storeError => getError(ERROR_STORE);
  String? get ordersError => getError(ERROR_ORDERS);
  String? get pollsError => getError(ERROR_POLLS);
  String? get notificationsError => getError(ERROR_NOTIFICATIONS);
  String? get profileError => getError(ERROR_PROFILE);
  String? get rsvpError => getError(ERROR_RSVP);
  String? get voteError => getError(ERROR_VOTE);
  String? get orderPlacementError => getError(ERROR_ORDER_PLACEMENT);
  String? get notificationActionError => getError(ERROR_NOTIFICATION_ACTION);
  String? get profileUpdateError => getError(ERROR_PROFILE_UPDATE);
  String? get clubSwitchError => getError(ERROR_CLUB_SWITCH);
  String? get validationError => getError(ERROR_VALIDATION);
  String? get unknownError => getError(ERROR_UNKNOWN);

  void setNetworkError(String message) => setError(ERROR_NETWORK, message);
  void setAuthError(String message) => setError(ERROR_AUTH, message);
  void setClubsError(String message) => setError(ERROR_CLUBS, message);
  void setMatchesError(String message) => setError(ERROR_MATCHES, message);
  void setTransactionsError(String message) => setError(ERROR_TRANSACTIONS, message);
  void setStoreError(String message) => setError(ERROR_STORE, message);
  void setOrdersError(String message) => setError(ERROR_ORDERS, message);
  void setPollsError(String message) => setError(ERROR_POLLS, message);
  void setNotificationsError(String message) => setError(ERROR_NOTIFICATIONS, message);
  void setProfileError(String message) => setError(ERROR_PROFILE, message);
  void setRSVPError(String message) => setError(ERROR_RSVP, message);
  void setVoteError(String message) => setError(ERROR_VOTE, message);
  void setOrderPlacementError(String message) => setError(ERROR_ORDER_PLACEMENT, message);
  void setNotificationActionError(String message) => setError(ERROR_NOTIFICATION_ACTION, message);
  void setProfileUpdateError(String message) => setError(ERROR_PROFILE_UPDATE, message);
  void setClubSwitchError(String message) => setError(ERROR_CLUB_SWITCH, message);
  void setValidationError(String message) => setError(ERROR_VALIDATION, message);
  void setUnknownError(String message) => setError(ERROR_UNKNOWN, message);

  void clearNetworkError() => clearError(ERROR_NETWORK);
  void clearAuthError() => clearError(ERROR_AUTH);
  void clearClubsError() => clearError(ERROR_CLUBS);
  void clearMatchesError() => clearError(ERROR_MATCHES);
  void clearTransactionsError() => clearError(ERROR_TRANSACTIONS);
  void clearStoreError() => clearError(ERROR_STORE);
  void clearOrdersError() => clearError(ERROR_ORDERS);
  void clearPollsError() => clearError(ERROR_POLLS);
  void clearNotificationsError() => clearError(ERROR_NOTIFICATIONS);
  void clearProfileError() => clearError(ERROR_PROFILE);
  void clearRSVPError() => clearError(ERROR_RSVP);
  void clearVoteError() => clearError(ERROR_VOTE);
  void clearOrderPlacementError() => clearError(ERROR_ORDER_PLACEMENT);
  void clearNotificationActionError() => clearError(ERROR_NOTIFICATION_ACTION);
  void clearProfileUpdateError() => clearError(ERROR_PROFILE_UPDATE);
  void clearClubSwitchError() => clearError(ERROR_CLUB_SWITCH);
  void clearValidationError() => clearError(ERROR_VALIDATION);
  void clearUnknownError() => clearError(ERROR_UNKNOWN);

  String getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }

  void handleError(String key, dynamic error) {
    final message = getErrorMessage(error);
    setError(key, message);
  }
}

class AppError {
  final String key;
  final String message;
  final DateTime timestamp;

  AppError({
    required this.key,
    required this.message,
    required this.timestamp,
  });

  @override
  String toString() => 'AppError(key: $key, message: $message, timestamp: $timestamp)';
}