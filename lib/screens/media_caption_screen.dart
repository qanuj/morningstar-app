import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import '../models/media_item.dart';
import '../widgets/video_player_widget.dart';

class MediaCaptionScreen extends StatefulWidget {
  final List<MediaItem>? mediaItems;
  final Function(List<MediaItem> mediaItems)? onSend;
  final String? imageUrl;
  final PlatformFile? imageFile;
  final String? initialCaption;
  final Function(String caption, String? croppedImagePath)? onSendSingle;
  final String title;

  const MediaCaptionScreen({
    super.key,
    this.mediaItems,
    this.onSend,
    this.imageUrl,
    this.imageFile,
    this.initialCaption,
    this.onSendSingle,
    this.title = 'Send Media',
  }) : assert(
         (mediaItems != null && onSend != null) ||
             ((imageUrl != null || imageFile != null) && onSendSingle != null),
         'Either provide mediaItems with onSend, or imageUrl/imageFile with onSendSingle',
       );

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

  // Single item mode properties (from ImageCaptionDialog)
  bool _isSingleMode = false;
  String? _currentImagePath;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _isCropping = false;
  bool _isVideo = false;
  late TextEditingController _singleCaptionController;

  @override
  void initState() {
    super.initState();

    // Check if we're in single item mode
    _isSingleMode = widget.mediaItems == null;

    if (_isSingleMode) {
      // Single item mode - create MediaItem from imageUrl/imageFile
      _singleCaptionController = TextEditingController(
        text: widget.initialCaption ?? '',
      );
      _checkIfVideo();
      _loadImage();

      // Create a single MediaItem for consistency
      _mediaItems = [];
      _captionControllers = [];
    } else {
      // Multiple items mode
      _mediaItems = List.from(widget.mediaItems!);
      _captionControllers = _mediaItems
          .map((item) => TextEditingController(text: item.caption ?? ''))
          .toList();
      _isLoading = false;
    }

    _pageController = PageController();
    _sharedCaptionController = TextEditingController();
  }

  void _checkIfVideo() {
    if (widget.imageFile?.name != null) {
      final extension = widget.imageFile!.name.split('.').last.toLowerCase();
      _isVideo = [
        'mp4',
        'mov',
        'avi',
        'mkv',
        '3gp',
        'webm',
        'm4v',
        'mpg',
        'mpeg',
      ].contains(extension);
    } else if (widget.imageUrl != null) {
      final extension = widget.imageUrl!.split('.').last.toLowerCase();
      _isVideo = [
        'mp4',
        'mov',
        'avi',
        'mkv',
        '3gp',
        'webm',
        'm4v',
        'mpg',
        'mpeg',
      ].contains(extension);
    }
  }

