import 'package:flutter/material.dart';
import '../models/user.dart';
import '../screens/transactions/transaction_create_screen.dart';

class TransactionDialogHelper {
  /// Shows the transaction dialog and handles the navigation
  /// 
  /// [context] - BuildContext to navigate from
  /// [type] - Transaction type ('CREDIT' or 'DEBIT')
  /// [title] - Dialog title (e.g., 'Add Funds', 'Add Expense')
  /// [isBulk] - Whether this is a bulk transaction
  /// [selectedMembers] - List of selected members (for bulk transactions)
  /// [onSubmit] - Callback function to handle transaction submission
  static void showTransactionDialog({
    required BuildContext context,
    required String type,
    required String title,
    required bool isBulk,
    List<User> selectedMembers = const [],
    required Future<void> Function(Map<String, dynamic>) onSubmit,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionCreateScreen(
          type: type,
          title: title,
          isBulk: isBulk,
          selectedMembers: selectedMembers,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  /// Convenience method for individual member transactions
  static void showMemberTransactionDialog({
    required BuildContext context,
    required String type,
    required String title,
    required User member,
    required Future<void> Function(Map<String, dynamic>) onSubmit,
  }) {
    showTransactionDialog(
      context: context,
      type: type,
      title: title,
      isBulk: false,
      selectedMembers: [member],
      onSubmit: onSubmit,
    );
  }

  /// Convenience method for bulk member transactions
  static void showBulkTransactionDialog({
    required BuildContext context,
    required String type,
    required String title,
    required List<User> selectedMembers,
    required Future<void> Function(Map<String, dynamic>) onSubmit,
  }) {
    showTransactionDialog(
      context: context,
      type: type,
      title: title,
      isBulk: true,
      selectedMembers: selectedMembers,
      onSubmit: onSubmit,
    );
  }
}