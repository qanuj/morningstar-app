import 'package:duggy/models/club.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/club_message.dart';
import '../models/media_item.dart';
import '../services/media_storage_service.dart';
import '../screens/shared/video_player_screen.dart';
import 'svg_avatar.dart';
import 'club_logo_widget.dart';

class MediaGalleryScreen extends StatefulWidget {
  final List<ClubMessage> messages;
  final int initialMediaIndex;
  final String initialMediaUrl;
  final Club club;

  const MediaGalleryScreen({
    super.key,
    required this.messages,
    required this.initialMediaIndex,
    required this.initialMediaUrl,
    required this.club,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  late PageController _pageController;
  late List<MediaWithMessage> _allMedia;
  int _currentIndex = 0;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _extractAllMedia();
    _findInitialIndex();
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _extractAllMedia() {
    _allMedia = [];

    // Extract all media (images and videos) from all messages, sorted by timestamp
    final List<MediaWithMessage> tempMedia = [];

    for (final message in widget.messages) {
      if (message.media.isNotEmpty) {
        for (final mediaItem in message.media) {
          // Include both images and videos
          tempMedia.add(
            MediaWithMessage(mediaItem: mediaItem, message: message),
          );
        }
      }
    }

    // Sort by message timestamp (oldest first for chronological viewing)
    tempMedia.sort(
      (a, b) => a.message.createdAt.compareTo(b.message.createdAt),
    );
    _allMedia = tempMedia;

    print(
      '📱 MediaGallery: Extracted ${_allMedia.length} media items from ${widget.messages.length} messages',
    );
  }

  void _findInitialIndex() {
    // Find the index of the initially tapped media
    for (int i = 0; i < _allMedia.length; i++) {
      if (_allMedia[i].mediaItem.url == widget.initialMediaUrl) {
        _currentIndex = i;
        break;
      }
    }
    print(
      '📱 MediaGallery: Initial index set to $_currentIndex for ${widget.initialMediaUrl}',
    );
  }

  void _toggleAppBarVisibility() {
    setState(() {
      _showAppBar = !_showAppBar;
    });
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
    super.dispose();
  }

  Widget _buildMediaViewer(MediaItem mediaItem) {
    if (mediaItem.isVideo) {
      return _buildVideoViewer(mediaItem);
    } else {
      return _buildImageViewer(mediaItem);
    }
  }

  Widget _buildImageViewer(MediaItem mediaItem) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      child: SVGAvatar.image(
        imageUrl: mediaItem.url,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
      ),
    );
  }

  Widget _buildVideoViewer(MediaItem mediaItem) {
    return Stack(
      children: [
        // Video thumbnail with play button
        Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.black,
          child: Stack(
            children: [
              // Show video thumbnail if available
              if (mediaItem.hasThumbnail)
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 3.0,
                    child:
                        mediaItem.thumbnailUrl != null &&
                            mediaItem.thumbnailUrl!.startsWith('http')
                        ? SVGAvatar.image(
                            imageUrl: mediaItem.thumbnailUrl!,
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.8,
                          )
                        : mediaItem.thumbnailPath != null
                        ? Image.file(
                            File(mediaItem.thumbnailPath!),
                            fit: BoxFit.contain,
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.8,
                          )
                        : Container(
                            color: Colors.black54,
                            child: Icon(
                              Icons.videocam,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                  ),
                )
              else
                // Fallback when no thumbnail
                Center(
                  child: Container(
                    color: Colors.black54,
                    child: Icon(
                      Icons.videocam,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),

              // Play button overlay
              Center(
                child: GestureDetector(
                  onTap: () => _playVideo(mediaItem),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),

              // Duration badge if available
              if (mediaItem.duration != null)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(mediaItem.duration!),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _playVideo(MediaItem mediaItem) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            VideoPlayerScreen(videoUrl: mediaItem.url, title: 'Video'),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildThumbnailForStrip(MediaItem mediaItem) {
    if (mediaItem.isVideo) {
      // For videos, show thumbnail if available
      if (mediaItem.hasThumbnail) {
        final thumbnailSource = mediaItem.bestThumbnail!;

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
      return SVGAvatar.image(imageUrl: mediaItem.url, width: 60, height: 60);
    }
  }

  Future<void> _shareCurrentMedia() async {
    if (_allMedia.isNotEmpty && _currentIndex < _allMedia.length) {
      final currentMedia = _allMedia[_currentIndex];
      final mediaUrl = currentMedia.mediaItem.url;
      final mediaType = currentMedia.mediaItem.isVideo ? 'video' : 'image';

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
    if (_allMedia.isEmpty) {
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
                    child: ClubLogoWidget.appBar(
                      club: widget.club,
                    ),
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
              itemCount: _allMedia.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final mediaWithMessage = _allMedia[index];
                final mediaItem = mediaWithMessage.mediaItem;

                return GestureDetector(
                  onTap: _toggleAppBarVisibility,
                  child: Center(
                    child: Hero(
                      tag: 'media_${mediaItem.url}',
                      child: _buildMediaViewer(mediaItem),
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
                            Text(
                              _allMedia[_currentIndex].message.senderName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatDateTime(
                                _allMedia[_currentIndex].message.createdAt,
                              ),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Thumbnail strip (only show if more than 1 media item)
                      if (_allMedia.length > 1)
                        Container(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _allMedia.length,
                            itemBuilder: (context, index) {
                              final mediaWithMessage = _allMedia[index];
                              final mediaItem = mediaWithMessage.mediaItem;
                              final isSelected = index == _currentIndex;

                              return GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
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
                                        _buildThumbnailForStrip(mediaItem),

                                        // Video play icon overlay
                                        if (mediaItem.isVideo)
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
          if (_showAppBar && _allMedia.length > 1)
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
                  '${_currentIndex + 1} / ${_allMedia.length}',
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

class MediaWithMessage {
  final MediaItem mediaItem;
  final ClubMessage message;

  MediaWithMessage({required this.mediaItem, required this.message});
}
