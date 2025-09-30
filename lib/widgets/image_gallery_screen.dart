import 'package:duggy/models/club.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/club_message.dart';
import '../models/media_item.dart';
import '../services/media_storage_service.dart';
import '../services/media_gallery_service.dart';
import 'svg_avatar.dart';
import 'club_logo_widget.dart';
import 'cached_media_image.dart';
import 'video_player_widget.dart';

class MediaGalleryScreen extends StatefulWidget {
  final List<MediaReference> mediaIndex;
  final int initialMediaIndex;
  final String initialMediaUrl;
  final Club club;

  const MediaGalleryScreen({
    super.key,
    required this.mediaIndex,
    required this.initialMediaIndex,
    required this.initialMediaUrl,
    required this.club,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late List<MediaReference> _mediaIndex;
  int _currentIndex = 0;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _initializeMediaIndex();
    _findInitialIndex();
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();

    // After the first frame, center the initial thumbnail
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mediaIndex.length > 1) {
        _centerThumbnail(_currentIndex);
      }
    });
  }

  void _initializeMediaIndex() {
    // Use the provided media index directly (already sorted)
    _mediaIndex = widget.mediaIndex;

    print(
      '📱 MediaGallery: Using ${_mediaIndex.length} media items from index',
    );
  }

  void _findInitialIndex() {
    // Find the index of the initially tapped media
    _currentIndex = MediaGalleryService.findMediaIndex(
      _mediaIndex,
      widget.initialMediaUrl
    );

    print(
      '📱 MediaGallery: Initial index set to $_currentIndex for ${widget.initialMediaUrl}',
    );
  }

  void _toggleAppBarVisibility() {
    setState(() {
      _showAppBar = !_showAppBar;
    });

    // When showing the app bar again, center the current thumbnail
    if (_showAppBar && _mediaIndex.length > 1) {
      // Add a small delay to ensure the ListView is built before scrolling
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerThumbnail(_currentIndex);
      });
    }
  }

  void _centerThumbnail(int index) {
    if (!_thumbnailScrollController.hasClients) return;

    // Calculate the position to center the selected thumbnail
    const double thumbnailWidth = 68.0; // 60 width + 8 margin
    const double padding = 16.0; // horizontal padding
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the target scroll position to center the thumbnail
    final targetPosition = (index * thumbnailWidth) - (screenWidth / 2) + (thumbnailWidth / 2) + padding;

    // Clamp the position to valid scroll bounds
    final maxScrollExtent = _thumbnailScrollController.position.maxScrollExtent;
    final minScrollExtent = _thumbnailScrollController.position.minScrollExtent;
    final clampedPosition = targetPosition.clamp(minScrollExtent, maxScrollExtent);

    _thumbnailScrollController.animateTo(
      clampedPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $ampm';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  Widget _buildMediaViewer(MediaReference mediaRef) {
    if (mediaRef.isVideo) {
      return _buildVideoViewer(mediaRef);
    } else {
      return _buildImageViewer(mediaRef);
    }
  }

  Widget _buildImageViewer(MediaReference mediaRef) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      child: Center(
        child: CachedMediaImage(
          imageUrl: mediaRef.url,
          fit: BoxFit.contain, // Maintain aspect ratio, fit within screen
          errorWidget: Container(
            color: Colors.grey[800],
            child: Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
          placeholder: Container(
            color: Colors.grey[900],
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoViewer(MediaReference mediaRef) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8, // Leave space for controls
              maxWidth: MediaQuery.of(context).size.width,
            ),
            child: CachedVideoPlayerWidget(
              videoUrl: mediaRef.url,
              autoPlay: false, // Don't autoplay in gallery
              showControls: true,
              borderRadius: 0, // No border radius in fullscreen
            ),
          ),
        ),
      ),
    );
  }


  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildThumbnailForStrip(MediaReference mediaRef) {
    if (mediaRef.isVideo) {
      // For videos, show thumbnail if available
      if (mediaRef.hasThumbnail) {
        final thumbnailSource = mediaRef.bestThumbnail!;

        if (thumbnailSource.startsWith('http')) {
          // Remote thumbnail URL
          return SVGAvatar.image(
            imageUrl: thumbnailSource,
            width: 60,
            height: 60,
          );
        } else {
          // Local thumbnail file
          return Image.file(
            File(thumbnailSource),
            fit: BoxFit.cover,
            width: 60,
            height: 60,
          );
        }
      } else {
        // Fallback video icon
        return Container(
          color: Colors.black54,
          child: Icon(Icons.videocam, color: Colors.white54, size: 24),
        );
      }
    } else {
      // For images, show the image itself
      return SVGAvatar.image(imageUrl: mediaRef.url, width: 60, height: 60);
    }
  }

  Future<void> _shareCurrentMedia() async {
    if (_mediaIndex.isNotEmpty && _currentIndex < _mediaIndex.length) {
      final currentMedia = _mediaIndex[_currentIndex];
      final mediaUrl = currentMedia.url;
      final mediaType = currentMedia.isVideo ? 'video' : 'image';

      try {
        print('📤 Sharing $mediaType: $mediaUrl');
        // Try to get cached local file first
        final localPath = await MediaStorageService.getCachedMediaPath(
          mediaUrl,
        );

        if (localPath != null) {
          // Share the local cached file with proper positioning for iOS
          await Share.shareXFiles(
            [XFile(localPath)],
            subject: 'Shared $mediaType from Duggy',
            sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
          );
        } else {
          // Fallback to sharing URL if no local file
          await Share.shareUri(
            Uri.parse(mediaUrl),
            sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
          );
        }
      } catch (e) {
        // Final fallback to sharing as text URL
        await Share.share(
          mediaUrl,
          subject: 'Shared $mediaType from Duggy',
          sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaIndex.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.perm_media, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text(
                'No media found',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: Colors.black54,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Row(
                children: [
                  // Club logo
                  Container(
                    margin: EdgeInsets.only(right: 12),
                    child: ClubLogoWidget.appBar(club: widget.club),
                  ),
                  // Club name
                  Expanded(
                    child: Text(
                      widget.club.name ?? 'Media Gallery',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.share, color: Colors.white),
                  onPressed: () => _shareCurrentMedia(),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // Media PageView - positioned to give full height
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _mediaIndex.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                // Center the thumbnail when page changes
                _centerThumbnail(index);
              },
              itemBuilder: (context, index) {
                final mediaRef = _mediaIndex[index];

                return GestureDetector(
                  onTap: _toggleAppBarVisibility,
                  child: Center(
                    child: Hero(
                      tag: 'media_${mediaRef.url}',
                      child: _buildMediaViewer(mediaRef),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom caption and thumbnail strip overlay
          if (_showAppBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                      Colors.black87,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Caption section
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show media caption if available
                            if (_mediaIndex[_currentIndex].caption != null &&
                                _mediaIndex[_currentIndex].caption!.isNotEmpty) ...[
                              Text(
                                _mediaIndex[_currentIndex].caption!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.left,
                              ),
                              SizedBox(height: 8),
                            ],
                            // Sender name and timestamp
                            Text(
                              _mediaIndex[_currentIndex].senderName,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatDateTime(
                                _mediaIndex[_currentIndex].timestamp,
                              ),
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Thumbnail strip (only show if more than 1 media item)
                      if (_mediaIndex.length > 1)
                        Container(
                          height: 80,
                          child: ListView.builder(
                            controller: _thumbnailScrollController,
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _mediaIndex.length,
                            itemBuilder: (context, index) {
                              final mediaRef = _mediaIndex[index];
                              final isSelected = index == _currentIndex;

                              return GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  // Center thumbnail will be called automatically via onPageChanged
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  margin: EdgeInsets.only(right: 8, bottom: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Thumbnail image
                                        _buildThumbnailForStrip(mediaRef),

                                        // Video play icon overlay
                                        if (mediaRef.isVideo)
                                          Container(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.play_arrow,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),

                                        // Selection overlay
                                        if (isSelected)
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                width: 1,
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
                  ),
                ),
              ),
            ),

          // Media counter
          if (_showAppBar && _mediaIndex.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${_mediaIndex.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
