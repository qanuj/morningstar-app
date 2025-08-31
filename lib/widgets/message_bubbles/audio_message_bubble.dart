import 'package:flutter/material.dart';
import '../../models/club_message.dart';
import 'base_message_bubble.dart';

/// Audio message bubble - shows audio player with speed controls and playback
class AudioMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;

  const AudioMessageBubble({
    Key? key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    this.isSelected = false,
  }) : super(key: key);

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  bool isPlaying = false;
  double playbackSpeed = 1.0;
  double currentPosition = 0.0; // 0.0 to 1.0

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

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
        minWidth: 280,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Show sender picture when not playing, speed control when playing
              if (!isPlaying) ...[
                // Profile picture (sender avatar)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                    image: widget.message.senderProfilePicture != null
                        ? DecorationImage(
                            image: NetworkImage(widget.message.senderProfilePicture!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.message.senderProfilePicture == null
                      ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                      : null,
                ),
              ] else ...[
                // Speed control button (only when playing)
                GestureDetector(
                  onTap: _togglePlaybackSpeed,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
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
                ),
              ],
              
              SizedBox(width: 12),
              
              // Play/Pause button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black87,
                    size: 24,
                  ),
                ),
              ),
              
              SizedBox(width: 12),
              
              // Progress bar with dots
              Expanded(
                child: GestureDetector(
                  onTapDown: (details) => _seekToPosition(details),
                  child: Container(
                    height: 20,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        final dotCount = (availableWidth / 5).floor(); // 3px dot + 2px margin
                        
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // Background dots
                            Row(
                              children: List.generate(dotCount, (index) {
                                return Container(
                                  width: 3,
                                  height: 3,
                                  margin: EdgeInsets.only(right: index < dotCount - 1 ? 2 : 0),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }),
                            ),
                            
                            // Progress indicator (black circle)
                            Positioned(
                              left: currentPosition * (availableWidth - 12), // Subtract circle width
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.black87,
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
          
          SizedBox(height: 8),
          
          // Duration
          Row(
            children: [
              Text(
                _formatDuration(widget.message.audio!.duration ?? 0),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
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
    // TODO: Implement actual audio playback control
  }

  void _togglePlaybackSpeed() {
    setState(() {
      switch (playbackSpeed) {
        case 1.0:
          playbackSpeed = 1.25;
          break;
        case 1.25:
          playbackSpeed = 1.5;
          break;
        case 1.5:
          playbackSpeed = 1.75;
          break;
        case 1.75:
          playbackSpeed = 2.0;
          break;
        case 2.0:
          playbackSpeed = 1.0;
          break;
        default:
          playbackSpeed = 1.0;
      }
    });
    // TODO: Implement actual playback speed change
  }

  void _seekToPosition(TapDownDetails details) {
    // Get the progress bar widget's render box
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    // Calculate relative position within the available width
    final progressBarX = localPosition.dx - 56; // Account for profile/speed + play button + margins
    final availableWidth = renderBox.size.width - 56 - 12; // Total minus left elements minus right margin
    
    if (progressBarX >= 0 && availableWidth > 0) {
      final newPosition = (progressBarX / availableWidth).clamp(0.0, 1.0);
      setState(() {
        currentPosition = newPosition;
      });
    }
    // TODO: Implement actual audio seeking
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
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Audio not available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}