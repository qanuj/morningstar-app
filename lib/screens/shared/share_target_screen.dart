// lib/screens/shared/share_target_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/shared_content.dart';
import '../../models/link_metadata.dart';
import '../../providers/club_provider.dart';
import '../../services/share_handler_service.dart';
import '../../services/open_graph_service.dart';
import '../../services/message_refresh_service.dart';
import '../../services/message_storage_service.dart';
import '../../services/auth_service.dart';
import '../clubs/club_chat.dart';
import '../../widgets/svg_avatar.dart';
import '../../services/chat_api_service.dart';
import '../../models/club_message.dart';
import 'text_editor_screen.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isLoadingMetadata = false;
  bool _isSearchFocused = false;
  final Set<String> _selectedClubIds = <String>{};
  LinkMetadata? _linkMetadata;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkAuthenticationAndInit();

    // Listen to focus changes on search field
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  void _checkAuthenticationAndInit() {
    print('📤 ShareTargetScreen: Checking authentication status...');
    print('📤 AuthService.isLoggedIn: ${AuthService.isLoggedIn}');
    print('📤 AuthService.hasToken: ${AuthService.hasToken}');

    // Check if user is authenticated
    if (!AuthService.isLoggedIn) {
      print('⚠️ User not authenticated for sharing, redirecting to login');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to share content to your clubs'),
              duration: Duration(seconds: 3),
            ),
          );
          // Close the share screen and redirect to app (will show login)
          Navigator.of(context).pop();
        }
      });
      return;
    }

    print('✅ User is authenticated, proceeding with sharing flow');
    _initializeContent();

    // Load clubs if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clubProvider = Provider.of<ClubProvider>(context, listen: false);
      print(
        '📤 ClubProvider status - Clubs: ${clubProvider.clubs.length}, Loading: ${clubProvider.isLoading}',
      );

      if (clubProvider.clubs.isEmpty && !clubProvider.isLoading) {
        print('📤 Loading clubs for sharing...');
        clubProvider
            .loadClubs()
            .then((_) {
              print(
                '📤 Clubs loaded successfully: ${clubProvider.clubs.length} clubs',
              );
            })
            .catchError((e) {
              print('❌ Failed to load clubs for sharing: $e');
            });
      } else if (clubProvider.clubs.isNotEmpty) {
        print('📤 Clubs already loaded: ${clubProvider.clubs.length}');
      }
    });
  }

  void _initializeContent() async {
    try {
      print('📤 === ShareTargetScreen Debug Info ===');
      print('📤 Content Type: ${widget.sharedContent.type.name}');
      print('📤 Content URL: ${widget.sharedContent.url}');
      print('📤 Content Text: ${widget.sharedContent.text}');
      print('📤 Content Subject: ${widget.sharedContent.subject}');
      print('📤 Content Image Paths: ${widget.sharedContent.imagePaths}');
      print('📤 Content Metadata: ${widget.sharedContent.metadata}');
      print('📤 Has Images: ${widget.sharedContent.hasImages}');
      print('📤 Has Text: ${widget.sharedContent.hasText}');
      print('📤 Is Valid: ${widget.sharedContent.isValid}');
      print('📤 Display Text: ${widget.sharedContent.displayText}');
      print('📤 =====================================');

      // Pre-fill message with shared text if available
      if (widget.sharedContent.hasText) {
        _messageController.text = widget.sharedContent.text ?? '';
        print('📤 Pre-filled message with shared text');
      }

      // Extract link metadata if content is a URL
      if (widget.sharedContent.type == SharedContentType.url) {
        print('📤 Extracting metadata for URL content');
        await _extractLinkMetadata();
      }

      // If content is images, ensure files exist
      if (widget.sharedContent.type == SharedContentType.image ||
          widget.sharedContent.type == SharedContentType.multipleImages) {
        print('📤 Validating image files');
        final imagePaths = widget.sharedContent.imagePaths ?? [];
        print('📤 Image paths to validate: $imagePaths');
        final existingFiles = <String>[];

        for (final path in imagePaths) {
          try {
            final file = File(path);
            print('📤 Checking file: $path');
            print('📤 File exists: ${file.existsSync()}');
            if (file.existsSync()) {
              final fileSize = file.lengthSync();
              print('📤 File size: $fileSize bytes');
              existingFiles.add(path);
            } else {
              print('⚠️ Image file not found: $path');
            }
          } catch (e) {
            print('❌ Error checking image file $path: $e');
          }
        }

        if (existingFiles.isEmpty) {
          print('❌ No valid image files found');
          // Show error and pop if no valid image files
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No valid image files found to share.'),
                duration: Duration(seconds: 5),
              ),
            );
            Navigator.of(context).pop();
          }
          return;
        } else {
          print(
            '✅ Found ${existingFiles.length} valid image files: $existingFiles',
          );
        }
      }

      print('✅ Content initialization completed successfully');
    } catch (e) {
      print('❌ Error initializing shared content: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing shared content: $e')),
        );
      }
    }
  }

  Future<void> _extractLinkMetadata() async {
    if (!mounted) return;

    setState(() => _isLoadingMetadata = true);

    try {
      final url = widget.sharedContent.url ?? widget.sharedContent.text ?? '';
      print('📤 Extracting metadata for URL: $url');

      if (url.isNotEmpty && url.startsWith(RegExp(r'https?://'))) {
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
          print('✅ Link metadata extracted successfully');
        }
      } else {
        print('⚠️ Invalid or empty URL for metadata extraction');
      }
    } catch (e) {
      print('❌ Error extracting metadata: $e');
      // Continue without metadata instead of failing
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
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Safety check - if shared content is invalid, show error and close
    if (!widget.sharedContent.isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid shared content received')),
          );
          Navigator.of(context).pop();
        }
      });
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: GestureDetector(
        onTap: () {
          // Allow tapping outside search to unfocus
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.85,
          child: _buildDialogBody(),
        ),
      ),
    );
  }

  Widget _buildDialogBody() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
      child: Stack(
        children: [
          // Body content (behind overlays) - Only club selection
          Positioned.fill(
            child: Column(
              children: [
                // Top padding to account for header overlay
                const SizedBox(height: 70),

                // Club selection section (takes all available space)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildClubSelector(),
                  ),
                ),

                // Bottom padding to account for footer overlay
                if (_selectedClubIds.isNotEmpty)
                  const SizedBox(height: 80), // Account for footer height
              ],
            ),
          ),

          // Minimal header overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFE5E5E5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Left cancel button (only show when search is not focused)
                  if (!_isSearchFocused) ...[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 36),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode
                              ? const Color(0xFF9E9E9E)
                              : const Color(0xFF757575),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Clean search field
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search clubs...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? const Color(0xFF757575)
                                : const Color(0xFF9E9E9E),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDarkMode
                                ? const Color(0xFF757575)
                                : const Color(0xFF9E9E9E),
                            size: 20,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF212121),
                        ),
                      ),
                    ),
                  ),

                  // Right clear button (only show when search has text)
                  if (_isSearchFocused && _searchQuery.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 36),
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? const Color(0xFF9E9E9E)
                              : const Color(0xFF757575),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer overlay (on top, only when clubs selected)
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (url.isEmpty) {
      //return nothing
      return const SizedBox.shrink();
    }

    if (_isLoadingMetadata) {
      return Container(
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
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview (left column)
            if (_linkMetadata!.image != null &&
                _linkMetadata!.image!.isNotEmpty)
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.network(
                    _linkMetadata!.image!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.link, size: 24, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),

            // Content (right column)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  if (_linkMetadata!.title != null &&
                      _linkMetadata!.title!.isNotEmpty)
                    Text(
                      _linkMetadata!.title!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
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
                        fontSize: 13,
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
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 6),
                          child: Image.network(
                            _linkMetadata!.favicon!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.language, size: 14),
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.language, size: 14),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          Uri.decodeFull(_linkMetadata!.url),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
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
                  Uri.decodeFull(url),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF06aeef),
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(0)),
        child: ClipRRect(
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
        final isLoading = clubProvider.isLoading;

        print(
          '📤 ShareTargetScreen - Clubs: ${clubs.length}, Loading: $isLoading',
        );

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (clubs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFC107)),
            ),
            child: Column(
              children: [
                const Text(
                  'No clubs available. Join a club to share content.',
                  style: TextStyle(color: Color(0xFF6C757D)),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    clubProvider.loadClubs();
                  },
                  child: const Text('Retry Loading Clubs'),
                ),
              ],
            ),
          );
        }

        // Filter clubs based on search query
        final filteredClubs = clubs.where((membership) {
          final clubName = membership.club.name.toLowerCase();
          final clubDescription = (membership.club.description ?? '')
              .toLowerCase();
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
                  child: const Icon(
                    Icons.public,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: 'Everyone',
                subtitle: 'Share with all your contacts',
                isSelected: _selectedClubIds.contains('everyone'),
                onTap: () => _toggleClubSelection('everyone'),
              ),

            // Show filtered clubs
            if (filteredClubs.isNotEmpty) ...[
              // Header section with selection limit info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _searchQuery.isEmpty ? 'Your clubs' : 'Search results',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_searchQuery.isEmpty && _selectedClubIds.isNotEmpty)
                      Text(
                        'Selected ${_selectedClubIds.length}/3 clubs',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
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
                      Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onTap == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode
                      ? const Color(0xFF1E3A8A).withOpacity(0.2)
                      : const Color(0xFFF0F8FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF212121),
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? const Color(0xFF9E9E9E)
                                  : const Color(0xFF757575),
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
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2196F3)
                          : (isDarkMode
                                ? const Color(0xFF616161)
                                : const Color(0xFFBDBDBD)),
                      width: 1.5,
                    ),
                    color: isSelected
                        ? const Color(0xFF2196F3)
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDarkMode
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFE5E5E5),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Content preview section
            if (_buildContentPreview() != const SizedBox.shrink())
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildContentPreview(),
              ),

            // Clean divider (only if content preview exists)
            if (_buildContentPreview() != const SizedBox.shrink())
              Container(
                height: 0.5,
                color: isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE5E5E5),
              ),

            // Compact action area with badges and button
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom > 0 ? 12 : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Scrollable badges
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Everyone option
                            if (_selectedClubIds.contains('everyone'))
                              _buildScrollableBadge(
                                name: 'Everyone',
                                color: const Color(0xFF4CAF50),
                              ),

                            // Selected clubs
                            ...clubProvider.clubs
                                .where(
                                  (membership) => _selectedClubIds.contains(
                                    membership.club.id,
                                  ),
                                )
                                .map(
                                  (membership) => _buildScrollableBadge(
                                    name: membership.club.name,
                                    color: const Color(0xFF2196F3),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Clean action button
                  _buildActionButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableBadge({required String name, required Color color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 28,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? color.withOpacity(0.15) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? color.withOpacity(0.3) : color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          name,
          style: TextStyle(
            color: isDarkMode ? color.withOpacity(0.9) : color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    // Different button styles based on content type
    switch (widget.sharedContent.type) {
      case SharedContentType.url:
      case SharedContentType.image:
      case SharedContentType.multipleImages:
        // Send icon for URLs and media
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _isLoading ? null : _shareContent,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ),
        );
      case SharedContentType.text:
      default:
        // Next button for text
        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isLoading ? null : _shareContent,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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
          ),
        );
    }
  }

  void _showTextEditor() {
    // Navigate to text editor screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TextEditorScreen(
          selectedClubIds: _selectedClubIds,
          initialText: widget.sharedContent.text ?? '',
        ),
      ),
    );
  }

  Future<void> _sendToClubs() async {
    setState(() => _isLoading = true);

    try {
      // Check if "Everyone" is selected
      if (_selectedClubIds.contains('everyone')) {
        _navigateToClubsScreen();
        return;
      }

      // Send to each selected club
      for (final clubId in _selectedClubIds) {
        await _sendMessageToClub(clubId);
      }

      _navigateToClubsScreen();
    } catch (e) {
      // Silent error handling - no toast
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _sendMessageToClub(String clubId) async {
    try {
      print('📤 _sendMessageToClub called for clubId: $clubId');
      print('📤 SharedContent type: ${widget.sharedContent.type}');

      Map<String, dynamic> messageData;

      switch (widget.sharedContent.type) {
        case SharedContentType.url:
          // Ensure we have a valid URL - prioritize the actual URL over metadata
          final actualUrl =
              widget.sharedContent.url ?? widget.sharedContent.text ?? '';
          print('🔗 Actual URL to send: $actualUrl');

          // Validate that we have a proper URL
          if (actualUrl.isEmpty ||
              !actualUrl.startsWith(RegExp(r'https?://'))) {
            print('❌ Invalid URL for sharing: $actualUrl');
            return false;
          }

          dynamic contentJson;
          contentJson = {
            'type': 'link',
            'url': actualUrl, // Use the actual URL directly
            'body': _messageController.text.trim().isEmpty
                ? actualUrl // Use URL as body if no custom message
                : _messageController.text.trim(),
            if (_linkMetadata?.title != null) 'title': _linkMetadata?.title,
            if (_linkMetadata?.description != null)
              'description': _linkMetadata?.description,
            if (_linkMetadata?.siteName != null)
              'siteName': _linkMetadata?.siteName,
            if (_linkMetadata?.favicon != null)
              'favicon': _linkMetadata?.favicon,
            if (_linkMetadata?.image != null) 'images': [_linkMetadata?.image!],
          };
          messageData = {
            'content': contentJson,
            'type': 'link',
            'metadata': {'forwarded': true},
            if (_linkMetadata != null) 'linkMeta': [_linkMetadata!.toJson()],
          };
          break;

        case SharedContentType.text:
          messageData = {
            'content': {
              'type': 'text',
              'body': widget.sharedContent.text ?? '',
            },
            'type': 'text',
            'metadata': {'forwarded': true},
          };
          break;

        case SharedContentType.image:
        case SharedContentType.multipleImages:
          // Upload all images first and get their URLs
          final imagePaths = widget.sharedContent.imagePaths ?? [];
          final uploadedImageUrls = <String>[];

          // Upload all images sequentially to ensure they're all processed
          for (final imagePath in imagePaths) {
            try {
              // Create PlatformFile from image path
              final file = File(imagePath);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                final fileName = imagePath.split('/').last;
                final platformFile = PlatformFile(
                  name: fileName,
                  size: bytes.length,
                  bytes: bytes,
                  path: imagePath,
                );

                // Upload the file and wait for completion
                final uploadedUrl = await ChatApiService.uploadFile(
                  platformFile,
                );
                if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                  uploadedImageUrls.add(uploadedUrl);
                  print('✅ Image uploaded successfully: $uploadedUrl');
                } else {
                  print('❌ Failed to upload image: $imagePath');
                }
              } else {
                print('❌ Image file not found: $imagePath');
              }
            } catch (e) {
              print('❌ Error uploading image $imagePath: $e');
              // Continue with other images even if one fails
            }
          }

          // Only proceed if at least one image was uploaded successfully
          if (uploadedImageUrls.isEmpty) {
            print('❌ No images were uploaded successfully');
            return false;
          }

          print(
            '📤 Creating message with ${uploadedImageUrls.length} uploaded images',
          );

          // Create message with uploaded image URLs
          messageData = {
            'content': {
              'type': 'text',
              'body': _messageController.text.trim().isEmpty
                  ? ' '
                  : _messageController.text.trim(),
              'images': uploadedImageUrls,
            },
            'type': 'text',
            'metadata': {'forwarded': true},
          };
          break;

        case SharedContentType.unknown:
          messageData = {
            'content': {
              'type': 'text',
              'body': widget.sharedContent.displayText,
            },
            'type': 'text',
            'metadata': {'forwarded': true},
          };
          break;
      }

      print('📤 Final messageData: $messageData');
      print('🔧 ShareTarget: About to call ChatApiService.sendMessage');
      print('🔧 ShareTarget: ClubId: $clubId');

      final response = await ChatApiService.sendMessage(clubId, messageData);

      print('🔧 ShareTarget: ChatApiService.sendMessage completed');
      print('🔧 ShareTarget: Response: $response');
      print('🔧 ShareTarget: Success: ${response != null}');

      // If message was sent successfully, add to local cache
      if (response != null) {
        try {
          print('💾 ShareTarget: Adding message to local cache...');

          // Create ClubMessage from API response
          final clubMessage = ClubMessage.fromJson(response);

          // Add message to local cache
          await MessageStorageService.addMessage(clubId, clubMessage);

          print('✅ ShareTarget: Message added to local cache successfully');
        } catch (e) {
          print('❌ ShareTarget: Error adding message to cache: $e');
          // Don't fail the entire operation if caching fails
        }
      }

      return response != null;
    } catch (e) {
      print('Error sending message to club $clubId: $e');
      return false;
    }
  }

  void _navigateToClubsScreen() {
    // Navigate to clubs screen (main navigation)
    Navigator.of(context).popUntil((route) => route.isFirst);
    // The main app should have bottom navigation to clubs tab
  }

  void _shareContent() {
    if (_selectedClubIds.isEmpty) return;

    // Handle different content types differently
    switch (widget.sharedContent.type) {
      case SharedContentType.url:
        // For URLs, send directly to all selected clubs
        _sendToClubs();
        break;
      case SharedContentType.text:
        // For text, show editor screen
        _showTextEditor();
        break;
      case SharedContentType.image:
      case SharedContentType.multipleImages:
        // For media, send directly with image preview
        _sendToClubs();
        break;
      default:
        _showShareConfirmation();
    }
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
        // Handle "Everyone" sharing - silent navigation
        Navigator.of(context).pop();
      } else if (_selectedClubIds.length == 1) {
        // If only one club is selected, send the message first then navigate to chat
        final clubId = _selectedClubIds.first;
        final success = await _sendMessageToClub(clubId);

        if (success) {
          // Trigger refresh for the successful club
          MessageRefreshService().triggerRefresh(clubId);

          final selectedClub = clubProvider.clubs
              .firstWhere((membership) => membership.club.id == clubId)
              .club;

          // Navigate to chat after successful message posting
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ClubChatScreen(
                  club: selectedClub,
                  // Don't pass sharedContent since message is already posted
                  initialMessage: null,
                ),
              ),
            );
          }
        } else {
          // Show error feedback for single club failure
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Failed to send message. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      } else {
        // For multiple clubs, send to each club via API
        int successCount = 0;
        List<String> successfulClubs = [];
        for (final clubId in _selectedClubIds) {
          final success = await _sendMessageToClub(clubId);
          if (success) {
            successCount++;
            successfulClubs.add(clubId);
          }
        }

        // Trigger refresh for successful clubs
        if (successfulClubs.isNotEmpty) {
          MessageRefreshService().triggerRefreshForClubs(successfulClubs);
        }

        if (mounted) {
          // Show success feedback
          if (successCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ Message sent to $successCount club${successCount > 1 ? 's' : ''}! Messages are now visible in chat.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          }
          Navigator.of(context).pop();
        }
      }

      // Clear shared content after processing
      ShareHandlerService().clearSharedContent();
    } catch (e) {
      // Silent error handling - no toast
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
