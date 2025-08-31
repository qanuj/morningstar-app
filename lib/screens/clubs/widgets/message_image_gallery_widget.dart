import 'package:duggy/models/message_image.dart';
import 'package:flutter/material.dart';
import '../../../models/club_message.dart';

class MessageImageGalleryWidget extends StatelessWidget {
  final List<MessageImage> images;
  final ClubMessage message;

  const MessageImageGalleryWidget({
    super.key,
    required this.images,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildImageLayout(context),
      ),
    );
  }

  Widget _buildImageLayout(BuildContext context) {
    if (images.length == 1) {
      return _buildSingleImage(images[0], context);
    } else if (images.length == 2) {
      return _buildTwoImages(context);
    } else if (images.length == 3) {
      return _buildThreeImages(context);
    } else if (images.length == 4) {
      return _buildFourImages(context);
    } else {
      return _buildMoreThanFourImages(context);
    }
  }

  Widget _buildSingleImage(MessageImage image, BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, 0),
      child: _buildImageWidget(
        image,
        height: _calculateSingleImageHeight(image),
        fitToWidth: true,
      ),
    );
  }

  Widget _buildTwoImages(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context, 0),
            child: _buildImageWidget(images[0], height: 200),
          ),
        ),
        SizedBox(width: 2),
        Expanded(
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context, 1),
            child: _buildImageWidget(images[1], height: 200),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeImages(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showFullScreenImage(context, 0),
          child: _buildImageWidget(images[0], height: 150, fitToWidth: true),
        ),
        SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 1),
                child: _buildImageWidget(images[1], height: 100),
              ),
            ),
            SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 2),
                child: _buildImageWidget(images[2], height: 100),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFourImages(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 0),
                child: _buildImageWidget(images[0], height: 120),
              ),
            ),
            SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 1),
                child: _buildImageWidget(images[1], height: 120),
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 2),
                child: _buildImageWidget(images[2], height: 120),
              ),
            ),
            SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 3),
                child: _buildImageWidget(images[3], height: 120),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoreThanFourImages(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 0),
                child: _buildImageWidget(images[0], height: 120),
              ),
            ),
            SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 1),
                child: _buildImageWidget(images[1], height: 120),
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 2),
                child: _buildImageWidget(images[2], height: 120),
              ),
            ),
            SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, 3),
                child: Stack(
                  children: [
                    _buildImageWidget(images[3], height: 120),
                    if (images.length > 4)
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                        ),
                        child: Center(
                          child: Text(
                            '+${images.length - 4}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageWidget(
    MessageImage image, {
    double? height,
    bool fitToWidth = false,
  }) {
    return Container(
      height: height,
      child: Image.network(
        image.url,
        fit: fitToWidth ? BoxFit.fitWidth : BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height ?? 200,
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: Color(0xFF06aeef),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height ?? 200,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey[600]),
          );
        },
      ),
    );
  }

  double _calculateSingleImageHeight(MessageImage image) {
    // Default height for single images
    double height = 200;

    try {
      if (image.width != null && image.height != null) {
        final aspectRatio = image.height! / image.width!;
        const maxWidth = 280; // approximate max width for chat bubble
        height = maxWidth * aspectRatio;

        // Constrain height between min and max values
        height = height.clamp(120.0, 400.0);
      }
    } catch (e) {
      // Use default height if calculation fails
      height = 200;
    }

    return height;
  }

  void _showFullScreenImage(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageImageGalleryScreen(
          images: images,
          initialIndex: initialIndex,
          message: message,
        ),
      ),
    );
  }
}

// Full screen image gallery
class MessageImageGalleryScreen extends StatefulWidget {
  final List<MessageImage> images;
  final int initialIndex;
  final ClubMessage message;

  const ImageGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.message,
  });

  @override
  _MessageImageGalleryScreenState createState() => _MessageImageGalleryScreenState();
}

class _MessageImageGalleryScreenState extends State<MessageImageGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  child: Image.network(
                    widget.images[index].url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          color: Color(0xFF06aeef),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Header with close button and counter
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: Text(
              '${_currentIndex + 1} / ${widget.images.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Caption at bottom if available
          if (widget.images[_currentIndex].caption != null &&
              widget.images[_currentIndex].caption!.isNotEmpty)
            Positioned(
              bottom: 50,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.images[_currentIndex].caption!,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
