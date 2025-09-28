import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/mention.dart';

/// A widget that renders text with markdown formatting and tappable mentions
class MarkdownMentionText extends StatelessWidget {
  final String text;
  final List<MentionedUser> mentions;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const MarkdownMentionText({
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
    return RichText(
      text: _buildTextSpan(context),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  TextSpan _buildTextSpan(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mentionColor = isDark
        ? const Color(0xFF64B5F6) // Light blue for dark mode
        : const Color(0xFF1976D2); // Darker blue for light mode

    // Base text style
    final baseStyle = style ?? const TextStyle();

    // Parse the text for both markdown and mentions
    return _parseText(text, context, baseStyle, mentionColor);
  }

  TextSpan _parseText(
    String text,
    BuildContext context,
    TextStyle baseStyle,
    Color mentionColor,
  ) {
    // Process text sequentially for different markdown patterns
    return _processFormattedText(text, context, baseStyle, mentionColor);
  }

  TextSpan _processFormattedText(
    String text,
    BuildContext context,
    TextStyle baseStyle,
    Color mentionColor,
  ) {
    final children = <InlineSpan>[];

    // Split text by lines for list and quote processing
    final lines = text.split('\n');

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      String line = lines[lineIndex];

      // Add newline before each line except the first
      if (lineIndex > 0) {
        children.add(const TextSpan(text: '\n'));
      }

      // Check for list patterns
      if (_isListItem(line)) {
        children.add(_parseListItem(line, context, baseStyle));
        continue;
      }

      // Check for quote pattern
      if (_isQuote(line)) {
        children.add(_parseQuote(line, context, baseStyle));
        continue;
      }

      // Process inline formatting for regular lines
      children.addAll(
        _parseInlineFormatting(line, context, baseStyle, mentionColor),
      );
    }

    return TextSpan(children: children);
  }

  bool _isListItem(String line) {
    return RegExp(r'^[ ]*[\*\-] .+').hasMatch(line) ||
        RegExp(r'^[ ]*\d+\. .+').hasMatch(line);
  }

  bool _isQuote(String line) {
    return RegExp(r'^[ ]*> .+').hasMatch(line);
  }

  TextSpan _parseListItem(
    String line,
    BuildContext context,
    TextStyle baseStyle,
  ) {
    return TextSpan(text: line, style: baseStyle);
  }

  TextSpan _parseQuote(String line, BuildContext context, TextStyle baseStyle) {
    return TextSpan(
      text: line,
      style: baseStyle.copyWith(
        fontStyle: FontStyle.italic,
        color: (baseStyle.color ?? Colors.black).withOpacity(0.7),
      ),
    );
  }

  List<TextSpan> _parseInlineFormatting(
    String text,
    BuildContext context,
    TextStyle baseStyle,
    Color mentionColor,
  ) {
    final children = <TextSpan>[];

    // Process mentions, bold, italic, strikethrough, and code inline
    final pattern = RegExp(
      r'(@\[([^:]+):([^\]]+)\])|' // Mentions: @[id:name]
      r'(\*\*([^*\n]+)\*\*)|' // Bold: **text**
      r'(\*([^*\n]+)\*)|' // Bold (alternative): *text*
      r'(_([^_\n]+)_)|' // Italic: _text_
      r'(~([^~\n]+)~)|' // Strikethrough: ~text~
      r'(```([^`\n]+)```)|' // Code block: ```text```
      r'(`([^`\n]+)`)', // Inline code: `text`
    );

    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        final beforeText = text.substring(lastEnd, match.start);
        children.add(TextSpan(text: beforeText, style: baseStyle));
      }

      // Handle different types of matches
      if (match.group(1) != null) {
        // Mention: @[id:name]
        final mentionId = match.group(2)!;
        final mentionName = match.group(3)!;
        final mentionedUser = mentions.firstWhere(
          (user) => user.id == mentionId,
          orElse: () =>
              MentionedUser(id: mentionId, name: mentionName, role: 'MEMBER'),
        );

        children.add(
          TextSpan(
            text: '@$mentionName',
            style: baseStyle.copyWith(
              color: mentionColor,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showMentionDialog(context, mentionedUser),
          ),
        );
      } else if (match.group(4) != null) {
        // Bold: **text**
        final boldText = match.group(5)!;
        children.add(
          TextSpan(
            text: boldText,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(6) != null) {
        // Bold (alternative): *text*
        final boldText = match.group(7)!;
        children.add(
          TextSpan(
            text: boldText,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(8) != null) {
        // Italic: _text_
        final italicText = match.group(9)!;
        children.add(
          TextSpan(
            text: italicText,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(10) != null) {
        // Strikethrough: ~text~
        final strikeText = match.group(11)!;
        children.add(
          TextSpan(
            text: strikeText,
            style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (match.group(12) != null) {
        // Code block: ```text```
        final codeText = match.group(13)!;
        children.add(
          TextSpan(
            text: codeText,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
              fontSize: (baseStyle.fontSize ?? 14) * 0.9,
            ),
          ),
        );
      } else if (match.group(14) != null) {
        // Inline code: `text`
        final inlineCodeText = match.group(15)!;
        children.add(
          TextSpan(
            text: inlineCodeText,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
              fontSize: (baseStyle.fontSize ?? 14) * 0.9,
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    // Add remaining text after the last match
    if (lastEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return children;
  }

  void _showMentionDialog(BuildContext context, MentionedUser mentionedUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('@${mentionedUser.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: ${mentionedUser.role}'),
            const SizedBox(height: 8),
            Text('ID: ${mentionedUser.id}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
