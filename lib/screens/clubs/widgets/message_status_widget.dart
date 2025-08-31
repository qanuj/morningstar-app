import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/club_message.dart';
import '../../../models/message_status.dart';
import '../../../providers/user_provider.dart';

class MessageStatusWidget extends StatelessWidget {
  final ClubMessage message;
  final Color? overrideColor;

  const MessageStatusWidget({
    Key? key,
    required this.message,
    this.overrideColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = message.status;
    final List<Widget> icons = [];
    final isOwn =
        message.senderId ==
        Provider.of<UserProvider>(context, listen: false).user?.id;

    // Use override color if provided, otherwise use default color logic
    final iconColor =
        overrideColor ??
        (isOwn
            ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.65))
            : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6)));

    // Only add status ticks (pin and star are now handled in main row)
    switch (status) {
      case MessageStatus.sending:
        icons.add(
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: iconColor,
            ),
          ),
        );
        break;
      case MessageStatus.failed:
        icons.add(Icon(Icons.error_outline, size: 14, color: Colors.red));
        break;
      case MessageStatus.sent:
        icons.add(Icon(Icons.check, size: 14, color: iconColor));
        break;
      case MessageStatus.delivered:
        // Two gray ticks for delivered
        icons.addAll([Icon(Icons.done_all, size: 14, color: iconColor)]);
        break;
      case MessageStatus.read:
        // Two blue ticks for seen/read
        icons.add(Icon(Icons.done_all, size: 14, color: Color(0xFF06aeef)));
        break;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }
}
