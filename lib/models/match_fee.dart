// lib/models/match_fee.dart
import 'transaction.dart';

class MatchFeeTransaction {
  final String id;
  final User? user;
  final double amount;
  final String? paymentMethod;
  final DateTime createdAt;
  final bool isPaid;
  final bool isConfirmed;

  MatchFeeTransaction({
    required this.id,
    this.user,
    required this.amount,
    this.paymentMethod,
    required this.createdAt,
    required this.isPaid,
    required this.isConfirmed,
  });

  factory MatchFeeTransaction.fromJson(Map<String, dynamic> json) {
    return MatchFeeTransaction(
      id: json['id'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isPaid: json['isPaid'] ?? false,
      isConfirmed: json['isConfirmed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user?.toJson(),
      'amount': amount,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'isPaid': isPaid,
      'isConfirmed': isConfirmed,
    };
  }

  String get paymentStatusText {
    if (!isPaid) return 'Unpaid';
    if (isPaid && !isConfirmed) return 'Pending Confirmation';
    return 'Confirmed';
  }

  String get paymentMethodText {
    switch (paymentMethod) {
      case 'UPI':
        return 'UPI';
      case 'CASH':
        return 'Cash';
      case 'KITTY':
        return 'Kitty Balance';
      default:
        return 'Unknown';
    }
  }
}

class User {
  final String id;
  final String name;
  final String? profilePicture;

  User({
    required this.id,
    required this.name,
    this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePicture': profilePicture,
    };
  }
}

class MatchFeesResponse {
  final MatchInfo match;
  final List<MatchFeeTransaction> transactions;
  final UserFeeStatus? userFeeStatus;
  final String userRole;
  final bool canManageFees;

  MatchFeesResponse({
    required this.match,
    required this.transactions,
    this.userFeeStatus,
    required this.userRole,
    required this.canManageFees,
  });

  factory MatchFeesResponse.fromJson(Map<String, dynamic> json) {
    return MatchFeesResponse(
      match: MatchInfo.fromJson(json['match']),
      transactions: (json['transactions'] as List)
          .map((transaction) => MatchFeeTransaction.fromJson(transaction))
          .toList(),
      userFeeStatus: json['userFeeStatus'] != null
          ? UserFeeStatus.fromJson(json['userFeeStatus'])
          : null,
      userRole: json['userRole'] ?? 'NONE',
      canManageFees: json['canManageFees'] ?? false,
    );
  }
}

class UserFeeStatus {
  final double amount;
  final bool isPaid;
  final bool isConfirmed;
  final String? paymentMethod;
  final DateTime? paidAt;

  UserFeeStatus({
    required this.amount,
    required this.isPaid,
    required this.isConfirmed,
    this.paymentMethod,
    this.paidAt,
  });

  factory UserFeeStatus.fromJson(Map<String, dynamic> json) {
    return UserFeeStatus(
      amount: (json['amount'] ?? 0).toDouble(),
      isPaid: json['isPaid'] ?? false,
      isConfirmed: json['isConfirmed'] ?? false,
      paymentMethod: json['paymentMethod'],
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
    );
  }

  String get statusText {
    if (!isPaid) return 'Unpaid';
    if (isPaid && !isConfirmed) return 'Pending Confirmation';
    return 'Confirmed';
  }
}

class MatchInfo {
  final String id;
  final ClubInfo club;

  MatchInfo({
    required this.id,
    required this.club,
  });

  factory MatchInfo.fromJson(Map<String, dynamic> json) {
    return MatchInfo(
      id: json['id'] ?? '',
      club: ClubInfo.fromJson(json['club']),
    );
  }
}

class ClubInfo {
  final String id;
  final String name;
  final String currency;
  final String? upiId;

  ClubInfo({
    required this.id,
    required this.name,
    required this.currency,
    this.upiId,
  });

  factory ClubInfo.fromJson(Map<String, dynamic> json) {
    return ClubInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      currency: json['currency'] ?? 'INR',
      upiId: json['upiId'],
    );
  }
}

// Payment method enum
enum PaymentMethod {
  UPI,
  CASH,
  KITTY,
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.UPI:
        return 'UPI';
      case PaymentMethod.CASH:
        return 'Cash';
      case PaymentMethod.KITTY:
        return 'Kitty Balance';
    }
  }

  String get apiValue {
    switch (this) {
      case PaymentMethod.UPI:
        return 'UPI';
      case PaymentMethod.CASH:
        return 'CASH';
      case PaymentMethod.KITTY:
        return 'KITTY';
    }
  }
}