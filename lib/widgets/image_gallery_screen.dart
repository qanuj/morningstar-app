import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/club_message.dart';
import '../services/media_storage_service.dart';
import 'svg_avatar.dart';

class ImageGalleryScreen extends StatefulWidget {
  final List<ClubMessage> messages;
  final int initialImageIndex;
  final String initialImageUrl;

  const ImageGalleryScreen({
    super.key,
    required this.messages,
    required this.initialImageIndex,
    required this.initialImageUrl,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late PageController _pageController;
  late List<ImageWithMessage> _allImages;
  int _currentIndex = 0;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _extractAllImages();
    _findInitialIndex();
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _extractAllImages() {
    _allImages = [];

    // Extract all images from all messages
    for (final message in widget.messages) {
      if (message.images.isNotEmpty) {
        for (final image in message.images) {
          _allImages.add(ImageWithMessage(image: image, message: message));
        }
      }
    }
  }

  void _findInitialIndex() {
    // Find the index of the initially tapped image
    for (int i = 0; i < _allImages.length; i++) {
      if (_allImages[i].image == widget.initialImageUrl) {
        _currentIndex = i;
        break;
      }
    }
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

  Future<void> _shareCurrentImage() async {
    if (_allImages.isNotEmpty && _currentIndex < _allImages.length) {
      final currentImage = _allImages[_currentIndex];
      final imageUrl = currentImage.image;

      try {
        // Try to get cached local file first
        final localPath = await MediaStorageService.getCachedMediaPath(
          imageUrl,
        );

        if (localPath != null) {
          // Share the local cached file with proper positioning for iOS
          await Share.shareXFiles(
            [XFile(localPath)],
            subject: 'Shared image from Duggy',
            sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
          );
        } else {
          // Fallback to sharing URL if no local file
          await Share.shareUri(
            Uri.parse(imageUrl),
            sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
          );
        }
      } catch (e) {
        // Final fallback to sharing as text URL
        await Share.share(
          imageUrl,
          subject: 'Shared image from Duggy',
          sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allImages.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text(
                'No images found',
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _allImages[_currentIndex].message.senderName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _formatDateTime(
                      _allImages[_currentIndex].message.createdAt,
                    ),
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.share, color: Colors.white),
                  onPressed: () => _shareCurrentImage(),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // Image PageView - positioned to give more height
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0, // Reduce bottom space to give more height to image
            child: PageView.builder(
              controller: _pageController,
              itemCount: _allImages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imageWithMessage = _allImages[index];
                return GestureDetector(
                  onTap: _toggleAppBarVisibility,
                  child: Center(
                    child: Hero(
                      tag: 'image_${imageWithMessage.image}',
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        child: SVGAvatar.image(
                          imageUrl: imageWithMessage.image,
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom caption overlay
          if (_showAppBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(20),
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
                  child: Text(
                    'Pictures',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ),

          // Image counter
          if (_showAppBar && _allImages.length > 1)
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
                  '${_currentIndex + 1} / ${_allImages.length}',
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

class ImageWithMessage {
  final String image;
  final ClubMessage message;

  ImageWithMessage({required this.image, required this.message});
}
