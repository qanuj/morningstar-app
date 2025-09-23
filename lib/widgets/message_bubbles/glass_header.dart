import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable glass effect header widget for message bubbles
class GlassHeader extends StatelessWidget {
  final String title;
  final Widget icon;
  final String? subtitle;
  final Widget? trailing;

  const GlassHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
  });

  /// Factory constructor for poll headers
  factory GlassHeader.poll({
    bool isExpired = false,
    Widget? trailing,
    required BuildContext context,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GlassHeader(
      title: 'Poll',
      icon: Icon(
        Icons.poll,
        color: isDarkMode ? Colors.white.withOpacity(0.9) : Color(0xFF003f9b),
        size: 20,
      ),
      subtitle: isExpired ? 'Expired' : null,
      trailing: trailing,
    );
  }

  /// Factory constructor for match headers
  factory GlassHeader.match({
    bool isCancelled = false,
    Widget? trailing,
    required BuildContext context,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GlassHeader(
      title: 'Match',
      icon: Icon(
        Icons.sports,
        color: isDarkMode ? Colors.white.withOpacity(0.9) : Color(0xFF003f9b),
        size: 20,
      ),
      subtitle: isCancelled ? 'Cancelled' : null,
      trailing: trailing,
    );
  }

  /// Factory constructor for practice headers
  factory GlassHeader.practice({
    bool isCancelled = false,
    Widget? trailing,
    required BuildContext context,
  }) {
    return GlassHeader(
      title: 'Practice',
      icon: Text('🏏', style: TextStyle(fontSize: 20)),
      subtitle: isCancelled ? 'Cancelled' : null,
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                      Colors.white.withOpacity(0.15),
                      Colors.grey[300]!.withOpacity(0.10),
                    ]
                  : [
                      Color(0xFF003f9b).withOpacity(0.15),
                      Color(0xFF06aeef).withOpacity(0.10),
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Color(0xFF003f9b).withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              icon,
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.9)
                            : Color(0xFF003f9b),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
