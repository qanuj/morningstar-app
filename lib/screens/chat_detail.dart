import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/user_provider.dart';
import '../models/conversation.dart';
import '../utils/theme.dart';
import '../widgets/custom_app_bar.dart';

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
                  
                  Container(
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
                    child: _buildMessageContent(message, isOwn),
                  ),
                  
                  if (isLastFromSender) ...[
                    SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.only(
                        left: isOwn ? 0 : 12,
                        right: isOwn ? 12 : 0,
                      ),
                      child: Text(
                        _formatMessageTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
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
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 16,
            color: isOwn ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        );
      
      case MessageType.image:
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
              child: Icon(Icons.image, size: 48),
            ),
            if (message.content.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                message.content,
                style: TextStyle(
                  fontSize: 16,
                  color: isOwn ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ],
        );
      
      case MessageType.file:
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
      
      case MessageType.system:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: isOwn ? Colors.white.withOpacity(0.8) : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        );
    }
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
      child: Row(
        children: [
          Expanded(
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
              ),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          SizedBox(width: 12),
          Material(
            color: _isComposing 
                ? Theme.of(context).primaryColor 
                : Theme.of(context).disabledColor,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _isComposing ? _sendMessage : null,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (!_isComposing) return;
    
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    _messageController.clear();
    setState(() {
      _isComposing = false;
    });
    
    HapticFeedback.lightImpact();
    
    final success = await context
        .read<ConversationProvider>()
        .sendMessage(widget.conversation.id, content);
    
    if (success) {
      // Scroll to bottom to show new message
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