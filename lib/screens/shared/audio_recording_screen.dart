import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

class AudioRecordingScreen extends StatefulWidget {
  final Function(String audioPath) onAudioRecorded;

  const AudioRecordingScreen({
    Key? key,
    required this.onAudioRecorded,
  }) : super(key: key);

  @override
  _AudioRecordingScreenState createState() => _AudioRecordingScreenState();
}

class _AudioRecordingScreenState extends State<AudioRecordingScreen>
    with TickerProviderStateMixin {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  String? _audioPath;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    try {
      await _audioRecorder.openRecorder();
    } catch (e) {
      print('Error initializing recorder: $e');
      _showErrorDialog('Failed to initialize audio recorder. Please restart the app.');
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Microphone Permission Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_off,
              size: 48,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'This app needs microphone access to record voice messages.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Please grant permission to continue.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Also close the recording screen
              }
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted) Navigator.of(context).pop();
              
              // Try requesting permission again
              final newStatus = await Permission.microphone.request();
              if (newStatus.isGranted) {
                _startRecording();
              } else if (newStatus.isPermanentlyDenied) {
                _showPermissionPermanentlyDeniedDialog();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF003f9b),
            ),
            child: Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permission Permanently Denied'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_off,
              size: 48,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'Microphone access has been permanently denied. Please enable it manually in Settings.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Settings > Privacy & Security > Microphone > Duggy',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Also close the recording screen
              }
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted) Navigator.of(context).pop();
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF003f9b),
            ),
            child: Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      // Ensure recorder is opened
      try {
        await _audioRecorder.openRecorder();
      } catch (e) {
        // Recorder might already be opened
      }
      
      // On iOS, attempting to start recording will trigger permission dialog if needed
      // Check permission status first
      final initialStatus = await Permission.microphone.status;
      
      // If permission is not granted, try to start recording which should trigger iOS system dialog
      if (!initialStatus.isGranted) {
        // Try to start recording briefly to trigger iOS permission dialog
        try {
          final directory = await getApplicationDocumentsDirectory();
          final tempPath = '${directory.path}/temp_permission_test.m4a';
          
          await _audioRecorder.startRecorder(
            toFile: tempPath,
            codec: Codec.aacMP4,
          );
          
          // Stop immediately - this was just to trigger permission
          await _audioRecorder.stopRecorder();
          
          // Clean up temp file
          final tempFile = File(tempPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          
        } catch (e) {
          // Permission was denied
          final newStatus = await Permission.microphone.status;
          
          if (newStatus.isPermanentlyDenied) {
            _showPermissionPermanentlyDeniedDialog();
          } else {
            _showPermissionDeniedDialog();
          }
          return;
        }
      }

      // Create audio file path
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _audioPath = '${directory.path}/$fileName';

      // Start recording
      await _audioRecorder.startRecorder(
        toFile: _audioPath!,
        codec: Codec.aacMP4, // Explicitly specify codec
      );

      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      _startTimer();
      _pulseController.repeat(reverse: true);
      
      print('Recording started successfully');
    } catch (e) {
      print('Error starting recording: $e');
      setState(() {
        _isRecording = false;
      });
      _showErrorDialog('Failed to start recording: ${e.toString()}');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pauseRecorder();
      
      setState(() {
        _isPaused = true;
      });

      _timer?.cancel();
      _pulseController.stop();
      _pulseController.reset();

      print('Recording paused');
    } catch (e) {
      print('Error pausing recording: $e');
      _showErrorDialog('Failed to pause recording. Please try again.');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resumeRecorder();
      
      setState(() {
        _isPaused = false;
      });

      _startTimer();
      _pulseController.repeat(reverse: true);

      print('Recording resumed');
    } catch (e) {
      print('Error resuming recording: $e');
      _showErrorDialog('Failed to resume recording. Please try again.');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stopRecorder();
      
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      _timer?.cancel();
      _pulseController.stop();

      if (path != null && path.isNotEmpty) {
        // Debug: Print audio file information
        print('Audio recording completed:');
        print('  Path: $path');
        
        // Check file details
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          final fileName = path.split('/').last;
          final fileExtension = path.split('.').last;
          
          print('  File name: $fileName');
          print('  File extension: $fileExtension');
          print('  File size: ${fileSize} bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)');
          print('  Content type: audio/${fileExtension == 'm4a' ? 'mp4' : fileExtension}');
        }
        
        widget.onAudioRecorded(path);
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _showErrorDialog('Failed to stop recording. Please try again.');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stopRecorder();
      
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordDuration = Duration.zero;
      });

      _timer?.cancel();
      _pulseController.stop();

      // Delete the recorded file
      if (_audioPath != null) {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      Navigator.of(context).pop();
    } catch (e) {
      print('Error canceling recording: $e');
      Navigator.of(context).pop();
    }
  }

  void _startTimer() {
    final startTime = DateTime.now().subtract(_recordDuration);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration = DateTime.now().difference(startTime);
      });
    });
  }



  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: _cancelRecording,
        ),
        title: Text(
          !_isRecording 
            ? 'Voice Message' 
            : _isPaused 
              ? 'Recording Paused' 
              : 'Recording...',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Duration display
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Text(
                        _formatDuration(_recordDuration),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2,
                        ),
                      ),
                    ),

                  // Microphone button
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Main microphone button
                      AnimatedBuilder(
                        animation: (_isRecording && !_isPaused) ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: GestureDetector(
                              onTap: () {
                                if (!_isRecording) {
                                  _startRecording();
                                } else if (_isPaused) {
                                  _resumeRecording();
                                } else {
                                  _pauseRecording();
                                }
                              },
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: !_isRecording 
                                    ? Color(0xFF003f9b)
                                    : _isPaused 
                                      ? Color(0xFF16a34a)
                                      : Color(0xFF06aeef),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (!_isRecording 
                                        ? Color(0xFF003f9b)
                                        : _isPaused 
                                          ? Color(0xFF16a34a)
                                          : Color(0xFF06aeef))
                                          .withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  !_isRecording 
                                    ? Icons.mic
                                    : _isPaused 
                                      ? Icons.play_arrow
                                      : Icons.pause,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Instructions
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      !_isRecording
                          ? 'Tap to start recording'
                          : _isPaused
                              ? 'Tap to resume recording'
                              : 'Tap to pause recording',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),

          // Bottom controls
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  GestureDetector(
                    onTap: _cancelRecording,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  
                  // Stop button (to complete recording)
                  GestureDetector(
                    onTap: _stopRecording,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: Icon(
                        Icons.stop,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}