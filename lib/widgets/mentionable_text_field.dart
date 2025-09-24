import 'package:flutter/material.dart';
import '../models/mention.dart';

/// Controller for handling mention selections and styling
class MentionableTextFieldController extends TextEditingController {
  _MentionableTextFieldState? _state;

  void _attachState(_MentionableTextFieldState state) {
    _state = state;
  }

  void _detachState() {
    _state = null;
  }

  /// Select a mention from external sources (like overlay)
  void selectMentionExternal(Mention mention) {
    print('🎯 selectMentionExternal called for: ${mention.name}');
    if (_state == null) {
      print('❌ _state is null - controller not attached!');
      return;
    }
    print('🎯 Calling _state.selectMention');
    _state?.selectMention(mention);
  }

  @override
  TextSpan buildTextSpan({
    BuildContext? context,
    TextStyle? style,
    bool? withComposing,
  }) {
    final children = <InlineSpan>[];

    // Get theme-aware mention colors
    final isDark = context != null
        ? Theme.of(context).brightness == Brightness.dark
        : false;

    final mentionColor = isDark
        ? Color(0xFF64B5F6) // Light blue for dark mode
        : Color(0xFF1976D2); // Darker blue for light mode

    // Get default text color from theme
    final defaultTextColor = context != null
        ? (isDark ? Colors.white : Colors.black87)
        : Colors.black87;

    // Create base style with proper defaults
    final baseStyle = (style ?? TextStyle()).copyWith(
      color: style?.color ?? defaultTextColor,
      fontSize: style?.fontSize ?? 16,
    );

    // Pattern to match both completed mentions @[id:name] and partial mentions @username
    final completedMentionPattern = RegExp(r'@\[([^:]+):([^\]]+)\]');
    final partialMentionPattern = RegExp(r'@(\w+)');

    if (text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    // Debug logging
    print('🎨 buildTextSpan called with text: "$text"');
    final completedMentions = completedMentionPattern.allMatches(text);
    print('🎨 Found ${completedMentions.length} completed mentions');
    for (final match in completedMentions) {
      print(
        '🎨 Completed mention: ${match.group(0)} -> id: ${match.group(1)}, name: ${match.group(2)}',
      );
    }

    // First handle completed mentions @[id:name]
    String workingText = text;
    final mentionReplacements = <String, String>{};
    int replacementCounter = 0;

    // Replace completed mentions with temporary placeholders
    workingText = workingText.replaceAllMapped(completedMentionPattern, (
      match,
    ) {
      final placeholder = '__MENTION_${replacementCounter++}__';
      final userName = match.group(2)!;
      mentionReplacements[placeholder] = '@$userName';
      print(
        '🎨 Replacing "${match.group(0)}" with placeholder "$placeholder" -> display "@$userName"',
      );
      return placeholder;
    });

    print('🎨 Working text after replacements: "$workingText"');
    print('🎨 Mention replacements: $mentionReplacements');

    // Use a different approach to split and preserve matched parts
    final splitPattern = RegExp(r'(__MENTION_\d+__|@\w+)');
    final parts = <String>[];
    int lastEnd = 0;

    for (final match in splitPattern.allMatches(workingText)) {
      // Add text before the match
      if (match.start > lastEnd) {
        parts.add(workingText.substring(lastEnd, match.start));
      }
      // Add the matched part
      parts.add(match.group(0)!);
      lastEnd = match.end;
    }

    // Add remaining text after the last match
    if (lastEnd < workingText.length) {
      parts.add(workingText.substring(lastEnd));
    }

    print('🎨 Split parts: $parts');

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];

      if (part.isEmpty) continue;

      if (mentionReplacements.containsKey(part)) {
        // This is a completed mention - style it in blue with bold
        print(
          '🎨 Styling completed mention: "$part" -> "${mentionReplacements[part]}"',
        );
        children.add(
          TextSpan(
            text: mentionReplacements[part]!,
            style: baseStyle.copyWith(
              color: mentionColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (partialMentionPattern.hasMatch(part)) {
        // This is a partial mention like @anuj - style it in lighter blue
        print('🎨 Styling partial mention: "$part"');
        children.add(
          TextSpan(
            text: part,
            style: baseStyle.copyWith(
              color: mentionColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else {
        // Regular text
        print('🎨 Adding regular text: "$part"');
        children.add(TextSpan(text: part, style: baseStyle));
      }
    }

    return TextSpan(style: baseStyle, children: children);
  }
}

/// A text field that supports @mention functionality
///
/// This widget extends TextField with mention capabilities:
/// - Detects @ character input
/// - Shows mention suggestions overlay
/// - Formats mentions with special styling
/// - Preserves mention data for sending
class MentionableTextField extends StatefulWidget {
  final MentionableTextFieldController controller;
  final FocusNode? focusNode;
  final Function(String query)? onMentionTriggered;
  final Function? onMentionCancelled;
  final Function(Mention mention)? onMentionSelected;
  final List<Mention> mentionSuggestions;
  final bool showMentionOverlay;
  final String? hintText;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool enabled;
  final bool autofocus;
  final Function(String)? onChanged;
  final Function()? onTap;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Function(String)? onSubmitted;

  const MentionableTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onMentionTriggered,
    this.onMentionCancelled,
    this.onMentionSelected,
    this.mentionSuggestions = const [],
    this.showMentionOverlay = false,
    this.hintText,
    this.maxLines = 1,
    this.minLines,
    this.style,
    this.decoration,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onTap,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<MentionableTextField> createState() => _MentionableTextFieldState();
}

class _MentionableTextFieldState extends State<MentionableTextField> {
  late final FocusNode _focusNode;
  String _currentMentionQuery = '';
  int _mentionStartIndex = -1;
  bool _isMentioning = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onTextChanged);
    widget.controller._attachState(this);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.controller._detachState();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.start != selection.end) {
      _cancelMentioning();
      return;
    }

    final cursorPosition = selection.start;
    _detectMention(text, cursorPosition);
  }

  void _detectMention(String text, int cursorPosition) {
    // Find the last @ before cursor position
    int lastAtIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        // Check if @ is at start or preceded by whitespace
        if (i == 0 || text[i - 1].trim().isEmpty) {
          lastAtIndex = i;
          break;
        }
      } else if (text[i].trim().isEmpty) {
        // Hit whitespace before finding @, stop searching
        break;
      }
    }

    if (lastAtIndex != -1) {
      // Extract potential mention query
      final mentionText = text.substring(lastAtIndex + 1, cursorPosition);

      // Check if this is a valid mention (no spaces)
      if (!mentionText.contains(' ') && mentionText.length <= 50) {
        if (!_isMentioning) {
          _startMentioning(lastAtIndex, mentionText);
        } else {
          _updateMentioning(mentionText);
        }
        return;
      }
    }

    // Not mentioning
    if (_isMentioning) {
      _cancelMentioning();
    }
  }

  void _startMentioning(int startIndex, String query) {
    setState(() {
      _isMentioning = true;
      _mentionStartIndex = startIndex;
      _currentMentionQuery = query;
    });

    widget.onMentionTriggered?.call(query);
  }

  void _updateMentioning(String query) {
    setState(() {
      _currentMentionQuery = query;
    });

    widget.onMentionTriggered?.call(query);
  }

  void _cancelMentioning() {
    if (_isMentioning) {
      setState(() {
        _isMentioning = false;
        _mentionStartIndex = -1;
        _currentMentionQuery = '';
      });

      widget.onMentionCancelled?.call();
    }
  }

  void selectMention(Mention mention) {
    print('🎯 selectMention called with: ${mention.name}');
    print(
      '🎯 _isMentioning: $_isMentioning, _mentionStartIndex: $_mentionStartIndex',
    );

    if (!_isMentioning || _mentionStartIndex == -1) {
      print(
        '❌ Cannot select mention - not in mentioning state or invalid start index',
      );
      return;
    }

    final currentText = widget.controller.text;
    final selection = widget.controller.selection;
    print('🎯 Current text: "$currentText"');
    print('🎯 Selection: ${selection.start}-${selection.end}');

    // Replace @query with @[userId:userName]
    final mentionText = '@[${mention.id}:${mention.name}]';
    final beforeMention = currentText.substring(0, _mentionStartIndex);
    final afterMention = currentText.substring(selection.start);

    final newText = beforeMention + mentionText + afterMention;
    final newCursorPosition = beforeMention.length + mentionText.length;

    print('🎯 Mention format created: "$mentionText"');
    print('🎯 Before: "$beforeMention", After: "$afterMention"');
    print('🎯 Final text will be: "$newText"');

    // Update text with the formatted mention
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    print('🎯 Mention inserted: "$newText"');
    print('🎯 New cursor position: $newCursorPosition');
    print('🎯 Controller text after update: "${widget.controller.text}"');

    _cancelMentioning();
    widget.onMentionSelected?.call(mention);
  }

  /// Extract mentions from the current text
  List<Mention> extractMentions() {
    final text = widget.controller.text;
    final mentionRegex = RegExp(r'@\[([^:]+):([^\]]+)\]');
    final mentions = <Mention>[];

    for (final match in mentionRegex.allMatches(text)) {
      final userId = match.group(1);
      final userName = match.group(2);

      if (userId != null && userName != null) {
        mentions.add(
          Mention(
            id: userId,
            name: userName,
            role: 'MEMBER', // Default role, can be enhanced
          ),
        );
      }
    }

    return mentions;
  }

  /// Get display text with mentions formatted for UI
  String getDisplayText() {
    String text = widget.controller.text;

    // Replace mention format with display format
    text = text.replaceAllMapped(
      RegExp(r'@\[([^:]+):([^\]]+)\]'),
      (match) => '@${match.group(2)}', // Show @userName
    );

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      style: widget.style,
      decoration: widget.decoration,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      onChanged: (value) {
        // Call the external onChanged if provided
        widget.onChanged?.call(value);
      },
      onTap: () {
        widget.onTap?.call();
      },
      onSubmitted: widget.onSubmitted,
    );
  }
}

/// Extension to provide mention utilities
extension MentionableTextFieldExtensions on TextEditingController {
  /// Extract mention IDs from the text
  List<String> extractMentionIds() {
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

  /// Get clean text without mention formatting for display
  String getCleanText() {
    return text.replaceAllMapped(
      RegExp(r'@\[([^:]+):([^\]]+)\]'),
      (match) => '@${match.group(2)}', // Show @userName
    );
  }

  /// Check if text contains mentions
  bool hasMentions() {
    return RegExp(r'@\[([^:]+):[^\]]+\]').hasMatch(text);
  }
}
