import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/media_storage_service.dart';

/// A versatile avatar widget that handles both SVG and regular images
/// with proper fallback handling and consistent styling across the app
class SVGAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final IconData fallbackIcon;
  final double? iconSize;
  final String? fallbackText;
  final TextStyle? fallbackTextStyle;
  final BoxFit fit;
  final Widget? child;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const SVGAvatar({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.backgroundColor,
    this.iconColor,
    this.fallbackIcon = Icons.person,
    this.iconSize,
    this.fallbackText,
    this.fallbackTextStyle,
    this.fit = BoxFit.cover,
    this.child,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.0,
    this.onTap,
  });

  /// Factory constructor for small avatars (24px)
  factory SVGAvatar.small({
    String? imageUrl,
    Color? backgroundColor,
    Color? iconColor,
    IconData fallbackIcon = Icons.person,
    VoidCallback? onTap,
  }) {
    return SVGAvatar(
      imageUrl: imageUrl,
      size: 24,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      fallbackIcon: fallbackIcon,
      iconSize: 14,
      onTap: onTap,
    );
  }

  /// Factory constructor for medium avatars (40px) - default
  factory SVGAvatar.medium({
    String? imageUrl,
    Color? backgroundColor,
    Color? iconColor,
    IconData fallbackIcon = Icons.person,
    bool showBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return SVGAvatar(
      imageUrl: imageUrl,
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

  /// Factory constructor for large avatars (64px)
  factory SVGAvatar.large({
    String? imageUrl,
    Color? backgroundColor,
    Color? iconColor,
    IconData fallbackIcon = Icons.person,
    bool showBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return SVGAvatar(
      imageUrl: imageUrl,
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

  /// Factory constructor for extra large avatars (96px)
  factory SVGAvatar.extraLarge({
    String? imageUrl,
    Color? backgroundColor,
    Color? iconColor,
    IconData fallbackIcon = Icons.person,
    bool showBorder = false,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return SVGAvatar(
      imageUrl: imageUrl,
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

  /// Check if the URL points to an SVG image
  bool _isSvg(String url) {
    return url.toLowerCase().contains('.svg') || 
           url.toLowerCase().contains('svg?') ||
           url.toLowerCase().contains('/svg/') ||
           url.toLowerCase().contains('dicebear.com');
  }

  /// Get default background color based on theme
  Color _getBackgroundColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey[700]! : Colors.grey[300]!;
  }

  /// Get default icon color based on theme
  Color _getIconColor(BuildContext context) {
    if (iconColor != null) return iconColor!;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white.withOpacity(0.8) : Colors.black54;
  }

  /// Generate initials from text (e.g., "Morningstar" -> "MO", "Spartan Kings" -> "SK")
  String _generateInitials(String text) {
    if (text.isEmpty) return '';
    
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      // Single word: take first two characters
      return words[0].length >= 2 
          ? words[0].substring(0, 2).toUpperCase()
          : words[0].substring(0, 1).toUpperCase();
    } else {
      // Multiple words: take first letter of first two words
      return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
    }
  }

  /// Build the fallback widget (text or icon)
  Widget _buildFallback(BuildContext context) {
    // If fallbackText is provided, use text instead of icon
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      final initials = _generateInitials(fallbackText!);
      return Center(
        child: Text(
          initials,
          style: fallbackTextStyle ?? TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: _getIconColor(context),
          ),
        ),
      );
    }
    
    // Default to icon fallback
    return Icon(
      fallbackIcon,
      size: iconSize ?? (size * 0.6),
      color: _getIconColor(context),
    );
  }

  /// Build the image widget (SVG or regular) with caching
  Widget _buildImage(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback(context);
    }

    return FutureBuilder<String?>(
      future: MediaStorageService.getCachedMediaPath(imageUrl!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildFallback(context);
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildFallback(context);
        }

        final localPath = snapshot.data!;

        if (_isSvg(imageUrl!)) {
          // For SVG, check if it's a local file or still needs network loading
          if (File(localPath).existsSync()) {
            return SvgPicture.file(
              File(localPath),
              width: size,
              height: size,
              fit: fit,
              placeholderBuilder: (context) => _buildFallback(context),
              semanticsLabel: 'User avatar',
            );
          } else {
            return SvgPicture.network(
              imageUrl!,
              width: size,
              height: size,
              fit: fit,
              placeholderBuilder: (context) => _buildFallback(context),
              semanticsLabel: 'User avatar',
            );
          }
        } else {
          // For regular images
          if (File(localPath).existsSync()) {
            return Image.file(
              File(localPath),
              width: size,
              height: size,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _buildFallback(context),
            );
          } else {
            return Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _buildFallback(context),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildFallback(context);
              },
            );
          }
        }
      },
    );
  }

  /// Build the complete avatar widget
  Widget _buildAvatar(BuildContext context) {
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getBackgroundColor(context),
        border: showBorder ? Border.all(
          color: borderColor ?? Theme.of(context).primaryColor,
          width: borderWidth,
        ) : null,
      ),
      child: ClipOval(
        child: child ?? _buildImage(context),
      ),
    );

    // Wrap with GestureDetector if onTap is provided
    if (onTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  @override
  Widget build(BuildContext context) {
    return _buildAvatar(context);
  }
}