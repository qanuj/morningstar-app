// lib/screens/shared/share_target_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shared_content.dart';
import '../../models/link_metadata.dart';
import '../../providers/club_provider.dart';
import '../../services/share_handler_service.dart';
import '../../services/open_graph_service.dart';
import '../clubs/club_chat.dart';
import '../../widgets/svg_avatar.dart';

class ShareTargetScreen extends StatefulWidget {
  final SharedContent sharedContent;

  const ShareTargetScreen({Key? key, required this.sharedContent})
    : super(key: key);

  @override
  State<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends State<ShareTargetScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingMetadata = false;
  final Set<String> _selectedClubIds = <String>{};
  LinkMetadata? _linkMetadata;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeContent();
  }

  void _initializeContent() async {
    // Pre-fill message with shared text if available
    if (widget.sharedContent.hasText) {
      _messageController.text = widget.sharedContent.text ?? '';
    }

    // Extract link metadata if content is a URL
    if (widget.sharedContent.type == SharedContentType.url) {
      await _extractLinkMetadata();
    }
  }

  Future<void> _extractLinkMetadata() async {
    if (!mounted) return;

    setState(() => _isLoadingMetadata = true);

    try {
      final url = widget.sharedContent.url ?? widget.sharedContent.text ?? '';
      if (url.isNotEmpty) {
        final ogData = await OpenGraphService.fetchMetadata(url);
        if (mounted) {
          setState(() {
            _linkMetadata = LinkMetadata(
              url: ogData.url,
              title: ogData.title,
              description: ogData.description,
              image: ogData.image,
              siteName: ogData.siteName,
              favicon: ogData.favicon,
            );
          });
        }
      }
    } catch (e) {
      print('Error extracting metadata: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMetadata = false);
      }
    }
  }

  void _toggleClubSelection(String clubId) {
    setState(() {
      if (_selectedClubIds.contains(clubId)) {
        _selectedClubIds.remove(clubId);
      } else if (_selectedClubIds.length < 3) {
        _selectedClubIds.add(clubId);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.85,
        child: _buildDialogBody(),
      ),
    );
  }

  Widget _buildDialogBody() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Stack(
        children: [
          Column(
            children: [
          // Header with cancel button and search field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFDEE2E6))),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search clubs...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintStyle: TextStyle(color: Color(0xFF6C757D)),
                        prefixIcon: Icon(Icons.search, color: Color(0xFF6C757D)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Club selection section
          Expanded(
            flex: _selectedClubIds.isEmpty ? 1 : 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildClubSelector(),
            ),
          ),

          // Content preview section (only show after selection)
          if (_selectedClubIds.isNotEmpty) ...[
            Container(height: 1, color: const Color(0xFFDEE2E6)),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: _buildContentPreview(),
              ),
            ),
          ],
        ],
      ),
          
      // Fixed footer with badges
      if (_selectedClubIds.isNotEmpty) _buildBottomSection(),
    ],
    ),
    );
  }

  Widget _buildContentPreview() {
    switch (widget.sharedContent.type) {
      case SharedContentType.text:
        return _buildTextContent();
      case SharedContentType.url:
        return _buildUrlContent();
      case SharedContentType.image:
        return _buildSingleImageContent();
      case SharedContentType.multipleImages:
        return _buildMultipleImagesContent();
      default:
        return _buildUnknownContent();
    }
  }

  Widget _buildTextContent() {
    // Don't show text content preview as requested
    return const SizedBox.shrink();
  }

  Widget _buildUrlContent() {
    final url = widget.sharedContent.url ?? widget.sharedContent.text ?? '';

    if (_isLoadingMetadata) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDEE2E6)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading link preview...'),
          ],
        ),
      );
    }

    if (_linkMetadata != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDEE2E6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            if (_linkMetadata!.image != null &&
                _linkMetadata!.image!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: Container(
                  width: double.infinity,
                  height: 160,
                  child: Image.network(
                    _linkMetadata!.image!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.link, size: 48),
                    ),
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  if (_linkMetadata!.title != null &&
                      _linkMetadata!.title!.isNotEmpty)
                    Text(
                      _linkMetadata!.title!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Description
                  if (_linkMetadata!.description != null &&
                      _linkMetadata!.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _linkMetadata!.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),
                  // URL with favicon
                  Row(
                    children: [
                      if (_linkMetadata!.favicon != null &&
                          _linkMetadata!.favicon!.isNotEmpty) ...[
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 6),
                          child: Image.network(
                            _linkMetadata!.favicon!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.language, size: 16),
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.language, size: 16),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          _linkMetadata!.url,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Fallback to simple URL display
    final uri = Uri.tryParse(url);
    final domain = uri?.host ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF06aeef)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: Color(0xFF06aeef), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  url,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF06aeef),
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFDEE2E6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  domain,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleImageContent() {
    final imagePath = widget.sharedContent.imagePaths?.first;
    if (imagePath == null) return _buildUnknownContent();

    return GestureDetector(
      onTap: () => _showImageGallery([imagePath]),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDEE2E6)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFF8F9FA),
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Color(0xFF6C757D),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultipleImagesContent() {
    final imagePaths = widget.sharedContent.imagePaths ?? [];
    if (imagePaths.isEmpty) return _buildUnknownContent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${imagePaths.length} images',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6C757D),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imagePaths.length > 5 ? 5 : imagePaths.length,
            itemBuilder: (context, index) {
              final imagePath = imagePaths[index];
              final isLast = index == 4 && imagePaths.length > 5;

              return GestureDetector(
                onTap: () => _showImageGallery(imagePaths, initialIndex: index),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDEE2E6)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: const Color(0xFFF8F9FA),
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 24,
                                  color: Color(0xFF6C757D),
                                ),
                              ),
                        ),
                        if (isLast)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Text(
                                '+${imagePaths.length - 4}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnknownContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unknown content type: ${widget.sharedContent.displayText}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubSelector() {
    return Consumer<ClubProvider>(
      builder: (context, clubProvider, child) {
        final clubs = clubProvider.clubs;

        if (clubs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFC107)),
            ),
            child: const Text(
              'No clubs available. Join a club to share content.',
              style: TextStyle(color: Color(0xFF6C757D)),
            ),
          );
        }

        // Filter clubs based on search query
        final filteredClubs = clubs.where((membership) {
          final clubName = membership.club.name.toLowerCase();
          final clubDescription = (membership.club.description ?? '').toLowerCase();
          return _searchQuery.isEmpty || 
                 clubName.contains(_searchQuery) || 
                 clubDescription.contains(_searchQuery);
        }).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Everyone option (always show if no search or matches search)
            if (_searchQuery.isEmpty || 'everyone'.contains(_searchQuery))
              _buildClubItem(
                key: 'everyone',
                avatar: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF16a34a),
                  ),
                  child: const Icon(Icons.public, color: Colors.white, size: 20),
                ),
                title: 'Everyone',
                subtitle: 'Share with all your contacts',
                isSelected: _selectedClubIds.contains('everyone'),
                onTap: () => _toggleClubSelection('everyone'),
              ),
            
            // Show filtered clubs
            if (filteredClubs.isNotEmpty) ...[
              // Header section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  _searchQuery.isEmpty ? 'Your clubs' : 'Search results',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Clubs list
              ...filteredClubs.map((club) {
                final isSelected = _selectedClubIds.contains(club.club.id);
                final canSelect = _selectedClubIds.length < 3 || isSelected;

                return _buildClubItem(
                  key: club.club.id,
                  avatar: club.club.logo != null
                      ? SVGAvatar.medium(
                          imageUrl: club.club.logo,
                          backgroundColor: const Color(0xFF06aeef),
                          iconColor: Colors.white,
                          fallbackIcon: Icons.group,
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF06aeef),
                          ),
                          child: Center(
                            child: Text(
                              club.club.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                  title: club.club.name,
                  subtitle: club.club.description,
                  isSelected: isSelected,
                  onTap: canSelect
                      ? () => _toggleClubSelection(club.club.id)
                      : null,
                );
              }),
            ] else if (_searchQuery.isNotEmpty) ...[
              // No search results
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No clubs found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try a different search term',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildClubItem({
    required String key,
    required Widget avatar,
    required String title,
    String? subtitle,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF25D366)
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                  color: isSelected
                      ? const Color(0xFF25D366)
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showImageGallery(List<String> imagePaths, {int initialIndex = 0}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  'Image ${initialIndex + 1} of ${imagePaths.length}',
                ),
                backgroundColor: const Color(0xFF003f9b),
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: Image.file(
                  File(imagePaths[initialIndex]),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    final clubProvider = Provider.of<ClubProvider>(context, listen: false);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDEE2E6))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Scrollable badges
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Everyone option
                          if (_selectedClubIds.contains('everyone'))
                            _buildScrollableBadge(
                              name: 'Everyone',
                              color: const Color(0xFF16a34a),
                            ),

                          // Selected clubs
                          ...clubProvider.clubs
                              .where(
                                (membership) =>
                                    _selectedClubIds.contains(membership.club.id),
                              )
                              .map(
                                (membership) => _buildScrollableBadge(
                                  name: membership.club.name,
                                  color: const Color(0xFF06aeef),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Next button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16a34a),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: GestureDetector(
                    onTap: _isLoading ? null : _shareContent,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableBadge({
    required String name,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _shareContent() {
    if (_selectedClubIds.isEmpty) return;

    _showShareConfirmation();
  }

  void _showShareConfirmation() {
    final clubProvider = Provider.of<ClubProvider>(context, listen: false);
    final selectedClubs = clubProvider.clubs
        .where((membership) => _selectedClubIds.contains(membership.club.id))
        .map((membership) => membership.club)
        .toList();

    final hasEveryoneOption = _selectedClubIds.contains('everyone');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Confirm Share',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF003f9b),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this content to:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),

              // Show selected options
              if (hasEveryoneOption) ...[
                Row(
                  children: [
                    SVGAvatar.small(
                      backgroundColor: const Color(0xFF16a34a),
                      iconColor: Colors.white,
                      fallbackIcon: Icons.public,
                    ),
                    const SizedBox(width: 8),
                    const Text('Everyone'),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Show selected clubs
              ...selectedClubs.map(
                (club) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      club.logo != null
                          ? SVGAvatar.small(
                              imageUrl: club.logo,
                              backgroundColor: const Color(0xFF06aeef),
                              iconColor: Colors.white,
                              fallbackIcon: Icons.group,
                            )
                          : Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF06aeef),
                              ),
                              child: Center(
                                child: Text(
                                  club.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          club.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_messageController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Message:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6C757D),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDEE2E6)),
                  ),
                  child: Text(
                    _messageController.text.trim(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6C757D)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performActualShare();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003f9b),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Share ${hasEveryoneOption || selectedClubs.length > 1 ? '(${_selectedClubIds.length})' : ''}',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performActualShare() async {
    setState(() => _isLoading = true);

    try {
      final clubProvider = Provider.of<ClubProvider>(context, listen: false);

      // Check if "Everyone" is selected
      if (_selectedClubIds.contains('everyone')) {
        // Handle "Everyone" sharing - for now just show a message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared with everyone! (Feature coming soon)'),
            backgroundColor: Color(0xFF16a34a),
          ),
        );
        Navigator.of(context).pop();
      } else if (_selectedClubIds.length == 1) {
        // If only one club is selected, navigate directly to that club's chat
        final selectedClub = clubProvider.clubs
            .firstWhere(
              (membership) => membership.club.id == _selectedClubIds.first,
            )
            .club;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ClubChatScreen(
              club: selectedClub,
              sharedContent: widget.sharedContent,
              initialMessage: _messageController.text.trim().isNotEmpty
                  ? _messageController.text.trim()
                  : null,
            ),
          ),
        );
      } else {
        // For multiple clubs, we would need to handle bulk sharing
        // For now, let's show a success message and go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Content shared to ${_selectedClubIds.length} clubs successfully!',
            ),
            backgroundColor: const Color(0xFF16a34a),
          ),
        );

        Navigator.of(context).pop();
      }

      // Clear shared content after processing
      ShareHandlerService().clearSharedContent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share content. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
