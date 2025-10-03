import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'quick_reaction_picker.dart';

/// Inline reaction picker that appears above messages on long press
class InlineReactionPicker extends StatefulWidget {
  final Function(String emoji) onReactionSelected;
  final VoidCallback onDismiss;
  final Offset position;
  final bool isOwnMessage;

  const InlineReactionPicker({
    super.key,
    required this.onReactionSelected,
    required this.onDismiss,
    required this.position,
    this.isOwnMessage = false,
  });

  @override
  State<InlineReactionPicker> createState() => _InlineReactionPickerState();
}

/// Enhanced inline message options that appears on long press with blur background
class InlineMessageOptions extends StatefulWidget {
  final Function(String emoji) onReactionSelected;
  final VoidCallback onDismiss;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onSelectMessage;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback onStar;
  final VoidCallback onDelete;
  final VoidCallback onMore;
  final VoidCallback onInfo;
  final Offset messagePosition;
  final Size messageSize;
  final bool isOwnMessage;
  final bool canDelete;
  final bool isDeleted;
  final Widget? messageWidget;
  final String? messageContent;

  const InlineMessageOptions({
    super.key,
    required this.onReactionSelected,
    required this.onDismiss,
    required this.onReply,
    required this.onForward,
    required this.onSelectMessage,
    required this.onCopy,
    required this.onPin,
    required this.onStar,
    required this.onDelete,
    required this.onMore,
    required this.onInfo,
    required this.messagePosition,
    required this.messageSize,
    this.isOwnMessage = false,
    this.canDelete = false,
    this.isDeleted = false,
    this.messageWidget,
    this.messageContent,
  });

  @override
  State<InlineMessageOptions> createState() => _InlineMessageOptionsState();
}

class _InlineReactionPickerState extends State<InlineReactionPicker>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectReaction(String emoji) {
    HapticFeedback.lightImpact();
    widget.onReactionSelected(emoji);
    _dismiss();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    //bottom quick reactions bar
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;

    // Calculate safe position accounting for keyboard and system navigation
    final safeBottom =
        bottomInset +
        bottomPadding +
        40; // Extra 40px margin for better clearance
    final adjustedTop = widget.position.dy - safeBottom;

    return Positioned(
      left: widget.position.dx,
      top: adjustedTop,
      child: QuickReactionPicker(onReactionSelected: _selectReaction),
    );
  }
}

/// Overlay widget to handle inline reaction picker
class InlineReactionOverlay extends StatefulWidget {
  final Widget child;
  final Function(String emoji) onReactionSelected;
  final Offset messagePosition;
  final bool isOwnMessage;

  const InlineReactionOverlay({
    super.key,
    required this.child,
    required this.onReactionSelected,
    required this.messagePosition,
    this.isOwnMessage = false,
  });

  @override
  State<InlineReactionOverlay> createState() => _InlineReactionOverlayState();

  /// Public static method to dismiss all active inline reaction pickers
  static void dismissAllActivePickers() {
    _InlineReactionOverlayState.dismissAllActivePickers();
  }
}

class _InlineReactionOverlayState extends State<InlineReactionOverlay> {
  OverlayEntry? _overlayEntry;
  bool _isPickerVisible = false;

  // Static list to track all active inline reaction pickers
  static final List<_InlineReactionOverlayState> _activePickers = [];

  // Static method to dismiss all active inline reaction pickers
  static void dismissAllActivePickers() {
    final List<_InlineReactionOverlayState> pickersCopy = List.from(_activePickers);
    for (final picker in pickersCopy) {
      picker._dismissPicker();
    }
  }

  void showReactionPicker() {
    if (_isPickerVisible) return;

    _isPickerVisible = true;
    _activePickers.add(this);
    HapticFeedback.mediumImpact();

    // Calculate position above the message
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    // Position picker above the message, centered
    final pickerPosition = Offset(
      position.dx +
          (size.width / 2) -
          140, // Center horizontally (picker is ~280px wide)
      position.dy - 60, // Position above message
    );

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible barrier to dismiss picker when tapping outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissPicker,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Reaction picker
          InlineReactionPicker(
            position: pickerPosition,
            isOwnMessage: widget.isOwnMessage,
            onReactionSelected: (emoji) {
              widget.onReactionSelected(emoji);
              _dismissPicker();
            },
            onDismiss: _dismissPicker,
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _dismissPicker() {
    if (!_isPickerVisible) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    _isPickerVisible = false;
    _activePickers.remove(this);
  }

  @override
  void dispose() {
    _dismissPicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: showReactionPicker,
      child: widget.child,
    );
  }
}

/// Enhanced message options state with centered message and blur background
class _InlineMessageOptionsState extends State<InlineMessageOptions>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _blurAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectReaction(String emoji) {
    HapticFeedback.lightImpact();
    widget.onReactionSelected(emoji);
    _dismiss();
  }

