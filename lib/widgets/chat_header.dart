import 'package:flutter/material.dart';

/// Enum to define different types of chat headers
enum ChatHeaderType {
  date,
  announcement,
  event,
  custom,
}

/// A generic header widget for chat screens
/// Supports multiple header types with consistent styling and customization options
class ChatHeader extends StatelessWidget {
  final ChatHeaderType type;
  final dynamic data;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final BorderRadius? borderRadius;
  final String? customText;
  final Widget? customChild;

  const ChatHeader({
    super.key,
    required this.type,
    this.data,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.borderRadius,
    this.customText,
    this.customChild,
  });

  /// Factory constructor for date headers
  factory ChatHeader.date({
    Key? key,
    required DateTime date,
    EdgeInsets? margin,
    EdgeInsets? padding,
    Color? backgroundColor,
    Color? textColor,
    double? fontSize,
    FontWeight? fontWeight,
    BorderRadius? borderRadius,
  }) {
    return ChatHeader(
      key: key,
      type: ChatHeaderType.date,
      data: date,
      margin: margin,
      padding: padding,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      borderRadius: borderRadius,
    );
  }

  /// Factory constructor for announcement headers
  factory ChatHeader.announcement({
    Key? key,
    required String text,
    EdgeInsets? margin,
    EdgeInsets? padding,
    Color? backgroundColor,
    Color? textColor,
    double? fontSize,
    FontWeight? fontWeight,
    BorderRadius? borderRadius,
  }) {
    return ChatHeader(
      key: key,
      type: ChatHeaderType.announcement,
      customText: text,
      margin: margin,
      padding: padding,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      borderRadius: borderRadius,
    );
  }

  /// Factory constructor for event headers
  factory ChatHeader.event({
    Key? key,
    required String eventText,
    EdgeInsets? margin,
    EdgeInsets? padding,
    Color? backgroundColor,
    Color? textColor,
    double? fontSize,
    FontWeight? fontWeight,
    BorderRadius? borderRadius,
  }) {
    return ChatHeader(
      key: key,
      type: ChatHeaderType.event,
      customText: eventText,
      margin: margin,
      padding: padding,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      borderRadius: borderRadius,
    );
  }

  /// Factory constructor for custom headers
  factory ChatHeader.custom({
    Key? key,
    Widget? child,
    String? text,
    EdgeInsets? margin,
    EdgeInsets? padding,
    Color? backgroundColor,
    Color? textColor,
    double? fontSize,
    FontWeight? fontWeight,
    BorderRadius? borderRadius,
  }) {
    return ChatHeader(
      key: key,
      type: ChatHeaderType.custom,
      customChild: child,
      customText: text,
      margin: margin,
      padding: padding,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 16.0),
      alignment: Alignment.center,
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: backgroundColor ?? _getDefaultBackgroundColor(context),
          borderRadius: borderRadius ?? BorderRadius.circular(16.0),
        ),
        child: _buildHeaderContent(context),
      ),
    );
  }

  Widget _buildHeaderContent(BuildContext context) {
    // If custom child is provided, use it
    if (customChild != null) {
      return customChild!;
    }

    // Build content based on header type
    String headerText;
    switch (type) {
      case ChatHeaderType.date:
        headerText = _formatDateText(data as DateTime);
        break;
      case ChatHeaderType.announcement:
      case ChatHeaderType.event:
      case ChatHeaderType.custom:
        headerText = customText ?? '';
        break;
    }

    return Text(
      headerText,
      style: TextStyle(
        fontSize: fontSize ?? _getDefaultFontSize(),
        fontWeight: fontWeight ?? FontWeight.w500,
        color: textColor ?? _getDefaultTextColor(context),
      ),
    );
  }

  String _formatDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDate(date, today)) {
      return 'Today';
    } else if (_isSameDate(date, yesterday)) {
      return 'Yesterday';
    } else {
      // Format as "Mon, Jan 15, 2024"
      const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];

      final weekday = weekdays[date.weekday % 7];
      final month = months[date.month - 1];

      return '$weekday, $month ${date.day}, ${date.year}';
    }
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Color _getDefaultBackgroundColor(BuildContext context) {
    switch (type) {
      case ChatHeaderType.date:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]!
            : Colors.grey.shade200;
      case ChatHeaderType.announcement:
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF06aeef).withOpacity(0.2)
            : const Color(0xFF06aeef).withOpacity(0.1);
      case ChatHeaderType.event:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.orange.withOpacity(0.2)
            : Colors.orange.withOpacity(0.1);
      case ChatHeaderType.custom:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]!
            : Colors.grey.shade200;
    }
  }

  Color _getDefaultTextColor(BuildContext context) {
    switch (type) {
      case ChatHeaderType.date:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]!
            : Colors.grey.shade600;
      case ChatHeaderType.announcement:
        return const Color(0xFF06aeef);
      case ChatHeaderType.event:
        return Colors.orange.shade700;
      case ChatHeaderType.custom:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]!
            : Colors.grey.shade600;
    }
  }

  double _getDefaultFontSize() {
    switch (type) {
      case ChatHeaderType.date:
        return 12.0;
      case ChatHeaderType.announcement:
        return 13.0;
      case ChatHeaderType.event:
        return 13.0;
      case ChatHeaderType.custom:
        return 12.0;
    }
  }
}