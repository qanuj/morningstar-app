import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/mention.dart';
import '../widgets/svg_avatar.dart';

/// Widget to display text with rendered @mentions
///
/// This widget parses text containing mention placeholders (@[userId:userName])
/// and renders them as clickable, styled mention chips within the text flow.
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<MentionedUser> mentions;
  final Function(MentionedUser)? onMentionTap;
  final Color? mentionColor;
  final Color? mentionBackgroundColor;
  final bool selectable;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.mentions = const [],
    this.onMentionTap,
    this.mentionColor,
    this.mentionBackgroundColor,
    this.selectable = false,
  }) : assert(mentions != null, 'mentions cannot be null');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultMentionColor = mentionColor ?? theme.colorScheme.primary;
    final defaultMentionBgColor = mentionBackgroundColor ??
        theme.colorScheme.primary.withOpacity(0.1);

    // Create a map of user IDs to user data for quick lookup
    final mentionMap = <String, MentionedUser>{};
    for (final mention in mentions) {
      mentionMap[mention.id] = mention;
    }

    // Parse the text and create TextSpans
    final spans = _parseTextWithMentions(
      text,
      mentionMap,
      style ?? DefaultTextStyle.of(context).style,
      defaultMentionColor,
      defaultMentionBgColor,
      context,
    );

    if (selectable) {
      return SelectableText.rich(
        TextSpan(children: spans),
        style: style,
      );
    } else {
      return RichText(
        text: TextSpan(children: spans),
      );
    }
  }

  List<TextSpan> _parseTextWithMentions(
    String text,
    Map<String, MentionedUser> mentionMap,
    TextStyle defaultStyle,
    Color mentionColor,
    Color mentionBgColor,
    BuildContext context,
  ) {
    final spans = <TextSpan>[];
    final mentionRegex = RegExp(r'@\[([^:]+):([^\]]+)\]');

    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(text)) {
      // Add text before the mention
      if (match.start > lastEnd) {
        final beforeText = text.substring(lastEnd, match.start);
        spans.add(TextSpan(
          text: beforeText,
          style: defaultStyle,
        ));
      }

      // Extract mention data
      final userId = match.group(1)!;
      final userName = match.group(2)!;
      final mentionUser = mentionMap[userId];

      // Create mention span
      spans.add(_createMentionSpan(
        userName,
        mentionUser,
        defaultStyle,
        mentionColor,
        mentionBgColor,
        context,
      ));

      lastEnd = match.end;
    }

    // Add remaining text after the last mention
    if (lastEnd < text.length) {
      final remainingText = text.substring(lastEnd);
      spans.add(TextSpan(
        text: remainingText,
        style: defaultStyle,
      ));
    }

    return spans;
  }

  TextSpan _createMentionSpan(
    String userName,
    MentionedUser? mentionUser,
    TextStyle defaultStyle,
    Color mentionColor,
    Color mentionBgColor,
    BuildContext context,
  ) {
    return TextSpan(
      text: '@$userName',
      style: defaultStyle.copyWith(
        color: mentionColor,
        fontWeight: FontWeight.w600,
        backgroundColor: mentionBgColor,
      ),
      recognizer: mentionUser != null && onMentionTap != null
          ? (TapGestureRecognizer()
            ..onTap = () => onMentionTap!(mentionUser))
          : null,
    );
  }

  /// Get clean text without mention formatting
  static String getCleanText(String text) {
    return text.replaceAllMapped(
      RegExp(r'@\[([^:]+):([^\]]+)\]'),
      (match) => '@${match.group(2)}', // Show @userName
    );
  }

  /// Check if text contains mentions
  static bool hasMentions(String text) {
    return RegExp(r'@\[([^:]+):[^\]]+\]').hasMatch(text);
  }

  /// Extract mention user IDs from text
  static List<String> extractMentionIds(String text) {
    final mentionRegex = RegExp(r'@\[([^:]+):[^\]]+\]');
    final mentionIds = <String>[];

    for (final match in mentionRegex.allMatches(text)) {
      final userId = match.group(1);
      if (userId != null && !mentionIds.contains(userId)) {
        mentionIds.add(userId);
      }
    }

    return mentionIds;
  }
}

/// A compact mention chip widget for displaying mentioned users
class MentionChip extends StatelessWidget {
  final MentionedUser mention;
  final Function(MentionedUser)? onTap;
  final bool showProfilePicture;
  final double? size;

  const MentionChip({
    super.key,
    required this.mention,
    this.onTap,
    this.showProfilePicture = true,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipSize = size ?? 24.0;

    return GestureDetector(
      onTap: onTap != null ? () => onTap!(mention) : null,
      child: Container(
        height: chipSize,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(chipSize / 2),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showProfilePicture) ...[
              SVGAvatar(
                imageUrl: mention.profilePicture,
                size: chipSize - 8,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                iconColor: theme.colorScheme.primary,
                fallbackIcon: Icons.person,
                iconSize: (chipSize - 8) / 2.5,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                '@${mention.name}',
                style: TextStyle(
                  fontSize: (chipSize - 8) / 1.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display a list of mentions at the bottom of a message
class MessageMentionsList extends StatelessWidget {
  final List<MentionedUser> mentions;
  final Function(MentionedUser)? onMentionTap;

  const MessageMentionsList({
    super.key,
    required this.mentions,
    this.onMentionTap,
  }) : assert(mentions != null, 'mentions cannot be null');

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: mentions.map((mention) {
          return MentionChip(
            mention: mention,
            onTap: onMentionTap,
            size: 20,
            showProfilePicture: false,
          );
        }).toList(),
      ),
    );
  }
}