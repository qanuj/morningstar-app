import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/mention.dart';

/// A widget that renders text with tappable mentions
class TappableMentionText extends StatelessWidget {
  final String text;
  final List<MentionedUser> mentions;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TappableMentionText({
    super.key,
    required this.text,
    required this.mentions,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    // If no mentions, return simple text
    if (mentions.isEmpty || !_containsMentions(text)) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return RichText(
      text: _buildTextSpan(context),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  bool _containsMentions(String text) {
    return RegExp(r'@\[([^:]+):([^\]]+)\]').hasMatch(text);
  }

  TextSpan _buildTextSpan(BuildContext context) {
    final children = <InlineSpan>[];

    // Get theme-aware mention colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mentionColor = isDark
        ? Color(0xFF64B5F6) // Light blue for dark mode
        : Color(0xFF1976D2); // Darker blue for light mode

    // Pattern to match completed mentions @[id:name]
    final mentionPattern = RegExp(r'@\[([^:]+):([^\]]+)\]');

    int lastEnd = 0;

    for (final match in mentionPattern.allMatches(text)) {
      final mentionId = match.group(1)!;
      final mentionName = match.group(2)!;

      // Find the mentioned user data
      final mentionedUser = mentions.firstWhere(
        (user) => user.id == mentionId,
        orElse: () =>
            MentionedUser(id: mentionId, name: mentionName, role: 'MEMBER'),
      );

      // Add text before the mention
      if (match.start > lastEnd) {
        children.add(
          TextSpan(text: text.substring(lastEnd, match.start), style: style),
        );
      }

      // Add the tappable mention
      children.add(
        TextSpan(
          text: '@$mentionName',
          style: (style ?? TextStyle()).copyWith(
            color: mentionColor,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _showMentionDialog(context, mentionedUser),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text after the last mention
    if (lastEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return TextSpan(style: style, children: children);
  }

  void _showMentionDialog(BuildContext context, MentionedUser user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 40,
                  backgroundImage: user.profilePicture != null
                      ? NetworkImage(user.profilePicture!)
                      : null,
                  child: user.profilePicture == null
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                  backgroundColor: _getRoleColor(user.role),
                ),
                SizedBox(height: 16),

                // User name
                Text(
                  user.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),

                // User role
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getRoleColor(user.role).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getRoleDisplayName(user.role),
                    style: TextStyle(
                      color: _getRoleColor(user.role),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return Colors.purple;
      case 'ADMIN':
        return Colors.orange;
      case 'MEMBER':
      default:
        return Colors.blue;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Owner';
      case 'ADMIN':
        return 'Admin';
      case 'MEMBER':
      default:
        return 'Member';
    }
  }
}
