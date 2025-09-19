import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../utils/theme.dart';
import 'svg_avatar.dart';

enum TransactionListType {
  my, // Show club avatars with transaction badges (user's wallet view)
  club, // Show user avatars when available (club's all transactions view)
  member, // Show transaction purpose badges only (member's transactions view)
}

class TransactionsListWidget extends StatelessWidget {
  final List<Transaction> transactions;
  final TransactionListType listType;
  final bool isLoadingMore;
  final bool hasMoreData;
  final String? currency;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final bool showDateHeaders;
  final Function(Transaction)? onTransactionTap;

  const TransactionsListWidget({
    Key? key,
    required this.transactions,
    required this.listType,
    this.isLoadingMore = false,
    this.hasMoreData = true,
    this.currency,
    this.margin,
    this.padding,
    this.showDateHeaders = true,
    this.onTransactionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding ?? EdgeInsets.zero,
      children: buildTransactionListItems(context),
    );
  }

  List<Widget> buildTransactionListItems(BuildContext context) {
    final List<Widget> items = [];

    if (showDateHeaders) {
      final groupedTransactions = _groupTransactionsByDate(transactions);
      final sortedDateKeys = groupedTransactions.keys.toList()
        ..sort((a, b) => b.compareTo(a)); // Latest first

      for (final dateKey in sortedDateKeys) {
        final transactionsForDate = groupedTransactions[dateKey]!;

        // Add date header
        items.add(_buildDateHeader(context, dateKey));

        // Add transaction cards for this date
        for (final transaction in transactionsForDate) {
          items.add(_buildTransactionCard(context, transaction));
        }
      }
    } else {
      // No date headers, just show all transactions
      for (final transaction in transactions) {
        items.add(_buildTransactionCard(context, transaction));
      }
    }

    // Add loading indicator at the bottom for infinite scroll
    if (isLoadingMore) {
      items.add(_buildLoadingMoreIndicator(context));
    } else if (!hasMoreData && transactions.isNotEmpty) {
      items.add(_buildEndOfListIndicator(context));
    }

    return items;
  }

