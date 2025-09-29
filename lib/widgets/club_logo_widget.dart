import 'package:flutter/material.dart';
import '../models/club.dart';
import 'svg_avatar.dart';

/// Reusable widget for displaying club logos with consistent fallback behavior
class ClubLogoWidget extends StatelessWidget {
  final Club club;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final IconData fallbackIcon;
  final double? iconSize;
  final bool showBorder;
  final Color? borderColor;
  final double? borderWidth;
  final BoxFit fit;
  final VoidCallback? onTap;

  const ClubLogoWidget({
    super.key,
    required this.club,
    this.size = 40,
    this.backgroundColor,
    this.iconColor,
    this.fallbackIcon = Icons.sports_cricket,
    this.iconSize,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  /// Factory constructor for small club logos (24px)
  factory ClubLogoWidget.small({
    required Club club,
    Color? backgroundColor,
    Color? iconColor,
    IconData fallbackIcon = Icons.sports_cricket,
    bool showBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return ClubLogoWidget(
      club: club,
      size: 24,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      fallbackIcon: fallbackIcon,
      iconSize: 14,
      showBorder: showBorder,
      borderColor: borderColor,
      onTap: onTap,
    );
  }

  /// Factory constructor for medium club logos (40px) - default
  factory ClubLogoWidget.medium({
    required Club club,
    Color? backgroundColor,
    Color? iconColor,
    IconData fallbackIcon = Icons.sports_cricket,
    bool showBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return ClubLogoWidget(
      club: club,
      size: 40,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      fallbackIcon: fallbackIcon,
      iconSize: 24,
      showBorder: showBorder,
      borderColor: borderColor,
      onTap: onTap,
    );
  }

  /// Factory constructor for large club logos (64px)
  factory ClubLogoWidget.large({
    required Club club,
    Color? backgroundColor,
    Color? iconColor,
    IconData fallbackIcon = Icons.sports_cricket,
    bool showBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return ClubLogoWidget(
      club: club,
      size: 64,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      fallbackIcon: fallbackIcon,
      iconSize: 36,
      showBorder: showBorder,
      borderColor: borderColor,
      onTap: onTap,
    );
  }

  /// Factory constructor for extra large club logos (96px)
  factory ClubLogoWidget.extraLarge({
    required Club club,
    Color? backgroundColor,
    Color? iconColor,
    IconData fallbackIcon = Icons.sports_cricket,
    bool showBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return ClubLogoWidget(
      club: club,
      size: 96,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      fallbackIcon: fallbackIcon,
      iconSize: 48,
      showBorder: showBorder,
      borderColor: borderColor,
      onTap: onTap,
    );
  }

  /// Factory constructor for app bar usage (32px)
  factory ClubLogoWidget.appBar({
    required Club club,
    Color? backgroundColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ClubLogoWidget(
      club: club,
      size: 32,
      iconColor: iconColor ?? Colors.white70,
      fallbackIcon: Icons.sports_cricket,
      iconSize: 20,
      showBorder: false,
      onTap: onTap,
    );
  }

  /// Factory constructor for circular club logo with fallback text
  factory ClubLogoWidget.withFallbackText({
    required Club club,
    double size = 40,
    Color? backgroundColor,
    Color? iconColor,
    bool showBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return ClubLogoWidget(
      club: club,
      size: size,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      fallbackIcon: Icons.sports_cricket,
      iconSize: size / 2,
      showBorder: showBorder,
      borderColor: borderColor,
      onTap: onTap,
    );
  }

  /// Factory constructor for colorful text fallbacks
  factory ClubLogoWidget.colorfulText({
    required Club club,
    double size = 40,
    bool showBorder = false,
    VoidCallback? onTap,
  }) {
    return ClubLogoWidget(
      club: club,
      size: size,
      backgroundColor: _getColorFromClubName(club.name),
      iconColor: Colors.white,
      fallbackIcon: Icons.sports_cricket,
      iconSize: size / 2,
      showBorder: showBorder,
      borderColor: showBorder ? Colors.white.withOpacity(0.3) : null,
      onTap: onTap,
    );
  }

  /// Generate a color based on club name for consistent appearance
  static Color _getColorFromClubName(String name) {
    final colors = [
      Color(0xFF003f9b), // Primary blue
      Color(0xFF06aeef), // Light blue
      Color(0xFF4dd0ff), // Lighter blue
      Color(0xFF16a34a), // Green
      Color(0xFFf59e0b), // Orange
      Color(0xFF8b5cf6), // Purple
      Color(0xFFef4444), // Red
      Color(0xFF059669), // Emerald
      Color(0xFF7c3aed), // Violet
      Color(0xFFdc2626), // Red
    ];
    final hash = name.toLowerCase().hashCode;
    print('Hash for club name "$name": $hash');
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    // Use club logo if available, otherwise show fallback
    final hasLogo = club.logo != null && club.logo!.isNotEmpty;

    // For text fallbacks, ensure we have a solid background color for visibility
    final effectiveBackgroundColor = hasLogo
        ? (backgroundColor ?? Colors.transparent)
        : (backgroundColor ?? _getColorFromClubName(club.name));

    print('Building ClubLogoWidget for club: ${club.name}, hasLogo: $hasLogo');

    // For text fallbacks, ensure we have white text on colored background
    final effectiveIconColor = hasLogo
        ? (iconColor ?? Theme.of(context).colorScheme.primary)
        : Colors.white;

    return SVGAvatar(
      imageUrl: hasLogo ? club.logo : null,
      size: size,
      backgroundColor: effectiveBackgroundColor,
      iconColor: effectiveIconColor,
      fallbackIcon: fallbackIcon,
      iconSize: iconSize ?? size / 2,
      fallbackText: hasLogo ? null : _getClubInitials(),
      fallbackTextStyle: TextStyle(
        fontSize: size / 2.5,
        fontWeight: FontWeight.w600,
        color: effectiveIconColor,
      ),
      showBorder: showBorder,
      borderColor: borderColor,
      borderWidth: borderWidth ?? (showBorder ? 2.0 : 0.0),
      fit: fit,
      onTap: onTap,
      isAvatarMode: true, // Ensure circular background
    );
  }

  /// Get club name initials for fallback text
  String _getClubInitials() {
    final name = club.name.trim();
    if (name.isEmpty) return 'C';

    final words = name.split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return (words[0].substring(0, 1) + words[1].substring(0, 1))
          .toUpperCase();
    }
  }
}
