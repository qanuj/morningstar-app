import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/audio_recording_widget.dart';
import '../widgets/image_caption_dialog.dart';
import '../models/club_message.dart';
import '../models/message_status.dart';
import '../models/message_image.dart';
import '../models/message_document.dart';
import '../models/starred_info.dart';
import '../models/message_audio.dart';

/// A comprehensive self-contained message input widget for chat functionality
/// Handles text input, file attachments, camera capture, and audio recording
class MessageInput extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode textFieldFocusNode;
  final String clubId;
  final GlobalKey<AudioRecordingWidgetState> audioRecordingKey;
  
  // Simplified callbacks - only what's needed
  final Function(ClubMessage) onSendMessage;

  const MessageInput({
    super.key,
    required this.messageController,
    required this.textFieldFocusNode,
    required this.clubId,
    required this.audioRecordingKey,
    required this.onSendMessage,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _isComposing = false;
  final ImagePicker _imagePicker = ImagePicker();

  void _handleTextChanged(String value) {
    final isComposing = value.trim().isNotEmpty;
    if (_isComposing != isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
    }
  }

  void _sendTextMessage() {
    final text = widget.messageController.text.trim();
    if (text.isEmpty) return;

    // Create temp message
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user', // Will be filled by parent
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: text,
      messageType: 'text',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
    );

    widget.messageController.clear();
    setState(() {
      _isComposing = false;
    });

    widget.onSendMessage(tempMessage);
  }

  void _handleCameraCapture() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (photo != null) {
        _showImageCaptionDialog(photo);
      }
    } catch (e) {
      _showError('Failed to capture photo: $e');
    }
  }

  void _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 80,
      );
      
      if (images.isNotEmpty) {
        // For now, handle first image through caption dialog
        // Multiple image support can be added later by extending ImageCaptionDialog
        _showImageCaptionDialog(images.first);
        
        // If user selected multiple images, show the rest without caption dialog
        if (images.length > 1) {
          _sendImageMessage(images.skip(1).toList());
        }
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  void _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        _sendDocumentMessage(result.files);
      }
    } catch (e) {
      _showError('Failed to pick documents: $e');
    }
  }

  void _showImageCaptionDialog(XFile image) async {
    final platformFile = PlatformFile(
      name: image.name,
      path: image.path,
      size: await File(image.path).length(),
      bytes: null,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCaptionDialog(
            imageFile: platformFile,
            title: 'Send Image',
            onSend: (caption, croppedImagePath) {
              _sendImageMessageWithCaption(caption, croppedImagePath ?? image.path);
            },
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _sendImageMessageWithCaption(String caption, String imagePath) {
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user',
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: caption.trim(),
      messageType: 'image',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      // Store temp file path for upload
      pictures: [MessageImage(url: imagePath, caption: null)],
    );

    widget.onSendMessage(tempMessage);
  }

  void _sendImageMessage(List<XFile> images) {
    for (final image in images) {
      final tempMessage = ClubMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${images.indexOf(image)}',
        clubId: widget.clubId,
        senderId: 'current_user',
        senderName: 'You',
        senderProfilePicture: null,
        senderRole: 'MEMBER',
        content: '',
        messageType: 'image',
        createdAt: DateTime.now(),
        status: MessageStatus.sending,
        starred: StarredInfo(isStarred: false),
        pin: PinInfo(isPinned: false),
        // Store temp file path for upload
        pictures: [MessageImage(url: image.path, caption: null)],
      );

      widget.onSendMessage(tempMessage);
    }
  }

  void _sendDocumentMessage(List<PlatformFile> documents) {
    for (final doc in documents) {
      final tempMessage = ClubMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${documents.indexOf(doc)}',
        clubId: widget.clubId,
        senderId: 'current_user',
        senderName: 'You',
        senderProfilePicture: null,
        senderRole: 'MEMBER',
        content: '',
        messageType: 'document',
        createdAt: DateTime.now(),
        status: MessageStatus.sending,
        starred: StarredInfo(isStarred: false),
        pin: PinInfo(isPinned: false),
        // Store temp file info for upload
        documents: [MessageDocument(
          url: doc.path ?? '',
          filename: doc.name,
          type: doc.extension ?? 'file',
          size: doc.size.toString(),
        )],
      );

      widget.onSendMessage(tempMessage);
    }
  }

  void _sendAudioMessage(String audioPath) {
    // Extract audio file information
    final file = File(audioPath);
    final fileName = audioPath.split('/').last;
    final fileSize = file.existsSync() ? file.lengthSync() : 0;

    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user',
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: '',
      messageType: 'audio',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      // Store temp audio info for upload
      audio: MessageAudio(
        url: audioPath,
        filename: fileName,
        size: fileSize,
      ),
    );

    widget.onSendMessage(tempMessage);
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // First row - Photos, Document
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGridOption(
                            icon: Icons.photo_library,
                            iconColor: Color(0xFF2196F3),
                            title: 'Photos',
                            onTap: () {
                              Navigator.pop(context);
                              _pickImages();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.description,
                            iconColor: Color(0xFF2196F3),
                            title: 'Document',
                            onTap: () {
                              Navigator.pop(context);
                              _pickDocuments();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.location_on,
                            iconColor: Color(0xFF00C853),
                            title: 'Location',
                            onTap: () {
                              Navigator.pop(context);
                              // Location sharing coming soon
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                      // Coming soon options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGridOption(
                            icon: Icons.person,
                            iconColor: Colors.grey[700]!,
                            title: 'Contact',
                            onTap: () {
                              Navigator.pop(context);
                              // Contact sharing coming soon
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.poll,
                            iconColor: Color(0xFFFFB300),
                            title: 'Poll',
                            onTap: () {
                              Navigator.pop(context);
                              // Poll creation coming soon
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.event,
                            iconColor: Color(0xFFE53935),
                            title: 'Event',
                            onTap: () {
                              Navigator.pop(context);
                              // Event creation coming soon
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
                  onAudioRecorded: _sendAudioMessage,
                  isComposing: _isComposing,
                  onRecordingStateChanged: () => setState(() {}),
                ),
              ] else ...[
                // Normal input interface
                // Attachment button (+)
                IconButton(
                  onPressed: _showUploadOptions,
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
                            onChanged: _handleTextChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Camera button - hidden when composing
                if (!_isComposing)
                  IconButton(
                    onPressed: _handleCameraCapture,
                    icon: Icon(
                      Icons.camera_alt,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    iconSize: 28,
                  ),

                // Send button or audio recording widget
                if (_isComposing)
                  IconButton(
                    onPressed: _sendTextMessage,
                    icon: const Icon(Icons.send, color: Color(0xFF003f9b)),
                    iconSize: 28,
                  )
                else
                  AudioRecordingWidget(
                    key: widget.audioRecordingKey,
                    onAudioRecorded: _sendAudioMessage,
                    isComposing: _isComposing,
                    onRecordingStateChanged: () => setState(() {}),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}