import 'package:flutter/material.dart';

/// Reusable quick reaction picker widget
class QuickReactionPicker extends StatelessWidget {
  final Function(String emoji) onReactionSelected;
  final VoidCallback? onMoreEmojis;
  final List<String> reactions;
  final double fontSize;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final bool showPlusButton;

  const QuickReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.onMoreEmojis,
    this.reactions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    this.fontSize = 32,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
    this.showPlusButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth * 0.8; // 80% of available width

    return Container(
      width: containerWidth,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? const Color(0xFF2a2f32) : Colors.white),
        borderRadius: borderRadius ?? BorderRadius.circular(25),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Regular emoji reactions
          ...reactions.asMap().entries.map((entry) {
            final emoji = entry.value;
            final isLast = entry.key == reactions.length - 1;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => onReactionSelected(emoji),
                  child: Container(
                    width: 36, // Fixed width for perfect circle
                    height: 36, // Fixed height for perfect circle
                    child: Center(
                      child: Text(emoji, style: TextStyle(fontSize: fontSize)),
                    ),
                  ),
                ),
                if (!isLast || showPlusButton) const SizedBox(width: 5), // 5px margin between emojis
              ],
            );
          }).toList(),

          // Plus button for more emojis
          if (showPlusButton)
            GestureDetector(
              onTap: () {
                if (onMoreEmojis != null) {
                  onMoreEmojis!();
                } else {
                  // Default behavior: show native emoji input dialog
                  _showEmojiInputDialog(context);
                }
              },
              child: Container(
                width: 36, // Fixed width for perfect circle
                height: 36, // Fixed height for perfect circle
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showEmojiInputDialog(BuildContext context) {
    _showDirectEmojiKeyboard(context);
  }

  void _showDirectEmojiKeyboard(BuildContext context) {
    final TextEditingController emojiController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // Position off-screen but still accessible to keyboard
        top: -100,
        left: 0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 1,
            height: 1,
            child: TextField(
              controller: emojiController,
              focusNode: focusNode,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '😀', // Hint to suggest emoji input
              ),
              onChanged: (text) {
                if (text.isNotEmpty) {
                  // Extract first emoji character
                  final firstEmoji = text.characters.first;

                  // Remove overlay
                  overlayEntry?.remove();

                  // Call the reaction callback
                  onReactionSelected(firstEmoji);
                }
              },
              onTapOutside: (event) {
                // Close when user taps outside
                overlayEntry?.remove();
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // Auto-focus to open keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }
}