  Future<void> _loadImage() async {
    try {
      if (widget.imageFile != null) {
        _currentImagePath = widget.imageFile!.path;
        if (!_isVideo) {
          _imageBytes =
              widget.imageFile!.bytes ??
              await File(widget.imageFile!.path!).readAsBytes();
        }
      } else if (widget.imageUrl != null) {
        _currentImagePath = widget.imageUrl;
        if (!_isVideo && widget.imageUrl!.startsWith('http')) {
          // Load network image
          final response = await HttpClient().getUrl(
            Uri.parse(widget.imageUrl!),
          );
          final httpResponse = await response.close();
          _imageBytes = await consolidateHttpClientResponseBytes(httpResponse);
        } else if (!_isVideo) {
          _imageBytes = await File(widget.imageUrl!).readAsBytes();
        }
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sharedCaptionController.dispose();
    for (var controller in _captionControllers) {
      controller.dispose();
    }
    if (_isSingleMode) {
      _singleCaptionController.dispose();
    }
    super.dispose();
  }

  Future<void> _cropCurrentImage() async {
    if (_isCropping || _isVideo || _currentImagePath == null) return;

    setState(() => _isCropping = true);

    try {
      String? imagePath = _currentImagePath;

      // If we have bytes but no file path, create a temporary file
      if (_imageBytes != null &&
          (!_currentImagePath!.contains('/') ||
              _currentImagePath!.startsWith('http'))) {
        final tempDir = Directory.systemTemp;
        final tempFile = File(
          '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(_imageBytes!);
        imagePath = tempFile.path;
      }

      if (imagePath != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: imagePath,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Edit Image',
              toolbarColor: Color(0xFF003f9b),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Edit Image',
              minimumAspectRatio: 0.1,
              aspectRatioLockEnabled: false,
            ),
          ],
        );

        if (croppedFile != null && mounted) {
          _currentImagePath = croppedFile.path;
          _imageBytes = await File(croppedFile.path).readAsBytes();

          // Update the MediaItem if in multiple mode
          if (!_isSingleMode && _mediaItems.isNotEmpty) {
            _mediaItems[_currentIndex] = _mediaItems[_currentIndex].copyWith(
              url: croppedFile.path,
            );
          }

          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to crop image: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  Future<void> _cropImageAtIndex(int index) async {
    if (_isCropping || index >= _mediaItems.length) return;

    final item = _mediaItems[index];
    if (item.isVideo) return; // Can't crop videos

    setState(() => _isCropping = true);

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: item.url,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Image',
            toolbarColor: Color(0xFF003f9b),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Edit Image',
            minimumAspectRatio: 0.1,
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        // Update the MediaItem with the cropped image path
        _mediaItems[index] = _mediaItems[index].copyWith(url: croppedFile.path);
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to crop image: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  bool _shouldShowCropButton() {
    if (_isSingleMode) {
      return !_isVideo && _currentImagePath != null;
    } else {
      return !_isVideo && _mediaItems.isNotEmpty && !_mediaItems[_currentIndex].isVideo;
    }
  }

  void _handleCropFromAppBar() {
    if (_isSingleMode) {
      _cropCurrentImage();
    } else {
      _cropImageAtIndex(_currentIndex);
    }
  }

  String _getCaptionPlaceholder() {
    if (_isSingleMode) {
      return 'Caption';
    } else if (_hasSharedCaption) {
      return 'Caption for all media';
    } else if (_mediaItems.length == 1) {
      return 'Caption';
    } else {
      return 'Caption ${_currentIndex + 1} of ${_mediaItems.length}';
    }
  }

  void _sendMedia() {
    print('🔍 MediaCaptionScreen: _sendMedia called');
    print('🔍 MediaCaptionScreen: _isSingleMode = $_isSingleMode');
    print('🔍 MediaCaptionScreen: _mediaItems.length = ${_mediaItems.length}');
    print('🔍 MediaCaptionScreen: widget.onSend = ${widget.onSend}');
    print('🔍 MediaCaptionScreen: widget.onSendSingle = ${widget.onSendSingle}');

    if (_isSingleMode) {
      // Single item mode
      final caption = _singleCaptionController.text.trim();
      print('🔍 MediaCaptionScreen: Single mode - caption = "$caption"');
      print('🔍 MediaCaptionScreen: Single mode - _currentImagePath = $_currentImagePath');
      print('🔍 MediaCaptionScreen: Calling widget.onSendSingle');
      widget.onSendSingle!(caption, _currentImagePath);
      print('🔍 MediaCaptionScreen: widget.onSendSingle completed');
      // Don't pop here - let the callback handle navigation
    } else {
      // Multiple items mode
      final updatedMediaItems = <MediaItem>[];

      for (int i = 0; i < _mediaItems.length; i++) {
        final caption = _hasSharedCaption
            ? _sharedCaptionController.text.trim()
            : _captionControllers[i].text.trim();

        updatedMediaItems.add(
          _mediaItems[i].copyWith(caption: caption.isEmpty ? null : caption),
        );
      }

      print('🔍 MediaCaptionScreen: Multiple mode - updatedMediaItems.length = ${updatedMediaItems.length}');
      for (int i = 0; i < updatedMediaItems.length; i++) {
        print('🔍 MediaCaptionScreen: Item $i: ${updatedMediaItems[i].url}, caption: "${updatedMediaItems[i].caption}"');
      }

      print('🔍 MediaCaptionScreen: Calling widget.onSend');
      widget.onSend!(updatedMediaItems);
      print('🔍 MediaCaptionScreen: widget.onSend completed');
      // Don't pop here - let the callback handle navigation
    }
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

  Widget _buildSingleModePreview() {
    if (_isLoading) {
      return Container(
        height: 300,
        color: Color(0xFF0f0f0f),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06aeef)),
          ),
        ),
      );
    }

    // Show video player for video files
    if (_isVideo && _currentImagePath != null) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Color(0xFF0f0f0f),
        child: Stack(
          children: [
            VideoThumbnailWidget(
              videoUrl: _currentImagePath!,
              onTap: () {}, // No action needed in preview
              borderRadius: 12,
            ),
            // Add crop button overlay for videos (disabled)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Crop not available for videos',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show image for image files
    if (_imageBytes != null && !_isVideo) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Color(0xFF0f0f0f),
        child: Center(
          child: Image.memory(
            _imageBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _buildErrorWidget(),
          ),
        ),
      );
    }

    return _buildErrorWidget();
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
                errorBuilder: (context, error, stackTrace) =>
                    VideoThumbnailWidget(
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
                errorBuilder: (context, error, stackTrace) =>
                    _buildErrorWidget(),
              )
            : Image.network(
                item.url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildErrorWidget(),
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
          Text(
            'Failed to load media',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
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
                              errorBuilder: (context, error, stackTrace) =>
                                  VideoThumbnailWidget(
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
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Color(0xFF2a2a2a),
                          child: Icon(Icons.error, color: Colors.white38),
                        ),
                      )
                    : Image.network(
                        item.url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Color(0xFF2a2a2a),
                          child: Icon(Icons.error, color: Colors.white38),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptionInput() {
    // Get the appropriate controller based on mode
    TextEditingController controller;
    if (_isSingleMode) {
      controller = _singleCaptionController;
    } else if (_hasSharedCaption) {
      controller = _sharedCaptionController;
    } else {
      controller = _captionControllers[_currentIndex];
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          // Caption input
          Expanded(
            child: Theme(
              data: ThemeData(
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Color(0xFF1a1a1a),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: Colors.white,
                  selectionColor: Colors.white.withOpacity(0.3),
                  selectionHandleColor: Colors.white,
                ),
              ),
              child: TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: _getCaptionPlaceholder(),
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                cursorColor: Colors.white,
                onSubmitted: (_) => _sendMedia(),
              ),
            ),
          ),
          // Send button
          Padding(
            padding: EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: _sendMedia,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF003f9b),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF003f9b).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          // Crop button for images only
          if (_shouldShowCropButton())
            IconButton(
              icon: _isCropping
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06aeef)),
                      ),
                    )
                  : Icon(Icons.crop, color: Colors.white),
              onPressed: _isCropping ? null : _handleCropFromAppBar,
              tooltip: 'Edit Image',
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
                child: _isSingleMode
                    ? _buildSingleModePreview()
                    : PageView.builder(
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
          if (!_isSingleMode) _buildThumbnailStrip(),

          // Caption Input Section
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: _buildCaptionInput(),
          ),
        ],
      ),
    );
  }
}
