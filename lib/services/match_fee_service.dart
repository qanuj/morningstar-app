// lib/services/match_fee_service.dart
import '../models/match_fee.dart';
import 'api_service.dart';

class MatchFeeService {
  static const String _baseUrl = '/matches';

  /// Get match fees and player payment status
  static Future<MatchFeesResponse> getMatchFees(String matchId) async {
    try {
      final response = await ApiService.get('$_baseUrl/$matchId/fees');
      return MatchFeesResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch match fees: $e');
    }
  }

  /// Create or update match fees (Admin/Owner only)
  static Future<Map<String, dynamic>> setMatchFees({
    required String matchId,
    required double amount,
    required List<String> selectedPlayerIds,
    String currency = 'INR',
  }) async {
    try {
      final response = await ApiService.post(
        '$_baseUrl/$matchId/fees',
        {
          'amount': amount,
          'selectedPlayerIds': selectedPlayerIds,
          'currency': currency,
        },
      );
      return response;
    } catch (e) {
      throw Exception('Failed to set match fees: $e');
    }
  }

  /// Record payment by player
  static Future<Map<String, dynamic>> payMatchFee({
    required String matchId,
    required PaymentMethod paymentMethod,
    required double amount,
    String? notes,
  }) async {
    try {
      final response = await ApiService.post(
        '$_baseUrl/$matchId/fees/pay',
        {
          'paymentMethod': paymentMethod.apiValue,
          'amount': amount,
          'notes': notes,
        },
      );
      return response;
    } catch (e) {
      throw Exception('Failed to record payment: $e');
    }
  }

  /// Confirm or reject player's payment (Admin/Owner only)
  static Future<Map<String, dynamic>> confirmPayment({
    required String matchId,
    required String userId,
    required String action, // 'confirm' or 'reject'
    double? amount,
    String? paymentMethod,
    String? notes,
  }) async {
    try {
      final response = await ApiService.post(
        '$_baseUrl/$matchId/fees/confirm',
        {
          'userId': userId,
          'action': action,
          if (amount != null) 'amount': amount,
          if (paymentMethod != null) 'paymentMethod': paymentMethod,
          if (notes != null) 'notes': notes,
        },
      );
      return response;
    } catch (e) {
      throw Exception('Failed to confirm payment: $e');
    }
  }

  /// Get pending payment confirmations (Admin/Owner only)
  static Future<Map<String, dynamic>> getPendingConfirmations(String matchId) async {
    try {
      final response = await ApiService.get('$_baseUrl/$matchId/fees/confirm');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch pending confirmations: $e');
    }
  }

  /// Send payment reminder notifications (Admin/Owner only)
  static Future<Map<String, dynamic>> sendPaymentReminders({
    required String matchId,
    List<String>? playerIds,
    String? message,
  }) async {
    try {
      final response = await ApiService.post(
        '$_baseUrl/$matchId/fees/notify',
        {
          if (playerIds != null) 'playerIds': playerIds,
          if (message != null) 'message': message,
        },
      );
      return response;
    } catch (e) {
      throw Exception('Failed to send payment reminders: $e');
    }
  }

  /// Generate UPI payment link
  static String generateUpiLink({
    required String upiId,
    required double amount,
    required String note,
    required String matchId,
    String currency = 'INR',
  }) {
    final encodedMatchId = Uri.encodeComponent('Match_Fee_$matchId');

    return 'upi://pay?pa=$upiId&pn=ClubPayment&am=$amount&tn=$encodedMatchId&cu=$currency&mode=02';
  }

  /// Check if user has pending fees for any matches
  static Future<List<Map<String, dynamic>>> getUserPendingFees() async {
    try {
      // This would be implemented as a separate endpoint to get user's pending fees across all matches
      final response = await ApiService.get('/user/pending-fees');
      return List<Map<String, dynamic>>.from(response['pendingFees'] ?? []);
    } catch (e) {
      // If endpoint doesn't exist yet, return empty list
      return [];
    }
  }

  /// Get match fee summary for a club (Admin/Owner only)
  static Future<Map<String, dynamic>> getClubFeesSummary(String clubId) async {
    try {
      final response = await ApiService.get('/clubs/$clubId/fees-summary');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch club fees summary: $e');
    }
  }

  /// Bulk confirm payments (Admin/Owner only)
  static Future<Map<String, dynamic>> bulkConfirmPayments({
    required String matchId,
    required List<String> playerFeeIds,
    String? notes,
  }) async {
    try {
      final response = await ApiService.post(
        '$_baseUrl/$matchId/fees/bulk-confirm',
        {
          'playerFeeIds': playerFeeIds,
          'notes': notes,
        },
      );
      return response;
    } catch (e) {
      throw Exception('Failed to bulk confirm payments: $e');
    }
  }

  /// Get fee payment history for a match
  static Future<List<Map<String, dynamic>>> getPaymentHistory(String matchId) async {
    try {
      final response = await ApiService.get('$_baseUrl/$matchId/fees/history');
      return List<Map<String, dynamic>>.from(response['history'] ?? []);
    } catch (e) {
      throw Exception('Failed to fetch payment history: $e');
    }
  }

  /// Format currency amount for display
  static String formatCurrency(double amount, [String currency = 'INR']) {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹${amount.toStringAsFixed(0)}';
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      default:
        return '$currency ${amount.toStringAsFixed(2)}';
    }
  }

  /// Get payment status color
  static String getPaymentStatusColor(MatchFeeTransaction transaction) {
    if (!transaction.isPaid) return 'red';
    if (transaction.isPaid && !transaction.isConfirmed) return 'orange';
    return 'green';
  }

  /// Get payment status icon
  static String getPaymentStatusIcon(MatchFeeTransaction transaction) {
    if (!transaction.isPaid) return 'pending_payment';
    if (transaction.isPaid && !transaction.isConfirmed) return 'hourglass_empty';
    return 'check_circle';
  }

  /// Validate payment amount
  static bool isValidAmount(double amount) {
    return amount > 0 && amount <= 100000; // Max 1 lakh INR
  }

  /// Validate UPI ID format
  static bool isValidUpiId(String upiId) {
    final regex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$');
    return regex.hasMatch(upiId);
  }

  /// Calculate per-player amount
  static double calculatePerPlayerAmount(double totalAmount, int playerCount) {
    if (playerCount <= 0) return 0;
    return totalAmount / playerCount;
  }

  /// Get payment deadline (if any)
  static DateTime? getPaymentDeadline(DateTime matchDate) {
    // Payment deadline is 24 hours before match
    return matchDate.subtract(const Duration(hours: 24));
  }

  /// Check if payment is overdue
  static bool isPaymentOverdue(DateTime matchDate) {
    final deadline = getPaymentDeadline(matchDate);
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }
}