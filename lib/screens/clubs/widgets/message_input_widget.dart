import 'package:duggy/models/message_reply.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class MessageInputWidget extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final MessageReply? replyingTo;
  final List<PlatformFile> selectedFiles;
  final Function() onSendMessage;
  final Function() onClearReply;
  final Function() onSelectImages;
  final Function() onSelectFiles;
  final Function() onShowEmojiPicker;
  final Function() onRecordVoiceMessage;
  final Function(PlatformFile) onRemoveFile;
  final bool isLoading;

  const MessageInputWidget({
    Key? key,
    required this.messageController,
    required this.messageFocusNode,
    this.replyingTo,
    required this.selectedFiles,
    required this.onSendMessage,
    required this.onClearReply,
    required this.onSelectImages,
    required this.onSelectFiles,
    required this.onShowEmojiPicker,
    required this.onRecordVoiceMessage,
    required this.onRemoveFile,
    required this.isLoading,
  }) : super(key: key);

  @override
  _MessageInputWidgetState createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends State<MessageInputWidget> {
  bool _showAttachmentMenu = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Reply preview
        if (widget.replyingTo != null) _buildReplyPreview(),

        // Selected files preview
        if (widget.selectedFiles.isNotEmpty) _buildFilesPreview(),

        // Input area
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Attachment button
                IconButton(
                  onPressed: () => _toggleAttachmentMenu(),
                  icon: Icon(Icons.add, color: Color(0xFF06aeef), size: 24),
                ),

                // Text input
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: widget.messageController,
                      focusNode: widget.messageFocusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        suffixIcon: IconButton(
                          onPressed: widget.onShowEmojiPicker,
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      onSubmitted: (_) => widget.onSendMessage(),
                    ),
                  ),
                ),

                SizedBox(width: 8),

                // Send/Voice button
                GestureDetector(
                  onTap: widget.isLoading ? null : _handleSendOrVoice,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(0xFF06aeef),
                      shape: BoxShape.circle,
                    ),
                    child: widget.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            _shouldShowSendButton() ? Icons.send : Icons.mic,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Attachment menu
        if (_showAttachmentMenu) _buildAttachmentMenu(),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: Color(0xFF06aeef), width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${widget.replyingTo!.senderName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF06aeef),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  widget.replyingTo!.content,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClearReply,
            icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesPreview() {
    return Container(
      height: 100,
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.selectedFiles.length,
        itemBuilder: (context, index) {
          final file = widget.selectedFiles[index];
          return Container(
            width: 80,
            margin: EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: _buildFilePreview(file),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => widget.onRemoveFile(file),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilePreview(PlatformFile file) {
    final extension = file.extension?.toLowerCase();

    if (extension != null &&
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: file.bytes != null
            ? Image.memory(
                file.bytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : file.path != null
            ? Image.network(
                file.path!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : Icon(Icons.image, size: 40),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getFileIcon(extension), size: 32, color: Colors.grey[600]),
            SizedBox(height: 4),
            Text(
              extension?.toUpperCase() ?? 'FILE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAttachmentMenu() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAttachmentOption(
            icon: Icons.photo,
            label: 'Photos',
            onTap: () {
              widget.onSelectImages();
              _toggleAttachmentMenu();
            },
          ),
          _buildAttachmentOption(
            icon: Icons.insert_drive_file,
            label: 'Files',
            onTap: () {
              widget.onSelectFiles();
              _toggleAttachmentMenu();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(0xFF06aeef).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Color(0xFF06aeef), size: 24),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _toggleAttachmentMenu() {
    setState(() {
      _showAttachmentMenu = !_showAttachmentMenu;
    });
  }

  void _handleSendOrVoice() {
    if (_shouldShowSendButton()) {
      widget.onSendMessage();
    } else {
      widget.onRecordVoiceMessage();
    }
  }

  bool _shouldShowSendButton() {
    return widget.messageController.text.trim().isNotEmpty ||
        widget.selectedFiles.isNotEmpty ||
        widget.replyingTo != null;
  }

  IconData _getFileIcon(String? extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_fields;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
}
