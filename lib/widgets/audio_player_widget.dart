import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final bool isFromCurrentUser;

  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
    this.isFromCurrentUser = false,
  });

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudioPlayer();
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializeAudioPlayer() async {
    try {
      _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() => _duration = duration);
        }
      });

      _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });

      _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
          _waveController.stop();
          _waveController.reset();
        }
      });

      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = state == PlayerState.playing && _position == Duration.zero;
          });
        }
      });

      // Load the audio file to get duration
      await _audioPlayer.setSourceDeviceFile(widget.audioPath);
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  Future<void> _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        _waveController.stop();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.resume();
        _waveController.repeat();
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Error playing/pausing audio: $e');
      // Show error to user if needed
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _waveController.dispose();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = widget.isFromCurrentUser 
        ? Color(0xFF003f9b) 
        : (isDarkMode ? Colors.grey[700] : Colors.grey[300]);
    final textColor = widget.isFromCurrentUser 
        ? Colors.white 
        : (isDarkMode ? Colors.white : Colors.black87);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _playPause,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor!),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: textColor,
                      size: 24,
                    ),
            ),
          ),

          SizedBox(width: 12),

          // Waveform visualization
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated waveform bars
                AnimatedBuilder(
                  animation: _waveAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 30,
                      child: Row(
                        children: List.generate(20, (index) {
                          final progress = _duration.inMilliseconds > 0
                              ? _position.inMilliseconds / _duration.inMilliseconds
                              : 0.0;
                          final isActive = (index / 20) <= progress;
                          final height = _isPlaying
                              ? 4.0 + (index % 4 + 1) * 4.0 + 
                                (_waveAnimation.value * 8.0 * ((index % 3) + 1))
                              : 4.0 + (index % 4 + 1) * 4.0;

                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 1),
                              height: height.clamp(4.0, 30.0),
                              decoration: BoxDecoration(
                                color: isActive 
                                    ? textColor!.withOpacity(0.9)
                                    : textColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),

                SizedBox(height: 4),

                // Duration display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        color: textColor!.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(width: 8),

          // Voice message icon
          Icon(
            Icons.mic,
            color: textColor.withOpacity(0.7),
            size: 18,
          ),
        ],
      ),
    );
  }
}