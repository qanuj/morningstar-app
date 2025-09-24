import 'package:flutter/material.dart';
import 'dart:math';
import '../models/mention.dart';
import '../widgets/svg_avatar.dart';

/// Overlay widget that shows mention suggestions above the keyboard
///
/// This widget displays a list of club members that can be mentioned
/// when the user types @ in a message. It's positioned above the keyboard
/// and provides smooth animations for showing/hiding.
class MentionSuggestionOverlay extends StatefulWidget {
  final List<Mention> suggestions;
  final Function(Mention) onMentionSelected;
  final Function()? onDismiss;
  final String currentQuery;
  final bool isLoading;

  const MentionSuggestionOverlay({
    super.key,
    required this.suggestions,
    required this.onMentionSelected,
    this.onDismiss,
    this.currentQuery = '',
    this.isLoading = false,
  });

  @override
  State<MentionSuggestionOverlay> createState() => _MentionSuggestionOverlayState();
}

class _MentionSuggestionOverlayState extends State<MentionSuggestionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0), // Start from fully below
      end: Offset.zero, // Slide to normal position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic, // Smoother drawer-like animation
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectMention(Mention mention) {
    print('🎯 _selectMention called for: ${mention.name}');
    widget.onMentionSelected(mention);
  }

  /// Generate a consistent color for avatar based on name
  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF6C5CE7), // Purple
      const Color(0xFFA29BFE), // Light purple
      const Color(0xFF74B9FF), // Blue
      const Color(0xFF0984E3), // Dark blue
      const Color(0xFF00CEC9), // Cyan
      const Color(0xFF55EFC4), // Light green
      const Color(0xFF00B894), // Green
      const Color(0xFFFD79A8), // Pink
      const Color(0xFFE84393), // Dark pink
      const Color(0xFFE17055), // Orange
      const Color(0xFFFD79A8), // Light orange
      const Color(0xFF6C5CE7), // Purple variant
    ];

    // Use name hash to get consistent color
    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }

  Widget _buildLoadingState() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Searching members...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.search_off,
            color: Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            widget.currentQuery.isEmpty
                ? 'Type a name to mention someone'
                : 'No members found',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    Color textColor;

    switch (role) {
      case 'OWNER':
        badgeColor = Colors.purple[100]!;
        textColor = Colors.purple[800]!;
        break;
      case 'ADMIN':
        badgeColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      default:
        badgeColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role.toLowerCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildMentionItem(Mention mention) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('🎯 InkWell tapped for: ${mention.name}');
          _selectMention(mention);
        },
        borderRadius: BorderRadius.circular(8), // Add visual feedback
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // More compact padding
          child: Row(
            children: [
              // SVG Avatar with fallback
              SVGAvatar.small(
                imageUrl: mention.profilePicture,
                backgroundColor: _getAvatarColor(mention.name),
                iconColor: Colors.white,
                fallbackIcon: Icons.person,
              ),
              const SizedBox(width: 12),

              // Member details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mention.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mention.role.toLowerCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
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

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 16, // Increased elevation to appear above other content
          borderRadius: BorderRadius.circular(12), // Rounded on all sides
          child: GestureDetector(
            // Absorb all tap events on the overlay
            onTap: () {
              print('🎯 Mention overlay area tapped - preventing passthrough');
            },
            child: Container(
              height: 200, // Fixed height for drawer-like behavior
              constraints: const BoxConstraints(
                minHeight: 100,
                maxHeight: 300, // Allow for larger list
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12), // Rounded on all sides
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Drawer Handle and Header
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drawer handle
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.alternate_email,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.currentQuery.isNotEmpty
                                  ? 'Mentioning "${widget.currentQuery}"'
                                  : 'Mention someone',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          if (widget.onDismiss != null)
                            GestureDetector(
                              onTap: widget.onDismiss,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Content - Scrollable drawer area
                Expanded(
                  child: widget.isLoading
                      ? _buildLoadingState()
                      : widget.suggestions.isEmpty
                          ? _buildEmptyState()
                          : Scrollbar(
                              thumbVisibility: true, // Always show scrollbar
                              child: ListView.builder(
                                shrinkWrap: false, // Allow full scrolling
                                physics: const BouncingScrollPhysics(),
                                itemCount: widget.suggestions.length, // Show all suggestions
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemBuilder: (context, index) {
                                  return _buildMentionItem(widget.suggestions[index]);
                                },
                              ),
                            ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget to show mention suggestions in a positioned overlay
class PositionedMentionOverlay extends StatelessWidget {
  final Widget child;
  final List<Mention> suggestions;
  final Function(Mention) onMentionSelected;
  final Function()? onDismiss;
  final String currentQuery;
  final bool isLoading;
  final bool show;

  const PositionedMentionOverlay({
    super.key,
    required this.child,
    required this.suggestions,
    required this.onMentionSelected,
    this.onDismiss,
    this.currentQuery = '',
    this.isLoading = false,
    this.show = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // Allow overflow outside bounds
      children: [
        child,
        if (show)
          Positioned(
            bottom: 50, // Even closer to input field for drawer effect
            left: 4,
            right: 4,
            child: GestureDetector(
              // Absorb all gestures to prevent passthrough
              onTap: () {
                print('🎯 Overlay background tapped - preventing passthrough');
              },
              child: Material(
                type: MaterialType.card,
                elevation: 20, // Higher elevation to ensure it's on top
                shadowColor: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                child: MentionSuggestionOverlay(
                  suggestions: suggestions,
                  onMentionSelected: onMentionSelected,
                  onDismiss: onDismiss,
                  currentQuery: currentQuery,
                  isLoading: isLoading,
                ),
              ),
            ),
          ),
      ],
    );
  }
}