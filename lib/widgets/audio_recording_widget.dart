import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:logger/logger.dart' show Level;

class AudioRecordingWidget extends StatefulWidget {
  final Function(String audioPath, Duration duration) onAudioRecorded;
  final bool isComposing;
  final VoidCallback? onRecordingStateChanged;

  const AudioRecordingWidget({
    super.key,
    required this.onAudioRecorded,
    required this.isComposing,
    this.onRecordingStateChanged,
  });

  @override
  AudioRecordingWidgetState createState() => AudioRecordingWidgetState();
}

class AudioRecordingWidgetState extends State<AudioRecordingWidget> {
  // Audio recording state
  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  File? _recordedAudioFile;
  String? _audioPath;
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder(
    logLevel: Level.fatal,
  );

  // Proper time tracking
  DateTime? _recordingStartTime;
  Duration _accumulatedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isPermanentlyDenied) {
        print('⚠️ Microphone permission is permanently denied');
      } else if (status.isDenied) {
        print('⚠️ Microphone permission is not granted');
      } else {
        print('✅ Microphone permission is granted');
      }
    } catch (e) {
      print('❌ Error checking microphone permission: $e');
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      await _audioRecorder.openRecorder();
    } catch (e) {
      print('Error initializing recorder: $e');
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    try {
      PermissionStatus permission = await Permission.microphone.status;

      if (permission.isDenied) {
        permission = await Permission.microphone.request();
      }

      if (permission.isPermanentlyDenied) {
        // Show dialog to open settings
        await _showPermissionDialog();
        return false;
      }

      return permission.isGranted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  Future<void> _showPermissionDialog() async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Microphone Permission Required'),
          content: Text(
            'This app needs microphone access to record audio messages. Please grant microphone permission in your device settings.',
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording || _hasRecording) return;

    // Check microphone permission first
    bool hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      print('❌ Microphone permission denied. Cannot start recording.');
      return;
    }

    // Reset time tracking immediately at the start
    _recordingDuration = Duration.zero;
    _accumulatedDuration = Duration.zero;
    _recordingStartTime = null;

    try {
      // Ensure recorder is opened
      try {
        await _audioRecorder.openRecorder();
      } catch (e) {
        // Recorder might already be opened
      }

      // Create audio file path
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _audioPath = '${directory.path}/$fileName';

      // Start recording
      await _audioRecorder.startRecorder(
        toFile: _audioPath!,
        codec: Codec.aacMP4,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;
        _accumulatedDuration = Duration.zero;
      });

      // Record the start time
      _recordingStartTime = DateTime.now();

      // Notify parent of state change
      widget.onRecordingStateChanged?.call();

      // Start the timer to track recording duration
      _recordingTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
        if (_recordingStartTime != null && mounted) {
          final currentTime = DateTime.now();
          final elapsed = currentTime.difference(_recordingStartTime!);
          final newDuration = _accumulatedDuration + elapsed;

          // Only update if the second has changed to reduce flickering
          if (newDuration.inSeconds != _recordingDuration.inSeconds) {
            setState(() {
              _recordingDuration = newDuration;
            });
          }
        }
      });

      HapticFeedback.mediumImpact();
      print('✅ Recording started successfully to: $_audioPath');
    } catch (e) {
      print('❌ Error starting recording: $e');
      setState(() {
        _isRecording = false;
      });

      // Provide specific error messages for common issues
      String errorMessage = 'Failed to start recording.';
      if (e.toString().contains('permission')) {
        errorMessage = 'Microphone permission is required to record audio.';
      } else if (e.toString().contains('busy') || e.toString().contains('occupied')) {
        errorMessage = 'Microphone is being used by another app. Please close other apps and try again.';
      } else if (e.toString().contains('audio session')) {
        errorMessage = 'Audio recording is not available. Please restart the app and try again.';
      }

      _showErrorDialog(errorMessage);
    }
  }

  Future<void> _pauseResumeRecording() async {
    if (!_isRecording) return;

    try {
      if (_isPaused) {
        // Resume recording
        await _audioRecorder.resumeRecorder();

        // Update accumulated duration and reset start time
        _accumulatedDuration = _recordingDuration;
        _recordingStartTime = DateTime.now();

        // Restart timer
        _recordingTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
          if (_recordingStartTime != null && mounted) {
            final currentTime = DateTime.now();
            final elapsed = currentTime.difference(_recordingStartTime!);
            final newDuration = _accumulatedDuration + elapsed;

            // Only update if the second has changed to reduce flickering
            if (newDuration.inSeconds != _recordingDuration.inSeconds) {
              setState(() {
                _recordingDuration = newDuration;
              });
            }
          }
        });

        setState(() {
          _isPaused = false;
        });
        HapticFeedback.lightImpact();
      } else {
        // Pause recording
        await _audioRecorder.pauseRecorder();
        _recordingTimer?.cancel();

        // Save the current duration as accumulated
        _accumulatedDuration = _recordingDuration;

        setState(() {
          _isPaused = true;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('Error pausing/resuming recording: $e');
      _showErrorDialog('Failed to pause/resume recording. Please try again.');
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stopRecorder();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      // Notify parent of state change
      widget.onRecordingStateChanged?.call();

      HapticFeedback.lightImpact();

      if (path != null && path.isNotEmpty) {
        // Check file details
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('Recording stopped and sending:');
          print('  Path: $path');
          print('  Duration: ${_formatRecordingDuration(_recordingDuration)}');
          print('  File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

          // Send immediately
          widget.onAudioRecorded(path, _recordingDuration);

          // Reset state
          setState(() {
            _recordingDuration = Duration.zero;
          });
        }
      }
    } catch (e) {
      print('Error stopping and sending recording: $e');
      _showErrorDialog('Failed to send recording. Please try again.');
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.stopRecorder();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingDuration = Duration.zero;
        _accumulatedDuration = Duration.zero;
      });

      _recordingStartTime = null;

      // Notify parent of state change
      widget.onRecordingStateChanged?.call();

      HapticFeedback.selectionClick();

      // Delete the recorded file if it exists
      if (_audioPath != null) {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
          print('Recording cancelled and file deleted');
        }
        _audioPath = null;
      }
    } catch (e) {
      print('Error cancelling recording: $e');
      _showErrorDialog('Failed to cancel recording. Please try again.');
    }
  }

  void _deleteRecording() {
    setState(() {
      _hasRecording = false;
      _recordingDuration = Duration.zero;
      _recordedAudioFile = null;
      _accumulatedDuration = Duration.zero;
    });

    _recordingStartTime = null;

    // Notify parent of state change
    widget.onRecordingStateChanged?.call();

    HapticFeedback.selectionClick();

    // TODO: Delete the recorded file
    print('Recording deleted');
  }

  void _sendAudioRecording() async {
    if (!_hasRecording || _recordedAudioFile == null) return;

    final audioFile = _recordedAudioFile!;
    final duration = _recordingDuration;

    // Reset recording state
    setState(() {
      _hasRecording = false;
      _recordingDuration = Duration.zero;
      _recordedAudioFile = null;
      _accumulatedDuration = Duration.zero;
    });

    _recordingStartTime = null;

    // Notify parent of state change
    widget.onRecordingStateChanged?.call();

    HapticFeedback.lightImpact();

    // Call the callback to send the audio message
    widget.onAudioRecorded(audioFile.path, duration);

    print(
      'Audio message sent. Duration: ${_formatRecordingDuration(duration)}',
    );
  }

  String _formatRecordingDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    // Return different layouts based on recording state
    if (_isRecording) {
      // Full-width recording interface
      return Expanded(
        child: Container(
          height: 48,
          margin: EdgeInsets.symmetric(horizontal: 8),
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.red.withOpacity(0.15)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.red.withOpacity(0.4)
                  : Colors.red.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              // Delete/Cancel button
              IconButton(
                onPressed: _cancelRecording,
                icon: Icon(
                  Icons.delete,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.red[400]
                      : Colors.red,
                ),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              SizedBox(width: 8),
              // Recording icon
              Icon(
                _isPaused ? Icons.pause : Icons.fiber_manual_record,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red[400]
                    : Colors.red,
                size: 16,
              ),
              SizedBox(width: 12),
              // Duration text
              Expanded(
                child: Text(
                  _isPaused
                      ? 'Paused ${_formatRecordingDuration(_recordingDuration)}'
                      : 'Recording... ${_formatRecordingDuration(_recordingDuration)}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red[400]
                        : Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              // Pause/Resume button
              IconButton(
                onPressed: _pauseResumeRecording,
                icon: Icon(
                  _isPaused ? Icons.mic : Icons.pause,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange[400]
                      : Colors.orange,
                ),
                iconSize: 28,
              ),
              // Send button
              IconButton(
                onPressed: _stopAndSendRecording,
                icon: Icon(
                  Icons.send,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF4dd0ff) // Lighter blue for dark mode
                      : Color(0xFF003f9b), // Primary blue for light mode
                ),
                iconSize: 28,
              ),
            ],
          ),
        ),
      );
    } else if (_hasRecording) {
      // Full-width recorded audio interface
      return Expanded(
        child: Container(
          height: 48,
          margin: EdgeInsets.symmetric(horizontal: 8),
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).primaryColor.withOpacity(0.15)
                : Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).primaryColor.withOpacity(0.4)
                  : Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              // Delete button
              IconButton(
                onPressed: _deleteRecording,
                icon: Icon(
                  Icons.delete,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.red[400]
                      : Colors.red,
                ),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              SizedBox(width: 8),
              // Audio icon and duration
              Icon(
                Icons.mic,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).primaryColor.withOpacity(0.8)
                    : Theme.of(context).primaryColor,
                size: 16,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audio recorded (${_formatRecordingDuration(_recordingDuration)})',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).primaryColor.withOpacity(0.9)
                        : Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              // Send button
              IconButton(
                onPressed: _sendAudioRecording,
                icon: Icon(
                  Icons.send,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).primaryColor.withOpacity(0.9)
                      : Theme.of(context).primaryColor,
                ),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      );
    } else {
      // Normal mic button
      return IconButton(
        onPressed: widget.isComposing
            ? null // Let parent handle send message
            : _startVoiceRecording,
        icon: Icon(
          widget.isComposing ? Icons.send : Icons.mic,
          color: widget.isComposing
              ? Color(0xFF003f9b)
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600]),
        ),
        iconSize: 28,
      );
    }
  }

  // Getters to expose state to parent
  bool get isRecording => _isRecording;
  bool get hasRecording => _hasRecording;
  Duration get recordingDuration => _recordingDuration;

  // Method to get hint text for input field
  String getHintText(String defaultHint) {
    if (_isRecording) {
      return 'Recording... ${_formatRecordingDuration(_recordingDuration)}';
    } else if (_hasRecording) {
      return 'Audio recorded';
    } else {
      return defaultHint;
    }
  }

  // Method to check if input should be enabled
  bool get shouldEnableInput => !_isRecording && !_hasRecording;

  // Public method to start recording programmatically
  Future<void> startRecordingProgrammatically() async {
    if (!_isRecording && !_hasRecording) {
      await _startVoiceRecording();
    }
  }
}
