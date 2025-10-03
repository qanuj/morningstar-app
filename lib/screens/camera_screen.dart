import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/media_item.dart';
import '../screens/media_caption_screen.dart';
import '../services/video_compression_service.dart';

enum CaptureMode { photo, video }

class CameraScreen extends StatefulWidget {
  final CaptureMode initialMode;
  final Function(List<MediaItem>) onMediaCaptured;

  const CameraScreen({
    super.key,
    this.initialMode = CaptureMode.photo,
    required this.onMediaCaptured,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isCapturing = false;
  bool _isGalleryOpening = false;
  bool _isFlashAvailable = false;
  bool _isZoomOverlayVisible = false;
  CaptureMode _currentMode = CaptureMode.photo;
  int _selectedCameraIndex = 0;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  double _baseZoom = 1.0;
  final ImagePicker _imagePicker = ImagePicker();
  FlashMode _flashMode = FlashMode.off;
  Timer? _zoomOverlayTimer;
  double _horizontalDragDelta = 0.0;
  bool _modeChangedDuringGesture = false;
  late AnimationController _recordingAnimationController;
  late Animation<double> _recordingAnimation;
  String? _recordingDuration;
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    WidgetsBinding.instance.addObserver(this);

    // Initialize recording animation
    _recordingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _recordingAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _recordingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _recordingAnimationController.dispose();
    _zoomOverlayTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Don't dispose immediately on inactive, wait for paused
      return;
    } else if (state == AppLifecycleState.paused) {
      cameraController.dispose();
      setState(() {
        _isLoading = true;
      });
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera and microphone permissions
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isDenied || micStatus.isDenied) {
        _showErrorDialog('Camera and microphone permissions are required');
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showErrorDialog('No cameras available on this device');
        return;
      }

      // Initialize camera controller
      await _initializeCameraController(_selectedCameraIndex);
    } catch (e) {
      _showErrorDialog('Failed to initialize camera: $e');
    }
  }

  Future<void> _initializeCameraController(int cameraIndex) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    // Dispose previous controller
    await _cameraController?.dispose();
    _cameraController = null;

    // Create new controller
    _cameraController = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();

      if (!mounted) return;

      // Get zoom levels
      _maxZoom = await _cameraController!.getMaxZoomLevel();
      _minZoom = await _cameraController!.getMinZoomLevel();
      _currentZoom = _minZoom;
      _baseZoom = _currentZoom;
      try {
        await _cameraController!.setZoomLevel(_currentZoom);
      } catch (_) {}

      bool flashSupported = false;
      try {
        await _cameraController!.setFlashMode(_flashMode);
        flashSupported = true;
      } catch (_) {
        flashSupported = false;
        _flashMode = FlashMode.off;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFlashAvailable = flashSupported;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to initialize camera controller: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile photo = await _cameraController!.takePicture();
      await _handleCapturedMedia(photo.path, false);
    } catch (e) {
      _showErrorSnackBar('Failed to capture photo: $e');
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isRecording) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
      });

      // Start recording animation
      _recordingAnimationController.repeat(reverse: true);

      // Start duration timer
      _updateRecordingDuration();
    } catch (e) {
      _showErrorSnackBar('Failed to start recording: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        !_isRecording) {
      return;
    }

    try {
      final XFile video = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordingStartTime = null;
        _recordingDuration = null;
      });

      // Stop recording animation
      _recordingAnimationController.stop();
      _recordingAnimationController.reset();

      await _handleCapturedMedia(video.path, true);
    } catch (e) {
      _showErrorSnackBar('Failed to stop recording: $e');
    }
  }

  void _updateRecordingDuration() {
    if (_isRecording && _recordingStartTime != null) {
      final duration = DateTime.now().difference(_recordingStartTime!);
      setState(() {
        _recordingDuration = _formatDuration(duration);
      });

      // Continue updating every second
      Future.delayed(const Duration(seconds: 1), () {
        if (_isRecording) {
          _updateRecordingDuration();
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleCapturedMedia(String filePath, bool isVideo) async {
    try {
      var mediaItem = MediaItem.fromPath(filePath);

      // Generate thumbnail for videos
      if (isVideo) {
        final thumbnailPath = await VideoCompressionService.generateThumbnail(
          filePath,
        );
        if (thumbnailPath != null) {
          mediaItem = mediaItem.copyWith(thumbnailPath: thumbnailPath);
        }
      }

      // Navigate to caption screen
      if (mounted) {
        final result = await Navigator.push<List<MediaItem>>(
          context,
          MaterialPageRoute(
            builder: (context) => MediaCaptionScreen(
              mediaItems: [mediaItem],
              title: isVideo ? 'Send Video' : 'Send Photo',
              onSend: (mediaItems) {
                Navigator.of(context).pop(mediaItems);
              },
            ),
            fullscreenDialog: true,
          ),
        );

        if (result != null && result.isNotEmpty) {
          // Close camera screen and return captured media
          Navigator.of(context).pop();
          widget.onMediaCaptured(result);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process captured media: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _setCaptureMode(CaptureMode mode) {
    if (_currentMode == mode || _isRecording) {
      return;
    }

    setState(() {
      _currentMode = mode;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1) return;

    setState(() {
      _isLoading = true;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });

    await _initializeCameraController(_selectedCameraIndex);
  }

  void _onCaptureButtonPressed() {
    if (_currentMode == CaptureMode.photo) {
      _capturePhoto();
    } else {
      if (_isRecording) {
        _stopVideoRecording();
      } else {
        _startVideoRecording();
      }
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
    _horizontalDragDelta = 0.0;
    _modeChangedDuringGesture = false;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (details.pointerCount == 1) {
      _horizontalDragDelta += details.focalPointDelta.dx;

      if (!_modeChangedDuringGesture && !_isRecording) {
        if (_horizontalDragDelta <= -60 && _currentMode == CaptureMode.photo) {
          _setCaptureMode(CaptureMode.video);
          _modeChangedDuringGesture = true;
        } else if (_horizontalDragDelta >= 60 &&
            _currentMode == CaptureMode.video) {
          _setCaptureMode(CaptureMode.photo);
          _modeChangedDuringGesture = true;
        }
      }
      return;
    }

    final targetZoom = (_baseZoom * details.scale)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    _updateZoom(targetZoom);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _baseZoom = _currentZoom;
    _horizontalDragDelta = 0.0;
    _modeChangedDuringGesture = false;
  }

  void _updateZoom(double zoom) {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    final clampedZoom = zoom.clamp(_minZoom, _maxZoom).toDouble();
    if ((_currentZoom - clampedZoom).abs() < 0.001) {
      return;
    }

    _cameraController!.setZoomLevel(clampedZoom).catchError((error) {
      debugPrint('Failed to set zoom level: $error');
    });

    setState(() {
      _currentZoom = clampedZoom;
    });

    _showZoomOverlay();
  }

  void _showZoomOverlay() {
    _zoomOverlayTimer?.cancel();
    setState(() {
      _isZoomOverlayVisible = true;
    });

    _zoomOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isZoomOverlayVisible = false;
        });
      }
    });
  }

  Future<void> _cycleFlashMode() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    var index = modes.indexOf(_flashMode);
    if (index == -1) index = 0;
    final nextMode = modes[(index + 1) % modes.length];

    try {
      await _cameraController!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (e) {
      _showErrorSnackBar('Flash mode not supported: $e');
    }
  }

  IconData _flashIconForMode(FlashMode mode) {
    switch (mode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.off:
      case FlashMode.torch:
        return Icons.flash_off;
    }
  }

  Widget _buildCameraPreview(BoxConstraints constraints) {
    final controller = _cameraController!;
    var previewAspectRatio = controller.value.aspectRatio;

    if (previewAspectRatio == 0) {
      previewAspectRatio = 1;
    }

    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      previewAspectRatio = 1 / previewAspectRatio;
    }

    // Use AspectRatio to maintain proper proportions
    return Center(
      child: AspectRatio(
        aspectRatio: previewAspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: topPadding, color: Colors.black.withOpacity(0.95)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _isRecording && _recordingDuration != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _recordingDuration!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                if (_isFlashAvailable)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: IconButton(
                      onPressed: _cycleFlashMode,
                      icon: Icon(
                        _flashIconForMode(_flashMode),
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs() {
    return Container(
      width: 120, // Fixed width to make it more compact
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        children: [
          _buildModeTab('Photo', CaptureMode.photo),
          _buildModeTab('Video', CaptureMode.video),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, CaptureMode mode) {
    final isActive = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => isActive ? null : _setCaptureMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureControls() {
    final isGalleryEnabled =
        !_isCapturing && !_isRecording && !_isGalleryOpening;

    return GestureDetector(
      onTap: _isCapturing ? null : _onCaptureButtonPressed,
      child: AnimatedBuilder(
        animation: _recordingAnimation,
        builder: (context, child) {
          final double innerSize = _isRecording
              ? 32.0 * _recordingAnimation.value
              : _isCapturing
              ? 52.0
              : 60.0;

          final innerColor = _isRecording
              ? Colors.red
              : _currentMode == CaptureMode.video
              ? Colors.red
              : Colors.white;

          return Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 3,
              ),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  color: innerColor,
                  shape: BoxShape.circle,
                ),
                child: _isCapturing
                    ? const CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      )
                    : _isRecording
                    ? const Icon(Icons.stop, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooterButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white.withOpacity(0.3),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingFooterTabs() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 15, 20, bottomPadding + 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Gallery button
            _buildFooterButton(
              icon: Icons.photo_library,
              onTap: _openGallery,
              enabled: !_isCapturing && !_isRecording && !_isGalleryOpening,
            ),
            // Photo/Video mode switcher
            _buildModeTabs(),
            // Camera flip button
            _buildFooterButton(
              icon: Icons.flip_camera_ios,
              onTap: _switchCamera,
              enabled: _cameras != null && _cameras!.length > 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCaptureButton() {
    return Positioned(
      bottom: 120, // Reduced position to match smaller footer
      left: 0,
      right: 0,
      child: Center(child: _buildCaptureControls()),
    );
  }

  Widget _buildZoomIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${_currentZoom.toStringAsFixed(1)}x',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildZoomControls() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _maxZoom <= _minZoom) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final divisions = ((_maxZoom - _minZoom) * 10).round();

    return Positioned(
      right: 16,
      top: topPadding + 24,
      bottom: bottomPadding + 180,
      child: AnimatedOpacity(
        opacity: _isZoomOverlayVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                width: 160,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: _currentZoom.clamp(_minZoom, _maxZoom).toDouble(),
                    min: _minZoom,
                    max: _maxZoom,
                    divisions: divisions > 0 ? divisions : null,
                    onChanged: (value) => _updateZoom(value),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildZoomIndicator(),
          ],
        ),
      ),
    );
  }

  Future<void> _openGallery() async {
    if (_isGalleryOpening || _isCapturing || _isRecording) {
      return;
    }

    bool shouldRestoreState = true;

    if (mounted) {
      setState(() {
        _isGalleryOpening = true;
      });
    } else {
      _isGalleryOpening = true;
    }

    try {
      final pickedFiles = <XFile>[];
      final multiple = await _imagePicker.pickMultipleMedia();
      if (multiple.isNotEmpty) {
        pickedFiles.addAll(multiple);
      }

      if (pickedFiles.isEmpty) {
        final single = await _imagePicker.pickMedia();
        if (single != null) {
          pickedFiles.add(single);
        }
      }

      if (pickedFiles.isEmpty || !mounted) {
        return;
      }

      final mediaItems = <MediaItem>[];
      for (final file in pickedFiles) {
        var mediaItem = MediaItem.fromPath(file.path);
        if (mediaItem.isVideo) {
          final thumbnailPath = await VideoCompressionService.generateThumbnail(
            file.path,
          );
          if (thumbnailPath != null) {
            mediaItem = mediaItem.copyWith(thumbnailPath: thumbnailPath);
          }
        }
        mediaItems.add(mediaItem);
      }

      if (!mounted) {
        return;
      }

      final title = mediaItems.length == 1
          ? (mediaItems.first.isVideo ? 'Send Video' : 'Send Photo')
          : 'Send ${mediaItems.length} items';

      final result = await Navigator.push<List<MediaItem>>(
        context,
        MaterialPageRoute(
          builder: (context) => MediaCaptionScreen(
            mediaItems: mediaItems,
            title: title,
            onSend: (selectedMedia) {
              Navigator.of(context).pop(selectedMedia);
            },
          ),
          fullscreenDialog: true,
        ),
      );

      if (result != null && result.isNotEmpty) {
        shouldRestoreState = false;
        if (mounted) {
          setState(() {
            _isGalleryOpening = false;
          });
        } else {
          _isGalleryOpening = false;
        }

        Navigator.of(context).pop();
        widget.onMediaCaptured(result);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick media: $e');
    } finally {
      if (shouldRestoreState) {
        if (mounted) {
          setState(() {
            _isGalleryOpening = false;
          });
        } else {
          _isGalleryOpening = false;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Center(child: CircularProgressIndicator(color: Colors.white)),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              // Top bar with close and flash
              _buildTopBar(),
              // Camera preview (expanded to full remaining height)
              Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        onScaleEnd: _handleScaleEnd,
                        child: _buildCameraPreview(constraints),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // Footer tabs positioned as overlay at bottom
          _buildFloatingFooterTabs(),
          // Capture button positioned over camera preview
          _buildFloatingCaptureButton(),
          // Zoom controls overlay
          _buildZoomControls(),
        ],
      ),
    );
  }
}
