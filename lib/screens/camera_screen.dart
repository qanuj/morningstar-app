import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
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
  CaptureMode _currentMode = CaptureMode.photo;
  int _selectedCameraIndex = 0;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
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

      if (mounted) {
        setState(() {
          _isLoading = false;
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
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) {
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
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isRecording) {
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
    if (_cameraController == null || !_cameraController!.value.isInitialized || !_isRecording) {
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
        final thumbnailPath = await VideoCompressionService.generateThumbnail(filePath);
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
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleCameraMode() {
    setState(() {
      _currentMode = _currentMode == CaptureMode.photo
          ? CaptureMode.video
          : CaptureMode.photo;
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

  void _handleZoom(ScaleUpdateDetails details) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    final newZoom = (_currentZoom * details.scale).clamp(_minZoom, _maxZoom);
    _cameraController!.setZoomLevel(newZoom);
    setState(() {
      _currentZoom = newZoom;
    });
  }

  Widget _buildCameraPreview(BoxConstraints constraints) {
    final controller = _cameraController!;
    final aspectRatio = controller.value.aspectRatio;
    final maxWidth = constraints.maxWidth;
    final maxHeight = constraints.maxHeight;

    double previewWidth = maxWidth;
    double previewHeight = previewWidth / aspectRatio;

    if (previewHeight > maxHeight) {
      previewHeight = maxHeight;
      previewWidth = previewHeight * aspectRatio;
    }

    return SizedBox(
      width: previewWidth,
      height: previewHeight,
      child: ClipRect(
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
              if (_isRecording && _recordingDuration != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        _recordingDuration!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              if (_cameras != null && _cameras!.length > 1)
                IconButton(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (_currentMode != CaptureMode.photo) {
                _toggleCameraMode();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _currentMode == CaptureMode.photo
                    ? Colors.white
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'PHOTO',
                style: TextStyle(
                  color: _currentMode == CaptureMode.photo
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_currentMode != CaptureMode.video) {
                _toggleCameraMode();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _currentMode == CaptureMode.video
                    ? Colors.white
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'VIDEO',
                style: TextStyle(
                  color: _currentMode == CaptureMode.video
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(Icons.photo_library, color: Colors.white, size: 22),
        ),
        GestureDetector(
          onTap: _isCapturing ? null : _onCaptureButtonPressed,
          child: AnimatedBuilder(
            animation: _recordingAnimation,
            builder: (context, child) {
              return Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: _isRecording
                        ? 25 * _recordingAnimation.value
                        : _isCapturing
                            ? 40
                            : 50,
                    height: _isRecording
                        ? 25 * _recordingAnimation.value
                        : _isCapturing
                            ? 40
                            : 50,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red
                          : _currentMode == CaptureMode.video
                              ? Colors.red
                              : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: _isCapturing
                        ? const CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          )
                        : _isRecording
                            ? const Icon(Icons.stop, color: Colors.white, size: 16)
                            : null,
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: _cameras != null && _cameras!.length > 1 ? _switchCamera : null,
            icon: Icon(
              Icons.flip_camera_ios,
              color: _cameras != null && _cameras!.length > 1
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
              size: 20,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.2),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeToggle(),
            const SizedBox(height: 24),
            _buildCaptureControls(),
            const SizedBox(height: 8),
          ],
        ),
      ),
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





  @override
  Widget build(BuildContext context) {
    if (_isLoading || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            SafeArea(
              child: Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
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
          // Camera preview - full screen
          Positioned.fill(
            child: GestureDetector(
              onScaleUpdate: _handleZoom,
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            ),
          ),

          // Top controls
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  ),

                  // Recording duration
                  if (_isRecording && _recordingDuration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            _recordingDuration!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                  // Camera switch button
                  if (_cameras != null && _cameras!.length > 1)
                    IconButton(
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode toggle - more prominent
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_currentMode != CaptureMode.photo) {
                                _toggleCameraMode();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: _currentMode == CaptureMode.photo
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'PHOTO',
                                style: TextStyle(
                                  color: _currentMode == CaptureMode.photo
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (_currentMode != CaptureMode.video) {
                                _toggleCameraMode();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: _currentMode == CaptureMode.video
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'VIDEO',
                                style: TextStyle(
                                  color: _currentMode == CaptureMode.video
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Capture controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery button (left side)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(Icons.photo_library, color: Colors.white, size: 22),
                        ),

                        // Capture button (center)
                        GestureDetector(
                          onTap: _isCapturing ? null : _onCaptureButtonPressed,
                          child: AnimatedBuilder(
                            animation: _recordingAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: _isRecording
                                        ? 25 * _recordingAnimation.value
                                        : _isCapturing ? 40 : 50,
                                    height: _isRecording
                                        ? 25 * _recordingAnimation.value
                                        : _isCapturing ? 40 : 50,
                                    decoration: BoxDecoration(
                                      color: _isRecording
                                          ? Colors.red
                                          : _currentMode == CaptureMode.video
                                              ? Colors.red
                                              : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: _isCapturing
                                        ? const CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 2,
                                          )
                                        : _isRecording
                                            ? const Icon(Icons.stop, color: Colors.white, size: 16)
                                            : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Camera switch or settings (right side)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            onPressed: _switchCamera,
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // Zoom indicator
          if (_currentZoom > _minZoom)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
