import 'package:flutter/material.dart';
import 'dart:async';
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
  final VoidCallback? onRetryUpload;

  const AudioMessageBubble({
    Key? key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
    this.onRetryUpload,
  }) : super(key: key);

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  bool isPlaying = false;
  double playbackSpeed = 1.0;
  double currentPosition = 0.0; // 0.0 to 1.0
  Timer? _progressTimer;
  int _currentSeconds = 0;

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
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
      content: _buildContent(context),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: widget.isOwn
                ? [
                    // For own messages: Avatar/Speed first, then Play/Progress
                    _AvatarSpeedToggle(
                      isPlaying: isPlaying,
                      playbackSpeed: playbackSpeed,
                      senderProfilePicture: widget.message.senderProfilePicture,
                      onSpeedTap: _togglePlaybackSpeed,
                      getIconColor: _getIconColor,
                      getSpeedBgColor: _getSpeedBgColor,
                    ),

                    SizedBox(width: 12),

                    _PlayProgressControls(
                      isPlaying: isPlaying,
                      currentPosition: currentPosition,
                      onPlayPauseTap: _togglePlayPause,
                      onSeekTap: _seekToPosition,
                      getIconColor: _getIconColor,
                      getDotColor: _getDotColor,
                    ),
                  ]
                : [
                    // For received messages: Play/Progress first, then Avatar/Speed
                    _PlayProgressControls(
                      isPlaying: isPlaying,
                      currentPosition: currentPosition,
                      onPlayPauseTap: _togglePlayPause,
                      onSeekTap: _seekToPosition,
                      getIconColor: _getIconColor,
                      getDotColor: _getDotColor,
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

          SizedBox(height: 8),

          // Duration
          Row(
            children: [
              Text(
                isPlaying
                    ? _formatDuration(_currentSeconds)
                    : _formatDuration(widget.message.audio!.duration ?? 0),
                style: TextStyle(
                  fontSize: 12,
                  color: _getDurationColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    setState(() {
      isPlaying = !isPlaying;
    });

    if (isPlaying) {
      _startProgressTimer();
    } else {
      _stopProgressTimer();
    }
  }

  void _startProgressTimer() {
    final totalDuration = widget.message.audio?.duration ?? 60;

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      Duration(milliseconds: (1000 / playbackSpeed).round()),
      (timer) {
        if (_currentSeconds >= totalDuration) {
          // Audio finished
          setState(() {
            isPlaying = false;
            currentPosition = 0.0;
            _currentSeconds = 0;
          });
          timer.cancel();
          return;
        }

        setState(() {
          _currentSeconds++;
          currentPosition = _currentSeconds / totalDuration;
        });
      },
    );
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
  }

  void _togglePlaybackSpeed() {
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

    // Restart timer with new speed if playing
    if (isPlaying) {
      _startProgressTimer();
    }
  }

  void _seekToPosition(TapDownDetails details) {
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
      final totalDuration = widget.message.audio?.duration ?? 60;

      setState(() {
        currentPosition = newPosition;
        _currentSeconds = (newPosition * totalDuration).round();
      });

      // Restart timer if playing to continue from new position
      if (isPlaying) {
        _startProgressTimer();
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
  final VoidCallback onSpeedTap;
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
      return Container(
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
      );
    }

    // Show speed control when playing
    return GestureDetector(
      onTap: onSpeedTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: getSpeedBgColor(context),
          borderRadius: BorderRadius.circular(12),
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
  final VoidCallback onPlayPauseTap;
  final void Function(TapDownDetails) onSeekTap;
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
            onTap: onPlayPauseTap,
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
                size: 24,
              ),
            ),
          ),

          SizedBox(width: 12),

          // Progress bar with dots
          Expanded(
            child: GestureDetector(
              onTapDown: onSeekTap,
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
