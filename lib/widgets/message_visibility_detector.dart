import 'package:flutter/material.dart';

/// A reusable widget that detects when its child becomes visible on screen
/// and triggers a callback. Useful for marking messages as read, tracking
/// impressions, or any other visibility-based functionality.
class MessageVisibilityDetector extends StatefulWidget {
  /// Unique identifier for the item being tracked
  final String itemId;
  
  /// Callback function triggered when the item becomes visible
  /// Receives the itemId as parameter
  final Function(String) onVisible;
  
  /// The widget to wrap and monitor for visibility
  final Widget child;
  
  /// Optional: Skip visibility tracking if this condition is true
  /// For example, skip tracking for own messages in chat
  final bool skipTracking;
  
  /// Optional: Custom visibility threshold (0.0 to 1.0)
  /// Determines what percentage of the widget must be visible to trigger callback
  /// Default is 0.5 (50% visible)
  final double visibilityThreshold;
  
  /// Optional: Custom safe area adjustments
  /// Top padding to account for app bars, headers, etc.
  final double topPadding;
  
  /// Optional: Custom safe area adjustments
  /// Bottom padding to account for input areas, navigation bars, etc.
  final double bottomPadding;

  const MessageVisibilityDetector({
    super.key,
    required this.itemId,
    required this.onVisible,
    required this.child,
    this.skipTracking = false,
    this.visibilityThreshold = 0.5,
    this.topPadding = 100.0,
    this.bottomPadding = 150.0,
  });

  @override
  State<MessageVisibilityDetector> createState() => _MessageVisibilityDetectorState();
}

class _MessageVisibilityDetectorState extends State<MessageVisibilityDetector> {
  bool _hasBeenSeen = false;

  @override
  void initState() {
    super.initState();
    // Check visibility after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Skip tracking if requested
    if (widget.skipTracking) {
      return widget.child;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_hasBeenSeen) {
          // Check visibility on any scroll notification
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkVisibility();
          });
        }
        return false; // Don't consume the notification
      },
      child: widget.child,
    );
  }

  /// Checks if the widget is currently visible on screen
  void _checkVisibility() {
    if (_hasBeenSeen || !mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      debugPrint('👁️ No render box for item ${widget.itemId}');
      return;
    }

    try {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      final screenHeight = MediaQuery.of(context).size.height;
      final topSafeArea = MediaQuery.of(context).padding.top;
      final bottomSafeArea = MediaQuery.of(context).padding.bottom;

      // Calculate visible screen area with custom padding
      final visibleTop = topSafeArea + widget.topPadding;
      final visibleBottom = screenHeight - bottomSafeArea - widget.bottomPadding;

      // Check if item is visible in the viewport
      final itemTop = position.dy;
      final itemBottom = position.dy + size.height;

      // Calculate how much of the item is visible
      final visibleHeight = (itemBottom.clamp(visibleTop, visibleBottom) -
          itemTop.clamp(visibleTop, visibleBottom));
      final visibilityRatio = visibleHeight / size.height;

      // Trigger callback if visibility threshold is met
      if (visibilityRatio >= widget.visibilityThreshold) {
        debugPrint('✅ Item ${widget.itemId} is visible! (${(visibilityRatio * 100).toStringAsFixed(1)}% visible)');
        _hasBeenSeen = true;
        widget.onVisible(widget.itemId);
      }
    } catch (e) {
      // Handle any errors in visibility calculation
      debugPrint('❌ Error checking visibility for item ${widget.itemId}: $e');
    }
  }

  /// Reset the visibility state - useful for dynamic content
  void resetVisibility() {
    _hasBeenSeen = false;
  }
}

/// Extension to provide helper methods for common use cases
extension MessageVisibilityDetectorExtension on Widget {
  /// Wrap this widget with visibility tracking
  /// 
  /// Example usage:
  /// ```dart
  /// Text('Hello World').trackVisibility(
  ///   itemId: 'message-123',
  ///   onVisible: (id) => markAsRead(id),
  /// )
  /// ```
  Widget trackVisibility({
    required String itemId,
    required Function(String) onVisible,
    bool skipTracking = false,
    double visibilityThreshold = 0.5,
    double topPadding = 100.0,
    double bottomPadding = 150.0,
  }) {
    return MessageVisibilityDetector(
      itemId: itemId,
      onVisible: onVisible,
      skipTracking: skipTracking,
      visibilityThreshold: visibilityThreshold,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      child: this,
    );
  }
}