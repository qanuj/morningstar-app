import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import 'base_message_bubble.dart';
import 'audio_upload_states.dart';

/// Audio message bubble - shows audio player with speed controls and playback
class AudioMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final VoidCallback? onRetryUpload;
  final Function(String messageId, String emoji, String userId)?
  onReactionRemoved;

  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
    this.showSenderInfo = false,
    this.onRetryUpload,
    this.onReactionRemoved,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  AudioPlayer? _audioPlayer;
  bool isPlaying = false;
  double playbackSpeed = 1.0;
  double currentPosition = 0.0; // 0.0 to 1.0
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    print('AudioMessageBubble initState called');
    _initializeAudioPlayer();
    print('After _initializeAudioPlayer call, _isInitialized: $_isInitialized');
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _initializeAudioPlayer() {
    try {
      _audioPlayer = AudioPlayer();

      // Listen to player state changes
      _playerStateSubscription = _audioPlayer!.onPlayerStateChanged.listen((
        state,
      ) {
        if (mounted) {
          setState(() {
            isPlaying = state == PlayerState.playing;
            // Reset position when playback completes
            if (state == PlayerState.completed) {
              currentPosition = 0.0;
              _currentDuration = Duration.zero;
            }
          });
        }
      });

      // Listen to position changes
      _positionSubscription = _audioPlayer!.onPositionChanged.listen((
        position,
      ) {
        if (mounted) {
          setState(() {
            _currentDuration = position;
            if (_totalDuration.inMilliseconds > 0) {
              currentPosition =
                  position.inMilliseconds / _totalDuration.inMilliseconds;
            }
          });
        }
      });

      // Listen to duration changes
      _durationSubscription = _audioPlayer!.onDurationChanged.listen((
        duration,
      ) {
        if (mounted) {
          setState(() {
            _totalDuration = duration;
          });
        }
      });

      _isInitialized = true;

      // Load audio file if available (async)
      if (widget.message.audio?.url.isNotEmpty == true) {
        _loadAudioFile();
      }
    } catch (e) {
      _isInitialized = false;
    }
  }

  Future<void> _loadAudioFile() async {
    if (_audioPlayer == null || !_isInitialized) return;

    try {
      await _audioPlayer!.setSource(UrlSource(widget.message.audio!.url));
      await _audioPlayer!.setPlaybackRate(playbackSpeed);
    } catch (e) {
      print('Error loading audio file: $e');
    }
  }

  Color _getIconColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white.withOpacity(0.8) : Colors.black87;
  }

  Color _getDotColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white.withOpacity(0.3) : Colors.black26;
  }

  Color _getSpeedBgColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withOpacity(0.2)
        : Colors.black.withOpacity(0.3);
  }

  Color _getDurationColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white.withOpacity(0.9) : Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: widget.message,
      isOwn: widget.isOwn,
      isPinned: widget.isPinned,
      isSelected: widget.isSelected,
      isTransparent: true, // Remove background, make transparent
      showMetaOverlay: true, // Ensure meta overlay is shown
      overlayBottomPosition: 18, // Position overlay higher up inside container
      content: _buildContent(context),
      onReactionRemoved: widget.onReactionRemoved,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.message.audio == null) {
      return _buildErrorState(context);
    }

    // Handle upload states
    switch (widget.message.status) {
      case MessageStatus.sending:
        return AudioUploadStates.buildUploadingState(
          context,
          getIconColor: _getIconColor,
          getDotColor: _getDotColor,
          getDurationColor: _getDurationColor,
        );
      case MessageStatus.failed:
        return AudioUploadStates.buildUploadFailedState(
          context,
          errorMessage: widget.message.errorMessage,
          onRetry: widget.onRetryUpload,
          getDurationColor: _getDurationColor,
        );
      default:
        break;
    }

    // Normal audio playback interface

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
        minWidth: 280,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isOwn
            ? Theme.of(context).primaryColorLight
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: widget.isOwn
                ? [
                    // For own messages: Avatar/Speed first, then Play/Progress
                    Column(
                      children: [
                        _AvatarSpeedToggle(
                          isPlaying: isPlaying,
                          playbackSpeed: playbackSpeed,
                          senderProfilePicture:
                              widget.message.senderProfilePicture,
                          onSpeedTap: _togglePlaybackSpeed,
                          getIconColor: _getIconColor,
                          getSpeedBgColor: _getSpeedBgColor,
                        ),
                        SizedBox(height: 8),
                        Text(
                          isPlaying
                              ? _formatDuration(_currentDuration.inSeconds)
                              : _formatDuration(
                                  _totalDuration.inSeconds > 0
                                      ? _totalDuration.inSeconds
                                      : widget.message.audio?.duration ?? 0,
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getDurationColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(width: 12),

                    Expanded(
                      child: _PlayProgressControls(
                        isPlaying: isPlaying,
                        currentPosition: currentPosition,
                        onPlayPauseTap: _togglePlayPause,
                        onSeekTap: _seekToPosition,
                        getIconColor: _getIconColor,
                        getDotColor: _getDotColor,
                      ),
                    ),
                  ]
                : [
                    // For received messages: Play/Progress first, then Avatar/Speed
                    Expanded(
                      child: _PlayProgressControls(
                        isPlaying: isPlaying,
                        currentPosition: currentPosition,
                        onPlayPauseTap: _togglePlayPause,
                        onSeekTap: _seekToPosition,
                        getIconColor: _getIconColor,
                        getDotColor: _getDotColor,
                      ),
                    ),

                    SizedBox(width: 12),

                    _AvatarSpeedToggle(
                      isPlaying: isPlaying,
                      playbackSpeed: playbackSpeed,
                      senderProfilePicture: widget.message.senderProfilePicture,
                      onSpeedTap: _togglePlaybackSpeed,
                      getIconColor: _getIconColor,
                      getSpeedBgColor: _getSpeedBgColor,
                    ),
                  ],
          ),

          // Duration for received messages (below play controls)
          if (!widget.isOwn) ...[
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                ), // Align with center of play button
                child: Text(
                  isPlaying
                      ? _formatDuration(_currentDuration.inSeconds)
                      : _formatDuration(
                          _totalDuration.inSeconds > 0
                              ? _totalDuration.inSeconds
                              : widget.message.audio?.duration ?? 0,
                        ),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getDurationColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer == null || !_isInitialized) {
      print('Audio player not initialized');
      return;
    }

    try {
      if (isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.resume();
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
  }

  Future<void> _togglePlaybackSpeed() async {
    if (_audioPlayer == null || !_isInitialized) {
      print('Audio player not initialized');
      return;
    }

    setState(() {
      switch (playbackSpeed) {
        case 1.0:
          playbackSpeed = 1.5;
          break;
        case 1.5:
          playbackSpeed = 2.0;
          break;
        case 2.0:
          playbackSpeed = 1.0;
          break;
        default:
          playbackSpeed = 1.0;
      }
    });

    // Update audio player speed
    try {
      await _audioPlayer!.setPlaybackRate(playbackSpeed);
    } catch (e) {
      print('Error setting playback speed: $e');
    }
  }

  Future<void> _seekToPosition(TapDownDetails details) async {
    if (_audioPlayer == null || !_isInitialized) {
      print('Audio player not initialized');
      return;
    }

    // Get the progress bar widget's render box
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    // Calculate relative position within the available width
    final progressBarX =
        localPosition.dx -
        56; // Account for profile/speed + play button + margins
    final availableWidth =
        renderBox.size.width -
        56 -
        12; // Total minus left elements minus right margin

    if (progressBarX >= 0 && availableWidth > 0) {
      final newPosition = (progressBarX / availableWidth).clamp(0.0, 1.0);
      final seekDuration = Duration(
        milliseconds: (_totalDuration.inMilliseconds * newPosition).round(),
      );

      try {
        await _audioPlayer!.seek(seekDuration);
      } catch (e) {
        print('Error seeking audio: $e');
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text(
            'Audio not available',
            style: TextStyle(fontSize: 14, color: _getIconColor(context)),
          ),
        ],
      ),
    );
  }
}

/// Private widget that toggles between avatar and speed control
class _AvatarSpeedToggle extends StatelessWidget {
  final bool isPlaying;
  final double playbackSpeed;
  final String? senderProfilePicture;
  final Future<void> Function() onSpeedTap;
  final Color Function(BuildContext) getIconColor;
  final Color Function(BuildContext) getSpeedBgColor;

  const _AvatarSpeedToggle({
    required this.isPlaying,
    required this.playbackSpeed,
    required this.senderProfilePicture,
    required this.onSpeedTap,
    required this.getIconColor,
    required this.getSpeedBgColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPlaying) {
      // Show avatar when not playing
      return Stack(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]
                  : Colors.grey[300],
              image: senderProfilePicture != null
                  ? DecorationImage(
                      image: NetworkImage(senderProfilePicture!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: senderProfilePicture == null
                ? Icon(
                    Icons.person,
                    size: 20,
                    color: getIconColor(context).withOpacity(0.6),
                  )
                : null,
          ),
          // Microphone badge
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Theme.of(context).primaryColor,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]!
                      : Colors.white,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.mic,
                size: 8,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).primaryColor
                    : Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Show speed control when playing
    return GestureDetector(
      onTap: () => onSpeedTap(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: getSpeedBgColor(context),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${playbackSpeed}x',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Private widget that handles play button and progress bar
class _PlayProgressControls extends StatelessWidget {
  final bool isPlaying;
  final double currentPosition;
  final Future<void> Function() onPlayPauseTap;
  final Future<void> Function(TapDownDetails) onSeekTap;
  final Color Function(BuildContext) getIconColor;
  final Color Function(BuildContext) getDotColor;

  const _PlayProgressControls({
    required this.isPlaying,
    required this.currentPosition,
    required this.onPlayPauseTap,
    required this.onSeekTap,
    required this.getIconColor,
    required this.getDotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: () => onPlayPauseTap(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: getIconColor(context),
                size: 28,
              ),
            ),
          ),

          SizedBox(width: 12),

          // Progress bar with dots
          Expanded(
            child: GestureDetector(
              onTapDown: (details) => onSeekTap(details),
              child: Container(
                height: 20,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final dotCount = (availableWidth / 5)
                        .floor(); // 3px dot + 2px margin

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background dots
                        Row(
                          children: List.generate(dotCount, (index) {
                            return Container(
                              width: 3,
                              height: 3,
                              margin: EdgeInsets.only(
                                right: index < dotCount - 1 ? 2 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: getDotColor(context),
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),

                        // Progress indicator (black circle)
                        Positioned(
                          left:
                              currentPosition *
                              (availableWidth - 12), // Subtract circle width
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: getIconColor(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
