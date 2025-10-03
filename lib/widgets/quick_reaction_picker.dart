import 'package:flutter/material.dart';

/// Reusable quick reaction picker widget
class QuickReactionPicker extends StatelessWidget {
  final Function(String emoji) onReactionSelected;
  final List<String> reactions;
  final double fontSize;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const QuickReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.reactions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    this.fontSize = 32,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
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
        children: reactions.asMap().entries.map((entry) {
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
              if (!isLast) const SizedBox(width: 5), // 5px margin between emojis
            ],
          );
        }).toList(),
      ),
    );
  }
}