  Map<String, List<Transaction>> _groupTransactionsByDate(
    List<Transaction> transactions,
  ) {
    final Map<String, List<Transaction>> groupedTransactions = {};

    for (final transaction in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.createdAt);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    return groupedTransactions;
  }

  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  Widget _buildDateHeader(BuildContext context, String dateKey) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatDateHeader(dateKey),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)
              : Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Transaction transaction) {
    final isCredit = transaction.type == 'CREDIT';
    final icon = _getTransactionIcon(transaction.purpose);

    return GestureDetector(
      onTap: onTransactionTap != null
          ? () => onTransactionTap!(transaction)
          : null,
      child: Container(
        margin: margin ?? EdgeInsets.only(bottom: 8, left: 4, right: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar based on list type
              _buildTransactionAvatar(context, transaction, isCredit, icon),
              SizedBox(width: 12),

              // Transaction Info (Center)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      transaction.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.15)
                            : Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getPurposeText(transaction.purpose),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.9)
                              : Theme.of(context).primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Amount and Time (Right)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${isCredit ? '+' : '-'}${_formatCurrencyAmount(transaction.amount, currency)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isCredit
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    DateFormat('hh:mm a').format(transaction.createdAt),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionAvatar(
    BuildContext context,
    Transaction transaction,
    bool isCredit,
    IconData icon,
  ) {
    switch (listType) {
      case TransactionListType.my:
        // Show club avatar with transaction badge
        return Stack(
          children: [
            // Club Avatar
            SVGAvatar(
              imageUrl: transaction.club?.logo,
              size: 40,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              fallbackIcon: Icons.account_balance,
              iconSize: 24,
            ),
            // Transaction Badge
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).cardColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 10,
                ),
              ),
            ),
          ],
        );

      case TransactionListType.club:
        // Show user avatar when available, fallback to club avatar
        return Stack(
          children: [
            SVGAvatar(
              imageUrl:
                  transaction.user?.profilePicture ?? transaction.club?.logo,
              size: 40,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              fallbackIcon: transaction.user?.profilePicture != null
                  ? Icons.person
                  : Icons.account_balance,
              iconSize: 24,
            ),
            // Transaction Badge
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).cardColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 10,
                ),
              ),
            ),
          ],
        );

      case TransactionListType.member:
        // Show transaction purpose icon in a circle
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCredit
                ? AppTheme.successGreen.withOpacity(0.1)
                : AppTheme.errorRed.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
            size: 20,
          ),
        );
    }
  }

  Widget _buildLoadingMoreIndicator(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading more transactions...',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfListIndicator(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            SizedBox(width: 8),
            Text(
              'All transactions loaded',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransactionIcon(String purpose) {
    switch (purpose) {
      case 'MATCH_FEE':
        return Icons.sports_cricket;
      case 'MEMBERSHIP':
        return Icons.card_membership;
      case 'ORDER':
        return Icons.shopping_cart;
      case 'CLUB_TOPUP':
        return Icons.account_balance_wallet;
      case 'GENERAL_EXPENSE':
        return Icons.receipt;
      case 'MANUAL_ADJUSTMENT':
        return Icons.tune;
      case 'REFUND':
        return Icons.replay;
      case 'OUTSTANDING_PERFORMANCE':
        return Icons.stars;
      case 'PRACTICE_ATTENDED':
        return Icons.fitness_center;
      case 'MATCH_WON':
        return Icons.emoji_events;
      case 'CAPTAIN_BONUS':
        return Icons.military_tech;
      case 'GOOD_BEHAVIOUR':
        return Icons.sentiment_satisfied;
      case 'OTHER_POINTS':
        return Icons.add_circle;
      case 'POOR_BEHAVIOUR':
        return Icons.sentiment_dissatisfied;
      case 'MISSED_MATCH':
        return Icons.block;
      case 'MISSED_PRACTICE':
        return Icons.cancel;
      case 'LATE_ARRIVAL':
        return Icons.access_time;
      case 'DISCIPLINE_ACTION':
        return Icons.gavel;
      default:
        return Icons.receipt;
    }
  }

  String _getPurposeText(String purpose) {
    switch (purpose) {
      case 'MATCH_FEE':
        return 'Match Fee';
      case 'MEMBERSHIP':
        return 'Membership Fee';
      case 'ORDER':
        return 'Store Order';
      case 'CLUB_TOPUP':
        return 'Kitty Top-up';
      case 'GENERAL_EXPENSE':
        return 'General Expense';
      case 'MANUAL_ADJUSTMENT':
        return 'Manual Adjustment';
      case 'REFUND':
        return 'Refund';
      case 'OUTSTANDING_PERFORMANCE':
        return 'Outstanding Performance';
      case 'PRACTICE_ATTENDED':
        return 'Practice Attended';
      case 'MATCH_WON':
        return 'Match Won';
      case 'CAPTAIN_BONUS':
        return 'Captain Bonus';
      case 'GOOD_BEHAVIOUR':
        return 'Good Behaviour';
      case 'OTHER_POINTS':
        return 'Other Points';
      case 'POOR_BEHAVIOUR':
        return 'Poor Behaviour';
      case 'MISSED_MATCH':
        return 'Missed Match';
      case 'MISSED_PRACTICE':
        return 'Missed Practice';
      case 'LATE_ARRIVAL':
        return 'Late Arrival';
      case 'DISCIPLINE_ACTION':
        return 'Discipline Action';
      default:
        return 'Other';
    }
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

// Helper class for creating transaction list widgets with common configurations
class TransactionsListBuilder {
  static Widget forMy({
    required List<Transaction> transactions,
    bool isLoadingMore = false,
    bool hasMoreData = true,
    String? currency,
    Function(Transaction)? onTransactionTap,
  }) {
    return TransactionsListWidget(
      transactions: transactions,
      listType: TransactionListType.my,
      isLoadingMore: isLoadingMore,
      hasMoreData: hasMoreData,
      currency: currency,
      onTransactionTap: onTransactionTap,
    );
  }

  static Widget forClub({
    required List<Transaction> transactions,
    bool isLoadingMore = false,
    bool hasMoreData = true,
    String? currency,
    Function(Transaction)? onTransactionTap,
  }) {
    return TransactionsListWidget(
      transactions: transactions,
      listType: TransactionListType.club,
      isLoadingMore: isLoadingMore,
      hasMoreData: hasMoreData,
      currency: currency,
      onTransactionTap: onTransactionTap,
    );
  }

  static Widget forMember({
    required List<Transaction> transactions,
    bool isLoadingMore = false,
    bool hasMoreData = true,
    String? currency,
    Function(Transaction)? onTransactionTap,
  }) {
    return TransactionsListWidget(
      transactions: transactions,
      listType: TransactionListType.member,
      isLoadingMore: isLoadingMore,
      hasMoreData: hasMoreData,
      currency: currency,
      onTransactionTap: onTransactionTap,
    );
  }

  static Widget forRecentTransactions({
    required List<Transaction> transactions,
    required TransactionListType listType,
    bool showDateHeaders = false,
    EdgeInsets? margin,
    Function(Transaction)? onTransactionTap,
  }) {
    return TransactionsListWidget(
      transactions: transactions,
      listType: listType,
      showDateHeaders: showDateHeaders,
      margin: margin,
      onTransactionTap: onTransactionTap,
      hasMoreData: true,
      isLoadingMore: false,
    );
  }
}
