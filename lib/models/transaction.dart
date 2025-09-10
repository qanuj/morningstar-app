// lib/models/transaction.dart
class Transaction {
  final String id;
  final String userId;
  final String clubId;
  final double amount;
  final String type; // CREDIT or DEBIT
  final String purpose;
  final String description;
  final DateTime createdAt;
  final String? orderId;
  final ClubModel? club;
  final UserModel? user;

  Transaction({
    required this.id,
    required this.userId,
    required this.clubId,
    required this.amount,
    required this.type,
    required this.purpose,
    required this.description,
    required this.createdAt,
    this.orderId,
    this.club,
    this.user,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['userId'],
      clubId: json['clubId'],
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'],
      purpose: json['purpose'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      orderId: json['orderId'],
      club: json['club'] != null ? ClubModel.fromJson(json['club']) : null,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'clubId': clubId,
      'amount': amount,
      'type': type,
      'purpose': purpose,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'orderId': orderId,
      'club': club?.toJson(),
      'user': user?.toJson(),
    };
  }
}

class ClubModel {
  final String id;
  final String name;
  final String? logo;

  ClubModel({
    required this.id,
    required this.name,
    this.logo,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'],
      name: json['name'],
      logo: json['logo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
    };
  }
}

class UserModel {
  final String id;
  final String name;
  final String? profilePicture;

  UserModel({
    required this.id,
    required this.name,
    this.profilePicture,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
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