import 'package:flutter/material.dart';
import '../widgets/audio_recording_widget.dart';

/// A comprehensive message input widget for chat functionality
/// Handles text input, file attachments, camera capture, and audio recording
class MessageInput extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode textFieldFocusNode;
  final bool isComposing;
  final GlobalKey<AudioRecordingWidgetState> audioRecordingKey;
  
  // Callbacks
  final VoidCallback onSendMessage;
  final VoidCallback onShowUploadOptions;
  final VoidCallback onCapturePhoto;
  final Function(String) onSendAudioMessage;
  final Function(String) onTextChanged;
  final Function(bool) onComposingChanged;
  final VoidCallback onRecordingStateChanged;

  const MessageInput({
    super.key,
    required this.messageController,
    required this.textFieldFocusNode,
    required this.isComposing,
    required this.audioRecordingKey,
    required this.onSendMessage,
    required this.onShowUploadOptions,
    required this.onCapturePhoto,
    required this.onSendAudioMessage,
    required this.onTextChanged,
    required this.onComposingChanged,
    required this.onRecordingStateChanged,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                spreadRadius: 1,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Check if audio recording is active - if so, show full-width recording interface
              if (widget.audioRecordingKey.currentState?.isRecording == true ||
                  widget.audioRecordingKey.currentState?.hasRecording == true) ...[
                // Full-width audio recording interface
                AudioRecordingWidget(
                  key: widget.audioRecordingKey,
                  onAudioRecorded: widget.onSendAudioMessage,
                  isComposing: widget.isComposing,
                  onRecordingStateChanged: widget.onRecordingStateChanged,
                ),
              ] else ...[
                // Normal input interface
                // Attachment button (+)
                IconButton(
                  onPressed: widget.onShowUploadOptions,
                  icon: Icon(
                    Icons.add,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                  iconSize: 28,
                ),

                // Expanded message input area
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: widget.textFieldFocusNode.hasFocus
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2a2f32)
                                : Colors.grey.shade50)
                          : (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2a2f32)
                                : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        // Text field
                        Expanded(
                          child: TextField(
                            controller: widget.messageController,
                            focusNode: widget.textFieldFocusNode,
                            autofocus: false,
                            decoration: InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            maxLines: 5,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            onChanged: (value) {
                              final isComposing = value.trim().isNotEmpty;
                              widget.onComposingChanged(isComposing);
                              widget.onTextChanged(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Camera button - hidden when composing
                if (!widget.isComposing)
                  IconButton(
                    onPressed: widget.onCapturePhoto,
                    icon: Icon(
                      Icons.camera_alt,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    iconSize: 28,
                  ),

                // Send button or audio recording widget
                if (widget.isComposing)
                  IconButton(
                    onPressed: widget.onSendMessage,
                    icon: const Icon(Icons.send, color: Color(0xFF003f9b)),
                    iconSize: 28,
                  )
                else
                  AudioRecordingWidget(
                    key: widget.audioRecordingKey,
                    onAudioRecorded: widget.onSendAudioMessage,
                    isComposing: widget.isComposing,
                    onRecordingStateChanged: widget.onRecordingStateChanged,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}