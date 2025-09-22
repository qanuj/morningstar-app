import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import '../../utils/text_utils.dart';

/// System message bubble - displays system events without background, centered
class SystemMessageBubble extends StatelessWidget {
  final ClubMessage message;

  const SystemMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]?.withOpacity(0.5)
                : Colors.grey[300]?.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _formatSystemMessage(),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[300]
                  : Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _formatSystemMessage() {
    final meta = message.meta ?? {};
    final systemType = meta['systemType'] as String?;

    switch (systemType) {
      case 'member_addition':
        return _formatMemberAdditionMessage();
      case 'date_group':
        return _formatDateMessage();
      default:
        return TextUtils.safeText(message.content);
    }
  }

  String _formatMemberAdditionMessage() {
    final meta = message.meta ?? {};
    final addedBy = TextUtils.safeText(message.senderName);
    final memberName = TextUtils.safeText(meta['memberName'] as String?);

    if (memberName.isEmpty) {
      return '$addedBy added a new member';
    }

    return '$addedBy added $memberName';
  }

  String _formatDateMessage() {
    // For date group messages, just show the content as-is
    return TextUtils.safeText(message.content);
  }
}