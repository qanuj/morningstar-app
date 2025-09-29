import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final double? aspectRatio;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final double borderRadius;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.aspectRatio,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = true,
    this.borderRadius = 12.0,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Determine if URL is network or local file
      late VideoPlayerController controller;
      if (widget.videoUrl.startsWith('http://') || widget.videoUrl.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      } else {
        // Local file path
        controller = VideoPlayerController.asset(widget.videoUrl);
      }

      _videoController = controller;

      await controller.initialize();

      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: controller,
          aspectRatio: widget.aspectRatio ?? controller.value.aspectRatio,
          autoPlay: widget.autoPlay,
          looping: widget.looping,
          showControls: widget.showControls,
          materialProgressColors: ChewieProgressColors(
            playedColor: Color(0xFF003f9b),
            handleColor: Color(0xFF06aeef),
            backgroundColor: Colors.grey,
            bufferedColor: Colors.grey.withOpacity(0.5),
          ),
          placeholder: Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06aeef)),
              ),
            ),
          ),
          errorBuilder: (context, errorMessage) => _buildErrorWidget(errorMessage),
        );

        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ VideoPlayerWidget: Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(_errorMessage ?? 'Failed to load video');
    }

    if (!_isInitialized || _chewieController == null) {
      return _buildLoadingWidget();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AspectRatio(
        aspectRatio: _chewieController!.aspectRatio!,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06aeef)),
            ),
            SizedBox(height: 12),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Failed to load video',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (error.isNotEmpty) ...[
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }
}

/// Simple video thumbnail with play button overlay for gallery display
class VideoThumbnailWidget extends StatelessWidget {
  final String videoUrl;
  final VoidCallback onTap;
  final double borderRadius;
  final double? width;
  final double? height;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    required this.onTap,
    this.borderRadius = 12.0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height ?? 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Stack(
          children: [
            // Video thumbnail placeholder (you could implement actual thumbnail generation)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Icon(
                Icons.video_library,
                size: 48,
                color: Colors.grey[600],
              ),
            ),
            // Play button overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(borderRadius),
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
                      size: 32,
                      color: Color(0xFF003f9b),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}