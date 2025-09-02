import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

class AudioRecordingWidget extends StatefulWidget {
  final Function(String audioPath, Duration duration) onAudioRecorded;
  final bool isComposing;
  final VoidCallback? onRecordingStateChanged;

  const AudioRecordingWidget({
    Key? key,
    required this.onAudioRecorded,
    required this.isComposing,
    this.onRecordingStateChanged,
  }) : super(key: key);

  @override
  AudioRecordingWidgetState createState() => AudioRecordingWidgetState();
}

class AudioRecordingWidgetState extends State<AudioRecordingWidget> {
  // Audio recording state
  bool _isRecording = false;
  bool _hasRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  File? _recordedAudioFile;
  String? _audioPath;
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    try {
      await _audioRecorder.openRecorder();
    } catch (e) {
      print('Error initializing recorder: $e');
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording || _hasRecording) return;

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
        _recordingDuration = Duration.zero;
      });

      // Notify parent of state change
      widget.onRecordingStateChanged?.call();

      // Start the timer to track recording duration
      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      });

      HapticFeedback.mediumImpact();
      print('Recording started successfully to: $_audioPath');
    } catch (e) {
      print('Error starting recording: $e');
      setState(() {
        _isRecording = false;
      });
      _showErrorDialog('Failed to start recording: ${e.toString()}');
    }
  }

  Future<void> _stopVoiceRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stopRecorder();

      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
        _hasRecording = true;
        if (path != null && path.isNotEmpty) {
          _recordedAudioFile = File(path);
          _audioPath = path;
        }
      });

      // Notify parent of state change
      widget.onRecordingStateChanged?.call();

      HapticFeedback.lightImpact();

      if (path != null && path.isNotEmpty) {
        // Check file details
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('Recording stopped successfully:');
          print('  Path: $path');
          print('  Duration: ${_formatRecordingDuration(_recordingDuration)}');
          print('  File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _showErrorDialog('Failed to stop recording. Please try again.');
    }
  }

  void _deleteRecording() {
    setState(() {
      _hasRecording = false;
      _recordingDuration = Duration.zero;
      _recordedAudioFile = null;
    });

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
    });

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
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              // Recording icon
              Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
              SizedBox(width: 12),
              // Duration text
              Expanded(
                child: Text(
                  'Recording... ${_formatRecordingDuration(_recordingDuration)}',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              // Stop button
              IconButton(
                onPressed: _stopVoiceRecording,
                icon: Icon(Icons.stop, color: Colors.red),
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
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              // Delete button
              IconButton(
                onPressed: _deleteRecording,
                icon: Icon(Icons.delete, color: Colors.red),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              SizedBox(width: 8),
              // Audio icon and duration
              Icon(Icons.mic, color: Theme.of(context).primaryColor, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audio recorded (${_formatRecordingDuration(_recordingDuration)})',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              // Send button
              IconButton(
                onPressed: _sendAudioRecording,
                icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
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
}
