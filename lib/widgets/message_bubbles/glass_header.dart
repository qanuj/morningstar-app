import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable glass effect header widget for message bubbles
class GlassHeader extends StatelessWidget {
  final String title;
  final Widget icon;
  final String? subtitle;

  const GlassHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  /// Factory constructor for poll headers
  factory GlassHeader.poll({
    bool isExpired = false,
  }) {
    return GlassHeader(
      title: 'Poll',
      icon: Icon(
        Icons.poll,
        color: Color(0xFF003f9b),
        size: 20,
      ),
      subtitle: isExpired ? 'Expired' : null,
    );
  }

  /// Factory constructor for match headers
  factory GlassHeader.match({
    bool isCancelled = false,
  }) {
    return GlassHeader(
      title: 'Match',
      icon: Icon(
        Icons.sports,
        color: Color(0xFF003f9b),
        size: 20,
      ),
      subtitle: isCancelled ? 'Cancelled' : null,
    );
  }

  /// Factory constructor for practice headers
  factory GlassHeader.practice({
    bool isCancelled = false,
  }) {
    return GlassHeader(
      title: 'Practice',
      icon: Text(
        '🏏',
        style: TextStyle(fontSize: 20),
      ),
      subtitle: isCancelled ? 'Cancelled' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              colors: [
                Color(0xFF003f9b).withOpacity(0.15),
                Color(0xFF06aeef).withOpacity(0.10),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFF003f9b).withOpacity(0.2),
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
                        color: Color(0xFF003f9b),
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
            ],
          ),
        ),
      ),
    );
  }
}