  void _handleAction(VoidCallback action) {
    HapticFeedback.lightImpact();
    action();
    _dismiss();
  }

  void _handleShare() {
    final content = widget.messageContent ?? 'Shared from Duggy app';
    Share.share(content, subject: 'Message from Duggy');
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Calculate available screen space minus safe area

    final maxWidth = (screenSize.width - 32).clamp(
      250.0,
      350.0,
    ); // Responsive width with margins

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Stack(
              children: [
                // Blurred background - full screen
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      color: Colors.black.withOpacity(
                        0.3 * _opacityAnimation.value,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: _blurAnimation.value,
                          sigmaY: _blurAnimation.value,
                        ),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                ),

                // Positioned content with proper bounds checking
                Positioned.fill(
                  child: SafeArea(
                    bottom: true, // Ensure SafeArea respects bottom insets
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16.0,
                        16.0,
                        16.0,
                        32.0,
                      ), // Extra bottom padding
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Reaction picker above message - only show for non-deleted messages
                          if (!widget.isDeleted)
                            Transform.scale(
                              scale: _scaleAnimation.value,
                              child: QuickReactionPicker(
                                onReactionSelected: _selectReaction,
                              ),
                            ),
                          const SizedBox(height: 10),
                          // The actual message in center
                          Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Opacity(
                              opacity: _opacityAnimation.value,
                              child: Container(
                                width: maxWidth,
                                child:
                                    widget.messageWidget ??
                                    Container(
                                      width: maxWidth,
                                      height: widget.messageSize.height.clamp(
                                        50.0,
                                        150.0,
                                      ), // Limit message height
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF2a2f32)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Selected Message',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          ),

                          // Options menu below message
                          Flexible(
                            child: Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Opacity(
                                opacity: _opacityAnimation.value,
                                child: Container(
                                  width:
                                      maxWidth -
                                      100, // Reduced constraint for better mobile fit
                                  margin: const EdgeInsets.only(
                                    top: 16,
                                    bottom: 16,
                                  ), // Add bottom margin
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF2a2f32)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: _buildMainOptions(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildMainOptions() {
    // For deleted messages, only show delete option to clean up the line
    if (widget.isDeleted) {
      return [
        if (widget.canDelete)
          _buildOptionTile(
            icon: Icons.delete_outline,
            title: 'Delete',
            onTap: () => _handleAction(widget.onDelete),
            isDestructive: true,
          ),
      ];
    }

    // For normal messages, show all options
    return [
      if (widget.isOwnMessage)
        _buildOptionTile(
          icon: Icons.info_outline,
          title: 'Info',
          onTap: () => _handleAction(widget.onInfo),
        ),

      _buildOptionTile(
        icon: Icons.reply,
        title: 'Reply',
        onTap: () => _handleAction(widget.onReply),
      ),
      _buildOptionTile(
        icon: Icons.copy,
        title: 'Copy',
        onTap: () => _handleAction(widget.onCopy),
      ),
      _buildOptionTile(
        icon: Icons.star_outline,
        title: 'Star',
        onTap: () => _handleAction(widget.onStar),
      ),
      _buildOptionTile(
        icon: Icons.push_pin_outlined,
        title: 'Pin',
        onTap: () => _handleAction(widget.onPin),
      ),
      _buildOptionTile(
        icon: Icons.share,
        title: 'Share',
        onTap: () => _handleAction(_handleShare),
      ),
      if (widget.canDelete)
        _buildOptionTile(
          icon: Icons.delete_outline,
          title: 'Delete',
          onTap: () => _handleAction(widget.onDelete),
          isDestructive: true,
        ),
    ];
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive
                      ? Colors.red
                      : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
              const Spacer(), // This creates the white space between text and icon
              Icon(
                icon,
                size: 20,
                color: isDestructive
                    ? Colors.red
                    : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
