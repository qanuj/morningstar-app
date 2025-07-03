// lib/models/transaction.dart
class Transaction {
  final String id;
  final double amount;
  final String type; // CREDIT or DEBIT
  final String purpose;
  final String description;
  final DateTime createdAt;
  final String? orderId;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.purpose,
    required this.description,
    required this.createdAt,
    this.orderId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'],
      purpose: json['purpose'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      orderId: json['orderId'],
    );
  }
}
