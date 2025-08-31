import 'package:flutter/material.dart';
import '../../../models/club_message.dart';

class MessageReactionsWidget extends StatelessWidget {
  final ClubMessage message;

  const MessageReactionsWidget({Key? key, required this.message})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (message.reactions.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: message.reactions.map((entry) {
          final emoji = entry.emoji;
          final users = entry.userIds;

          return GestureDetector(
            onTap: () => _showReactionDetails(context, emoji, users),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(0xFF06aeef).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: TextStyle(fontSize: 14)),
                  if (users.length > 1) ...[
                    SizedBox(width: 3),
                    Text(
                      '${users.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.8)
                            : Colors.black.withOpacity(0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showReactionDetails(
    BuildContext context,
    String emoji,
    List<MessageReactionUser> users,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Reactions'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Text(user.name),
                subtitle: user.role != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user.role!.toUpperCase() == 'OWNER'
                                ? Icons.star
                                : user.role!.toUpperCase() == 'ADMIN'
                                ? Icons.shield
                                : Icons.person,
                            size: 14,
                            color: user.role!.toUpperCase() == 'OWNER'
                                ? Colors.orange
                                : user.role!.toUpperCase() == 'ADMIN'
                                ? Colors.purple
                                : Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(user.role!, style: TextStyle(fontSize: 12)),
                        ],
                      )
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
