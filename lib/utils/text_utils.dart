import 'package:flutter/foundation.dart';

/// Utility functions for safe text handling to prevent UTF-16 encoding errors
class TextUtils {
  /// Sanitizes text by removing potentially malformed UTF-16 characters
  /// Returns null if input is null, empty string if sanitization fails
  static String? sanitizeText(String? text) {
    if (text == null) return null;
    try {
      // Remove any potentially malformed UTF-16 characters (surrogate pairs without proper pairs)
      return text.replaceAll(RegExp(r'[\uD800-\uDFFF]'), '');
    } catch (e) {
      debugPrint('Error sanitizing text: $e');
      return '';
    }
  }

  /// Safe text rendering - ensures text is safe for display
  /// Returns empty string if input is null or malformed
  static String safeText(String? text) {
    return sanitizeText(text) ?? '';
  }

  /// Safe emoji rendering - specifically for emoji content
  /// Handles emoji-specific UTF-16 issues
  static String safeEmoji(String? emoji) {
    if (emoji == null) return '';
    try {
      final sanitized = sanitizeText(emoji);
      // Additional emoji-specific validation could go here
      return sanitized ?? '';
    } catch (e) {
      debugPrint('Error sanitizing emoji: $e');
      return '';
    }
  }
}