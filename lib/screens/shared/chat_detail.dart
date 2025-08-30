import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../providers/conversation_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/conversation.dart';
import '../../models/message_status.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/image_picker_widget.dart';
import '../../widgets/file_picker_widget.dart';
import '../../widgets/emoji_picker_widget.dart';

// Import the document viewer widget from image_picker_widget.dart
// Note: We're reusing widgets from the existing files

class ChatDetailScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ChatDetailScreen({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _showEmojiPicker = false;
  List<File> _selectedImages = [];
  File? _selectedDocument;
  String? _selectedDocumentName;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {
        _isComposing = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: widget.conversation.title,
        customActions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showConversationInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, conversationProvider, child) {
                if (conversationProvider.isLoading && conversationProvider.messages.isEmpty) {
                  return _buildLoadingState();
                }

                if (conversationProvider.error != null && conversationProvider.messages.isEmpty) {
                  return _buildErrorState(conversationProvider.error!);
                }

                final messages = conversationProvider.messages
                    .where((m) => m.conversationId == widget.conversation.id)
                    .toList();

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildMessagesList(messages);
              },
            ),
          ),
          
          // Message Input
          if (_canSendMessages()) _buildMessageInput(),
        ],
      ),
    );
  }


  bool _canSendMessages() {
    // Announcements are typically read-only for regular members
    if (widget.conversation.type == ConversationType.announcement) {
      // TODO: Check if user is admin/owner
      return false;
    }
    return true;
  }

  Widget _buildMessagesList(List<MessageModel> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previousMessage = index > 0 ? messages[index - 1] : null;
        final nextMessage = index < messages.length - 1 ? messages[index + 1] : null;
        
        final showSenderInfo = previousMessage == null || 
                              previousMessage.senderId != message.senderId ||
                              message.createdAt.difference(previousMessage.createdAt).inMinutes > 10;
        
        final isLastFromSender = nextMessage == null || 
                                nextMessage.senderId != message.senderId ||
                                nextMessage.createdAt.difference(message.createdAt).inMinutes > 10;
        
        return _buildMessageBubble(message, showSenderInfo, isLastFromSender);
      },
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool showSenderInfo, bool isLastFromSender) {
    final userProvider = context.read<UserProvider>();
    final isOwn = message.senderId == userProvider.user?.id;
    
    return Container(
      margin: EdgeInsets.only(bottom: isLastFromSender ? 16 : 4),
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn && showSenderInfo) _buildSenderAvatar(message),
          if (!isOwn && !showSenderInfo) SizedBox(width: 40),
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isOwn && showSenderInfo) ...[
                    Padding(
                      padding: EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                  
                  GestureDetector(
                    onLongPress: () => _showMessageActions(message, isOwn),
                    onTap: () => _handleMessageTap(message),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isOwn 
                            ? Theme.of(context).primaryColor 
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(showSenderInfo && !isOwn ? 4 : 18),
                          topRight: Radius.circular(showSenderInfo && isOwn ? 4 : 18),
                          bottomLeft: Radius.circular(isOwn ? 18 : (isLastFromSender ? 18 : 4)),
                          bottomRight: Radius.circular(isOwn ? (isLastFromSender ? 18 : 4) : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMessageContent(message, isOwn),
                          if (message.reactions != null && message.reactions!.isNotEmpty) ...[
                            SizedBox(height: 8),
                            _buildMessageReactions(message.reactions!, isOwn),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  if (isLastFromSender) ...[
                    SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.only(
                        left: isOwn ? 0 : 12,
                        right: isOwn ? 12 : 0,
                      ),
                      child: Row(
                        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Text(
                            _formatMessageTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                          if (isOwn) ...[
                            SizedBox(width: 4),
                            _buildMessageStatusIcon(message.status),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          if (isOwn && showSenderInfo) SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSenderAvatar(MessageModel message) {
    return Container(
      width: 32,
      height: 32,
      margin: EdgeInsets.only(right: 8, bottom: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: message.senderAvatar != null
          ? ClipOval(
              child: Image.network(
                message.senderAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
              ),
            )
          : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Icon(
      Icons.person,
      size: 20,
      color: Theme.of(context).primaryColor,
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isOwn) {
    switch (message.type) {
      case MessageType.text:
        return _buildTextMessage(message, isOwn);
      
      case MessageType.image:
        return _buildImageMessage(message, isOwn);
      
      case MessageType.textWithImages:
        return _buildTextWithImagesMessage(message, isOwn);
      
      case MessageType.link:
        return _buildLinkMessage(message, isOwn);
      
      case MessageType.emoji:
        return _buildEmojiMessage(message, isOwn);
      
      case MessageType.gif:
        return _buildGifMessage(message, isOwn);
      
      case MessageType.document:
        return _buildDocumentMessage(message, isOwn);
      
      case MessageType.voice:
        return _buildVoiceMessage(message, isOwn);
      
      case MessageType.video:
        return _buildVideoMessage(message, isOwn);
      
      case MessageType.location:
        return _buildLocationMessage(message, isOwn);
      
      case MessageType.file:
        return _buildFileMessage(message, isOwn);
      
      case MessageType.system:
        return _buildSystemMessage(message, isOwn);
    }
  }

  Widget _buildTextMessage(MessageModel message, bool isOwn) {
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 16,
        color: isOwn ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }

  Widget _buildImageMessage(MessageModel message, bool isOwn) {
    final imageUrl = message.imageUrl;
    final caption = message.caption;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: isOwn ? Colors.white : Theme.of(context).primaryColor,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.broken_image,
                      size: 48,
                      color: isOwn ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                )
              : Icon(
                  Icons.image,
                  size: 48,
                  color: isOwn ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
                ),
        ),
        if (caption != null && caption.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            caption,
            style: TextStyle(
              fontSize: 16,
              color: isOwn ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextWithImagesMessage(MessageModel message, bool isOwn) {
    final images = message.images ?? [];
    final body = message.content;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (body.isNotEmpty) ...[
          Text(
            body,
            style: TextStyle(
              fontSize: 16,
              color: isOwn ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 8),
        ],
        if (images.isNotEmpty) _buildImageGrid(images, isOwn),
      ],
    );
  }

  Widget _buildImageGrid(List<String> images, bool isOwn) {
    if (images.length == 1) {
      return Container(
        height: 200,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            images[0],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.broken_image,
              size: 48,
              color: isOwn ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: images.length == 2 ? 2 : 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: images.length > 4 ? 4 : images.length,
      itemBuilder: (context, index) {
        if (index == 3 && images.length > 4) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '+${images.length - 3}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.broken_image,
                color: Colors.grey[600],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinkMessage(MessageModel message, bool isOwn) {
    final linkUrl = message.linkUrl;
    final linkTitle = message.linkTitle;
    final linkDescription = message.linkDescription;
    final linkThumbnail = message.linkThumbnail;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isOwn ? Colors.white.withOpacity(0.3) : Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (linkThumbnail != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              child: Image.network(
                linkThumbnail,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 60,
                  color: Colors.grey[300],
                  child: Icon(Icons.link, size: 24),
                ),
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (linkTitle != null && linkTitle.isNotEmpty) ...[
                  Text(
                    linkTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isOwn ? Colors.white : Theme.of(context).textTheme.titleLarge?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                ],
                if (linkDescription != null && linkDescription.isNotEmpty) ...[
                  Text(
                    linkDescription,
                    style: TextStyle(
                      fontSize: 14,
                      color: isOwn 
                          ? Colors.white.withOpacity(0.8) 
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                ],
                if (linkUrl != null) ...[
                  Text(
                    linkUrl,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOwn 
                          ? Colors.white.withOpacity(0.7) 
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiMessage(MessageModel message, bool isOwn) {
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 48, // Large emoji display
      ),
    );
  }

  Widget _buildGifMessage(MessageModel message, bool isOwn) {
    final gifUrl = message.imageUrl; // GIF URL stored in imageUrl field
    
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: gifUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                gifUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: isOwn ? Colors.white : Theme.of(context).primaryColor,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.gif_box,
                  size: 48,
                  color: isOwn ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            )
          : Icon(
              Icons.gif_box,
              size: 48,
              color: isOwn ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
            ),
    );
  }

  Widget _buildDocumentMessage(MessageModel message, bool isOwn) {
    final documentUrl = message.documentUrl;
    final documentName = message.documentName ?? 'Document';
    final documentSize = message.documentSize ?? '';
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOwn 
            ? Colors.white.withOpacity(0.1) 
            : Theme.of(context).cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOwn ? Colors.white.withOpacity(0.2) : Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getDocumentIcon(documentName),
              color: isOwn ? Colors.white : Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documentName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isOwn ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (documentSize.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    documentSize,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOwn 
                          ? Colors.white.withOpacity(0.7) 
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.download,
            color: isOwn ? Colors.white : Theme.of(context).primaryColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessage(MessageModel message, bool isOwn) {
    final voiceDuration = message.voiceDuration ?? 0;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow,
            color: isOwn ? Colors.white : Theme.of(context).primaryColor,
            size: 24,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: isOwn 
                    ? Colors.white.withOpacity(0.3) 
                    : Theme.of(context).primaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            _formatDuration(voiceDuration),
            style: TextStyle(
              fontSize: 12,
              color: isOwn 
                  ? Colors.white.withOpacity(0.8) 
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoMessage(MessageModel message, bool isOwn) {
    final videoUrl = message.imageUrl; // Video thumbnail stored in imageUrl field
    
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: videoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    videoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.videocam,
                      size: 48,
                      color: isOwn ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                )
              : Icon(
                  Icons.videocam,
                  size: 48,
                  color: isOwn ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
                ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.play_circle_filled,
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationMessage(MessageModel message, bool isOwn) {
    final locationName = message.locationName ?? 'Shared Location';
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOwn 
            ? Colors.white.withOpacity(0.1) 
            : Theme.of(context).cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOwn ? Colors.white.withOpacity(0.2) : Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.location_on,
              color: isOwn ? Colors.white : Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isOwn ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Tap to view location',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOwn 
                        ? Colors.white.withOpacity(0.7) 
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileMessage(MessageModel message, bool isOwn) {
    return Row(
      children: [
        Icon(
          Icons.attach_file,
          color: isOwn ? Colors.white : Theme.of(context).primaryColor,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 16,
              color: isOwn ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemMessage(MessageModel message, bool isOwn) {
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: isOwn ? Colors.white.withOpacity(0.8) : Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }

  IconData _getDocumentIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
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
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Emoji picker
          if (_showEmojiPicker) ...[
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: EmojiPickerWidget(
                onEmojiSelected: (emoji) {
                  _messageController.text += emoji;
                  setState(() {
                    _isComposing = _messageController.text.trim().isNotEmpty;
                  });
                },
              ),
            ),
          ],
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAttachmentOptions,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.add,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              
              // Text input
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Emoji button
                          IconButton(
                            onPressed: _toggleEmojiPicker,
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              color: Theme.of(context).primaryColor.withOpacity(0.7),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (text) {
                      // Detect links and show preview
                      _detectLinks(text);
                    },
                  ),
                ),
              ),
              
              // Send/Voice button
              Material(
                color: _isComposing 
                    ? Theme.of(context).primaryColor 
                    : Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _isComposing ? _sendMessage : _startVoiceRecording,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    child: Icon(
                      _isComposing ? Icons.send : Icons.mic,
                      color: _isComposing ? Colors.white : Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (!_isComposing) return;
    
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    // Check if message is emoji-only
    final isEmojiOnly = _isEmojiOnly(content);
    final messageType = isEmojiOnly ? MessageType.emoji : MessageType.text;
    
    _messageController.clear();
    setState(() {
      _isComposing = false;
    });
    
    HapticFeedback.lightImpact();
    
    final success = await context
        .read<ConversationProvider>()
        .sendMessage(widget.conversation.id, content, type: messageType);
    
    if (success) {
      // Scroll to bottom to show new message
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isEmojiOnly(String text) {
    // Simple emoji detection - in real app, use a proper emoji detection library
    final emojiRegex = RegExp(r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true);
    final cleanText = text.replaceAll(' ', '');
    final matches = emojiRegex.allMatches(cleanText);
    return matches.length > 0 && cleanText.replaceAll(emojiRegex, '').isEmpty;
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send Attachment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.gif_box,
                  label: 'GIF',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _showGifPicker();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _shareLocation();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _startVoiceRecording() {
    // TODO: Implement voice recording
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice recording coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _pickImageFromCamera() {
    _showImagePicker(allowMultiple: false);
  }

  void _pickImageFromGallery() {
    _showImagePicker(allowMultiple: true);
  }

  void _showImagePicker({bool allowMultiple = true}) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ImagePickerWidget(
        onImagesSelected: _onImagesSelected,
        allowMultiple: allowMultiple,
        maxImages: 10,
      ),
    );
  }

  void _onImagesSelected(List<File> images) async {
    if (images.isEmpty) return;
    
    setState(() {
      _selectedImages = images;
    });
    
    // Send images
    for (final image in images) {
      await _sendImageMessage(image);
    }
    
    setState(() {
      _selectedImages.clear();
    });
  }

  Future<void> _sendImageMessage(File imageFile) async {
    // TODO: Upload image to server and get URL
    // For now, create a placeholder message
    final richContent = {
      'type': 'image',
      'url': 'placeholder_url', // This would be the uploaded image URL
      'caption': '',
    };
    
    final success = await context
        .read<ConversationProvider>()
        .sendRichMessage(
          widget.conversation.id, 
          MessageType.image, 
          richContent,
        );
    
    if (success) {
      _scrollToBottom();
    }
  }

  void _pickDocument() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilePickerWidget(
        onFileSelected: _onDocumentSelected,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip', 'rar'],
        maxFileSizeMB: 50,
      ),
    );
  }

  void _onDocumentSelected(File documentFile, String fileName) async {
    setState(() {
      _selectedDocument = documentFile;
      _selectedDocumentName = fileName;
    });
    
    await _sendDocumentMessage(documentFile, fileName);
    
    setState(() {
      _selectedDocument = null;
      _selectedDocumentName = null;
    });
  }

  Future<void> _sendDocumentMessage(File documentFile, String fileName) async {
    // TODO: Upload document to server and get URL
    // For now, create a placeholder message
    final richContent = {
      'type': 'document',
      'url': 'placeholder_document_url', // This would be the uploaded document URL
      'name': fileName,
      'size': '${(documentFile.lengthSync() / 1024 / 1024).toStringAsFixed(1)}MB',
    };
    
    final success = await context
        .read<ConversationProvider>()
        .sendRichMessage(
          widget.conversation.id, 
          MessageType.document, 
          richContent,
        );
    
    if (success) {
      _scrollToBottom();
    }
  }

  void _showGifPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => GifPickerWidget(
        onGifSelected: _onGifSelected,
      ),
    );
  }

  void _onGifSelected(String gifUrl, String title) async {
    final richContent = {
      'type': 'gif',
      'url': gifUrl,
      'title': title,
    };
    
    final success = await context
        .read<ConversationProvider>()
        .sendRichMessage(
          widget.conversation.id, 
          MessageType.gif, 
          richContent,
        );
    
    if (success) {
      _scrollToBottom();
    }
  }

  void _shareLocation() {
    // TODO: Implement location sharing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location sharing coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _pickVideo() {
    // TODO: Implement video picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video picker coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _detectLinks(String text) {
    // Simple URL detection - in real app, use a proper URL detection library
    final urlRegex = RegExp(r'https?://[\w\-]+(\.[\w\-]+)+([\w\-\.,@?^=%&:/~\+#]*[\w\-\@?^=%&/~\+#])?');
    final matches = urlRegex.allMatches(text);
    
    // TODO: Generate link previews for detected URLs
    // This would involve fetching the URL metadata and displaying a preview
    if (matches.isNotEmpty) {
      // For now, just detect the presence of links
      // In a real app, you would fetch metadata and show preview
    }
  }

  void _showConversationInfo() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conversation Info',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow('Name', widget.conversation.title),
            _buildInfoRow('Type', _getTypeLabel(widget.conversation.type)),
            _buildInfoRow('Members', '${widget.conversation.participants.length}'),
            if (widget.conversation.description != null)
              _buildInfoRow('Description', widget.conversation.description!),
            _buildInfoRow('Created', _formatDate(widget.conversation.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(ConversationType type) {
    switch (type) {
      case ConversationType.announcement:
        return 'Announcement';
      case ConversationType.group:
        return 'Group Chat';
      case ConversationType.general:
        return 'General Discussion';
      case ConversationType.private:
        return 'Private Message';
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Widget _buildMessageReactions(List<MessageReaction> reactions, bool isOwn) {
    final groupedReactions = <String, List<MessageReaction>>{};
    for (final reaction in reactions) {
      if (!groupedReactions.containsKey(reaction.emoji)) {
        groupedReactions[reaction.emoji] = [];
      }
      groupedReactions[reaction.emoji]!.add(reaction);
    }
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: groupedReactions.entries.map((entry) {
        final emoji = entry.key;
        final reactionList = entry.value;
        final count = reactionList.length;
        
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOwn 
                ? Colors.white.withOpacity(0.2)
                : Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOwn 
                  ? Colors.white.withOpacity(0.3)
                  : Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: 12),
              ),
              if (count > 1) ...[
                SizedBox(width: 2),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isOwn 
                        ? Colors.white.withOpacity(0.8)
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageStatusIcon(MessageStatus status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.grey;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }
    
    return Icon(
      icon,
      size: 12,
      color: color,
    );
  }

  void _handleMessageTap(MessageModel message) {
    // Handle different message types on tap
    switch (message.type) {
      case MessageType.image:
        _showImagePreview(message);
        break;
      case MessageType.document:
        _openDocument(message);
        break;
      case MessageType.link:
        _openLink(message);
        break;
      case MessageType.video:
        _playVideo(message);
        break;
      case MessageType.location:
        _openLocation(message);
        break;
      default:
        // No special action for text messages
        break;
    }
  }

  void _showMessageActions(MessageModel message, bool isOwn) {
    final actions = <Widget>[];
    
    // Reply action (available for all messages)
    actions.add(
      ListTile(
        leading: Icon(Icons.reply),
        title: Text('Reply'),
        onTap: () {
          Navigator.pop(context);
          _replyToMessage(message);
        },
      ),
    );
    
    // Copy action (for text messages)
    if (message.type == MessageType.text || message.type == MessageType.emoji) {
      actions.add(
        ListTile(
          leading: Icon(Icons.copy),
          title: Text('Copy'),
          onTap: () {
            Navigator.pop(context);
            _copyMessage(message);
          },
        ),
      );
    }
    
    // Forward action
    actions.add(
      ListTile(
        leading: Icon(Icons.forward),
        title: Text('Forward'),
        onTap: () {
          Navigator.pop(context);
          _forwardMessage(message);
        },
      ),
    );
    
    // React action
    actions.add(
      ListTile(
        leading: Icon(Icons.emoji_emotions),
        title: Text('React'),
        onTap: () {
          Navigator.pop(context);
          _showReactionPicker(message);
        },
      ),
    );
    
    // Delete action (only for own messages)
    if (isOwn) {
      actions.add(
        ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('Delete', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            _deleteMessage(message);
          },
        ),
      );
    }
    
    // Info action
    actions.add(
      ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Info'),
        onTap: () {
          Navigator.pop(context);
          _showMessageInfo(message);
        },
      ),
    );
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        ),
      ),
    );
  }

  void _showImagePreview(MessageModel message) {
    final imageUrl = message.imageUrl;
    if (imageUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImagePreviewWidget(
            imageUrl: imageUrl,
            caption: message.caption,
          ),
        ),
      );
    }
  }

  void _openDocument(MessageModel message) {
    final documentUrl = message.documentUrl;
    final documentName = message.documentName;
    if (documentUrl != null && documentName != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerWidget(
            documentUrl: documentUrl,
            documentName: documentName,
            documentSize: message.documentSize,
          ),
        ),
      );
    }
  }

  void _openLink(MessageModel message) {
    final linkUrl = message.linkUrl;
    if (linkUrl != null) {
      // TODO: Open link with url_launcher
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening link: $linkUrl'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () => _copyToClipboard(linkUrl),
          ),
        ),
      );
    }
  }

  void _playVideo(MessageModel message) {
    // TODO: Implement video player
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video player coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openLocation(MessageModel message) {
    final lat = message.locationLat;
    final lng = message.locationLng;
    final name = message.locationName;
    
    if (lat != null && lng != null) {
      // TODO: Open map with location
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening location: ${name ?? 'Unknown location'}'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _replyToMessage(MessageModel message) {
    // TODO: Implement reply functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Replying to message from ${message.senderName}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyMessage(MessageModel message) {
    _copyToClipboard(message.content);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void _forwardMessage(MessageModel message) {
    // TODO: Implement forward functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Forward functionality coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showReactionPicker(MessageModel message) {
    final quickReactions = ['👍', '❤️', '😂', '😢', '😮', '😡'];
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'React to Message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: quickReactions.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction(message, emoji);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _addReaction(MessageModel message, String emoji) {
    // TODO: Implement reaction functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reacted with $emoji'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _deleteMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Message'),
        content: Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement message deletion
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Message deletion coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMessageInfo(MessageModel message) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message Info',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow('From', message.senderName),
            _buildInfoRow('Type', message.type.toString().split('.').last),
            _buildInfoRow('Sent', _formatDate(message.createdAt)),
            _buildInfoRow('Status', message.status.toString().split('.').last),
            if (message.attachments != null && message.attachments!.isNotEmpty)
              _buildInfoRow('Attachments', message.attachments!.length.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            SizedBox(height: 16),
            Text(
              'Unable to load messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context
                  .read<ConversationProvider>()
                  .fetchMessages(widget.conversation.id),
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start the conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}