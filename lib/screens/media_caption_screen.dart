import 'package:flutter/material.dart';
import 'dart:io';
import '../models/media_item.dart';
import '../widgets/video_player_widget.dart';

class MediaCaptionScreen extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final Function(List<MediaItem> mediaItems) onSend;
  final String title;

  const MediaCaptionScreen({
    super.key,
    required this.mediaItems,
    required this.onSend,
    this.title = 'Send Media',
  });

  @override
  State<MediaCaptionScreen> createState() => _MediaCaptionScreenState();
}

class _MediaCaptionScreenState extends State<MediaCaptionScreen> {
  late List<MediaItem> _mediaItems;
  late PageController _pageController;
  late List<TextEditingController> _captionControllers;
  int _currentIndex = 0;
  bool _hasSharedCaption = false;
  late TextEditingController _sharedCaptionController;

  @override
  void initState() {
    super.initState();
    _mediaItems = List.from(widget.mediaItems);
    _pageController = PageController();
    _sharedCaptionController = TextEditingController();

    // Initialize individual caption controllers
    _captionControllers = _mediaItems.map((item) =>
        TextEditingController(text: item.caption ?? '')).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sharedCaptionController.dispose();
    for (var controller in _captionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _sendMedia() {
    // Update media items with their individual captions or shared caption
    final updatedMediaItems = <MediaItem>[];

    for (int i = 0; i < _mediaItems.length; i++) {
      final caption = _hasSharedCaption
          ? _sharedCaptionController.text.trim()
          : _captionControllers[i].text.trim();

      updatedMediaItems.add(_mediaItems[i].copyWith(
        caption: caption.isEmpty ? null : caption,
      ));
    }

    Navigator.of(context).pop();
    widget.onSend(updatedMediaItems);
  }

  void _toggleCaptionMode() {
    setState(() {
      _hasSharedCaption = !_hasSharedCaption;
      if (_hasSharedCaption) {
        // Set shared caption to current item's caption
        _sharedCaptionController.text = _captionControllers[_currentIndex].text;
      } else {
        // Distribute shared caption to all items
        final sharedText = _sharedCaptionController.text;
        for (var controller in _captionControllers) {
          controller.text = sharedText;
        }
      }
    });
  }

  Widget _buildMediaPreview(MediaItem item) {
    if (item.isVideo) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Color(0xFF0f0f0f),
        child: Stack(
          children: [
            // Use generated thumbnail if available, otherwise fallback to VideoThumbnailWidget
            if (item.thumbnailPath != null)
              Image.file(
                File(item.thumbnailPath!),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => VideoThumbnailWidget(
                  videoUrl: item.url,
                  onTap: () {},
                  borderRadius: 12,
                ),
              )
            else
              VideoThumbnailWidget(
                videoUrl: item.url,
                onTap: () {},
                borderRadius: 12,
              ),

            // Play button overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.black87,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),

            // Duration badge if available
            if (item.duration != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(item.duration!),
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
      );
    } else {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Color(0xFF0f0f0f),
        child: item.isLocal
            ? Image.file(
                File(item.url),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
              )
            : Image.network(
                item.url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
              ),
      );
    }
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Color(0xFF0f0f0f),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white38, size: 48),
          SizedBox(height: 8),
          Text('Failed to load media', style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    if (_mediaItems.length <= 1) return SizedBox.shrink();

    return Container(
      height: 80,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaItems.length,
        itemBuilder: (context, index) {
          final item = _mediaItems[index];
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
              margin: EdgeInsets.only(right: 8, left: index == 0 ? 16 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Color(0xFF06aeef) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: item.isVideo
                    ? Stack(
                        children: [
                          // Use generated thumbnail if available
                          if (item.thumbnailPath != null)
                            Image.file(
                              File(item.thumbnailPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => VideoThumbnailWidget(
                                videoUrl: item.url,
                                onTap: () {},
                                borderRadius: 0,
                              ),
                            )
                          else
                            VideoThumbnailWidget(
                              videoUrl: item.url,
                              onTap: () {},
                              borderRadius: 0,
                            ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      )
                    : item.isLocal
                        ? Image.file(
                            File(item.url),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: Color(0xFF2a2a2a), child: Icon(Icons.error, color: Colors.white38)),
                          )
                        : Image.network(
                            item.url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: Color(0xFF2a2a2a), child: Icon(Icons.error, color: Colors.white38)),
                          ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptionInput() {
    if (_hasSharedCaption) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.message, color: Color(0xFF06aeef), size: 16),
              SizedBox(width: 6),
              Text(
                'Shared Caption',
                style: TextStyle(
                  color: Color(0xFF06aeef),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: _toggleCaptionMode,
                child: Text(
                  'Individual',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: _sharedCaptionController,
            maxLines: 3,
            minLines: 1,
            style: TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Type a caption for all media...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              filled: true,
              fillColor: Color(0xFF2a2a2a),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.message, color: Color(0xFF06aeef), size: 16),
              SizedBox(width: 6),
              Text(
                'Caption ${_currentIndex + 1} of ${_mediaItems.length}',
                style: TextStyle(
                  color: Color(0xFF06aeef),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: _toggleCaptionMode,
                child: Text(
                  'Shared',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: _captionControllers[_currentIndex],
            maxLines: 3,
            minLines: 1,
            style: TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Type a caption...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              filled: true,
              fillColor: Color(0xFF2a2a2a),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0f0f0f),
      appBar: AppBar(
        backgroundColor: Color(0xFF0f0f0f),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _sendMedia,
            child: Text(
              'Send',
              style: TextStyle(
                color: Color(0xFF06aeef),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Media Preview Section
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    return _buildMediaPreview(_mediaItems[index]);
                  },
                ),
              ),
            ),
          ),

          // Thumbnail Strip (if multiple items)
          _buildThumbnailStrip(),

          // Caption Input Section
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(
              color: Color(0xFF1a1a1a),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCaptionInput(),
                SizedBox(height: 16),

                // Send Button Row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _sendMedia,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(0xFF003f9b),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF003f9b).withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Send ${_mediaItems.length > 1 ? '${_mediaItems.length} items' : 'Media'}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}