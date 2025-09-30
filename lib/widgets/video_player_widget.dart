import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import '../services/media_storage_service.dart';

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

/// Cached video player widget that downloads and caches videos locally
class CachedVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final double? aspectRatio;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final double borderRadius;

  const CachedVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.aspectRatio,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = true,
    this.borderRadius = 12.0,
  });

  @override
  State<CachedVideoPlayerWidget> createState() => _CachedVideoPlayerWidgetState();
}

class _CachedVideoPlayerWidgetState extends State<CachedVideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isDownloading = false;
  String? _errorMessage;
  String? _cachedVideoPath;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeCachedVideo();
  }

  Future<void> _initializeCachedVideo() async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      // Check if video is already cached
      final cachedPath = await MediaStorageService.getCachedMediaPath(widget.videoUrl);

      if (cachedPath != null && await File(cachedPath).exists()) {
        print('🎥 Using cached video: $cachedPath');
        _cachedVideoPath = cachedPath;
      } else {
        print('📥 Downloading video: ${widget.videoUrl}');
        // Simulate download progress (MediaStorageService doesn't provide progress yet)
        for (int i = 0; i <= 100; i += 10) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = i / 100.0;
          });
          await Future.delayed(Duration(milliseconds: 100));
        }

        final downloadedPath = await MediaStorageService.downloadMedia(widget.videoUrl);
        if (downloadedPath != null) {
          _cachedVideoPath = downloadedPath;
          print('✅ Video downloaded and cached: $downloadedPath');
        } else {
          throw Exception('Failed to download video');
        }
      }

      setState(() {
        _isDownloading = false;
      });

      // Initialize video player with cached file
      await _initializeVideoPlayer();
    } catch (e) {
      print('❌ CachedVideoPlayerWidget: Error initializing cached video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isDownloading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_cachedVideoPath == null) return;

    try {
      // Use local file path for video controller
      final controller = VideoPlayerController.file(File(_cachedVideoPath!));
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
            color: Colors.grey[800],
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
      print('❌ CachedVideoPlayerWidget: Error initializing video player: $e');
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

    if (_isDownloading) {
      return _buildDownloadingWidget();
    }

    if (!_isInitialized || _chewieController == null) {
      return _buildLoadingWidget();
    }

    // Get the video aspect ratio, with fallback
    final videoAspectRatio = _chewieController?.aspectRatio ?? widget.aspectRatio ?? (16 / 9);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the best fit for the video within available space
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          // Calculate dimensions based on aspect ratio
          double videoWidth = availableWidth;
          double videoHeight = videoWidth / videoAspectRatio;

          // If video height exceeds available height, scale down
          if (videoHeight > availableHeight) {
            videoHeight = availableHeight;
            videoWidth = videoHeight * videoAspectRatio;
          }

          return SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: AspectRatio(
              aspectRatio: videoAspectRatio,
              child: Chewie(controller: _chewieController!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDownloadingWidget() {
    return Container(
      constraints: BoxConstraints(
        minHeight: 200,
        maxHeight: double.infinity,
        minWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_download,
            color: Colors.white70,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'Downloading video...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Container(
            width: 200,
            child: LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.grey[600],
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06aeef)),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${(_downloadProgress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      constraints: BoxConstraints(
        minHeight: 200,
        maxHeight: double.infinity,
        minWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[800],
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
              'Preparing video...',
              style: TextStyle(
                color: Colors.white70,
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
      constraints: BoxConstraints(
        minHeight: 200,
        maxHeight: double.infinity,
        minWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Failed to load video',
            style: TextStyle(
              color: Colors.white70,
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
                  color: Colors.white60,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _initializeCachedVideo(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF06aeef),
              foregroundColor: Colors.white,
            ),
            child: Text('Retry'),
          ),
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