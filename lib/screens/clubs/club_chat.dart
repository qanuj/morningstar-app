import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/user_provider.dart';
import '../../models/club.dart';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/message_image.dart';
import '../../models/message_document.dart';
import '../../models/link_metadata.dart';
import '../../services/api_service.dart';
// import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // Package not available
import 'package:url_launcher/url_launcher.dart';

class ClubChatScreen extends StatefulWidget {
  final Club club;

  const ClubChatScreen({
    Key? key,
    required this.club,
  }) : super(key: key);

  @override
  _ClubChatScreenState createState() => _ClubChatScreenState();
}

class _ClubChatScreenState extends State<ClubChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ClubMessage> _messages = [];
  bool _isLoading = true;
  bool _isComposing = false;
  String? _error;
  bool _showEmojiPicker = false;
  bool _showGifPicker = false;
  final FocusNode _textFieldFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Remove the listener since we handle it in onChanged now
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.get('/conversations/${widget.club.id}/messages');
      
      if (response['success'] == true || response['messages'] != null) {
        final List<dynamic> messageData = response['messages'] ?? [];
        _messages = messageData
            .map((json) => ClubMessage.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Sort by creation time (oldest first for chat display)
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else {
        _error = response['message'] ?? 'Failed to load messages';
      }
    } catch (e) {
      print('Error loading messages: $e');
      _error = 'Unable to load messages. Please check your connection.';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (!_isComposing) return;
    
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) {
      print('❌ User is null, cannot send message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Generate temporary message ID
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    // Check if message is emoji-only
    final emojiOnlyPattern = RegExp(r'^(\s*[\p{Emoji}\p{Emoji_Modifier}\p{Emoji_Component}\p{Emoji_Modifier_Base}\p{Emoji_Presentation}\u200d]*\s*)+$', unicode: true);
    final isEmojiOnly = emojiOnlyPattern.hasMatch(content) && content.trim().length <= 12; // Max 4 emojis
    
    // Detect links and fetch metadata
    List<LinkMetadata> linkMeta = [];
    final urlPattern = RegExp(r'https?://[^\s]+');
    final urls = urlPattern.allMatches(content).map((match) => match.group(0)!).toList();
    
    // Determine message type
    String messageType = 'text';
    if (isEmojiOnly) {
      messageType = 'emoji';
    } else if (urls.isNotEmpty) {
      messageType = 'link';
    }
    
    // Create optimistic message (add immediately to list)
    final optimisticMessage = ClubMessage(
      id: tempMessageId,
      clubId: widget.club.id,
      senderId: user.id,
      senderName: user.name,
      senderProfilePicture: user.profilePicture,
      senderRole: 'MEMBER', // Default role for current user
      content: content,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    
    // Clear input and add message to list immediately
    _messageController.clear();
    setState(() {
      _isComposing = false;
      _messages.add(optimisticMessage);
    });
    
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
    
    HapticFeedback.lightImpact();
    
    // Fetch link metadata if URLs found
    if (urls.isNotEmpty) {
      for (String url in urls) {
        final metadata = await _fetchLinkMetadata(url);
        if (metadata != null) {
          linkMeta.add(metadata);
        }
      }
    }
    
    try {
      print('🔵 Sending message to club ${widget.club.id} from user ${user.id}');
      print('🔵 Message content: $content');
      
      final Map<String, dynamic> contentMap = {
        'type': messageType,
        'body': content,
      };
      
      if (linkMeta.isNotEmpty) {
        contentMap['meta'] = linkMeta.map((meta) => meta.toJson()).toList();
      }
      
      final requestData = {
        'senderId': user.id,
        'content': contentMap,
      };
      
      print('🔵 Request data: $requestData');
      
      final response = await ApiService.post('/conversations/${widget.club.id}/messages', requestData);
      
      print('🔵 Full API Response: $response');
      
      // Check different possible response structures
      bool isSuccess = false;
      String? messageId;
      
      if (response.containsKey('messageId') && response['messageId'] != null) {
        isSuccess = true;
        messageId = response['messageId'];
      } else if (response.containsKey('success') && response['success'] == true) {
        isSuccess = true;
        messageId = response['messageId'];
      } else if (response.containsKey('id')) {
        // Sometimes the response might use 'id' instead of 'messageId'
        isSuccess = true;
        messageId = response['id'];
      } else if (response.containsKey('data') && response['data'] != null) {
        // Check if response has data wrapper
        final data = response['data'];
        if (data is Map && (data['messageId'] != null || data['id'] != null)) {
          isSuccess = true;
          messageId = data['messageId'] ?? data['id'];
        }
      } else {
        // If we get here without an error being thrown, assume success
        isSuccess = true;
        messageId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      print('🔵 Is success: $isSuccess, Message ID: $messageId');
      
      if (isSuccess) {
        // Update the optimistic message to sent status with real ID and metadata
        setState(() {
          final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
          if (messageIndex != -1) {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.sent,
              linkMeta: linkMeta,
            );
          }
        });
        
        print('✅ Message sent successfully: $messageId');
      } else {
        // Mark message as failed
        setState(() {
          final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
          if (messageIndex != -1) {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.failed,
              errorMessage: 'Server response unclear',
            );
          }
        });
        
        print('❌ Message send failed - no success indicator in response');
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      print('❌ Error type: ${e.runtimeType}');
      
      String errorMessage = 'Unable to send message';
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      
      // Mark message as failed with error message
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.failed,
            errorMessage: errorMessage,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true, // This ensures the body resizes when keyboard appears
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            // Club Logo
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: widget.club.logo != null && widget.club.logo!.isNotEmpty
                    ? Image.network(
                        widget.club.logo!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultClubLogo();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildDefaultClubLogo();
                        },
                      )
                    : _buildDefaultClubLogo(),
              ),
            ),
            SizedBox(width: 12),
            // Club Name
            Expanded(
              child: Text(
                widget.club.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMessages,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState(_error!)
                      : _messages.isEmpty
                          ? _buildEmptyState()
                          : _buildMessagesList(),
            ),
            
            // Message Input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final previousMessage = index > 0 ? _messages[index - 1] : null;
        final nextMessage = index < _messages.length - 1 ? _messages[index + 1] : null;
        
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

  Widget _buildMessageBubble(ClubMessage message, bool showSenderInfo, bool isLastFromSender) {
    final userProvider = context.read<UserProvider>();
    final isOwn = message.senderId == userProvider.user?.id;
    
    return Container(
      margin: EdgeInsets.only(bottom: isLastFromSender ? 8 : 2),
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn && showSenderInfo) _buildSenderAvatar(message),
          if (!isOwn && !showSenderInfo) SizedBox(width: 34),
          
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
                      padding: EdgeInsets.only(left: 8, bottom: 2),
                      child: Row(
                        children: [
                          Text(
                            message.senderName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.black.withOpacity(0.7),
                            ),
                          ),
                          if (message.senderRole != null && 
                              message.senderRole!.isNotEmpty && 
                              _shouldShowRole(message.senderRole!)) ...[
                            SizedBox(width: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRoleColor(message.senderRole!).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getRoleColor(message.senderRole!).withOpacity(0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                _formatRole(message.senderRole!),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: _getRoleColor(message.senderRole!),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  
                  GestureDetector(
                    onTap: message.status == MessageStatus.failed 
                        ? () => _showErrorDialog(message) 
                        : null,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isOwn 
                            ? (message.status == MessageStatus.failed 
                                ? (Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.red[800]
                                    : Colors.red.withOpacity(0.7))
                                : Theme.of(context).primaryColor)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!
                                : Theme.of(context).cardColor),
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
                        border: message.status == MessageStatus.failed
                            ? Border.all(color: Colors.red.withOpacity(0.5), width: 1)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (message.gifUrl != null)
                                  _buildGifMessage(message.gifUrl!, isOwn)
                                else if (message.content.isNotEmpty)
                                  _buildMessageContent(message, isOwn),
                                if (message.pictures.isNotEmpty) ...[
                                  // Debug: Print when we're about to show images
                                  Builder(
                                    builder: (context) {
                                      print('Message ${message.id} has ${message.pictures.length} pictures');
                                      return SizedBox.shrink();
                                    },
                                  ),
                                  _buildImageGallery(message.pictures),
                                ],
                                if (message.documents.isNotEmpty)
                                  _buildDocumentList(message.documents),
                                if (message.linkMeta.isNotEmpty)
                                  _buildLinkPreviews(message.linkMeta),
                              ],
                            ),
                          ),
                          if (isOwn) ...[
                            SizedBox(width: 8),
                            _buildMessageStatusIcon(message.status),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  if (isLastFromSender) ...[
                    SizedBox(height: 2),
                    Padding(
                      padding: EdgeInsets.only(
                        left: isOwn ? 0 : 8,
                        right: isOwn ? 8 : 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black.withOpacity(0.5),
                            ),
                          ),
                          if (message.status == MessageStatus.failed) ...[
                            SizedBox(width: 4),
                            Text(
                              '• Tap to retry',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
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

  Widget _buildMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white.withOpacity(0.7),
          ),
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.red,
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: Colors.white.withOpacity(0.7),
        );
      case MessageStatus.delivered:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 12, color: Colors.white.withOpacity(0.7)),
            Icon(Icons.check, size: 12, color: Colors.white.withOpacity(0.7)),
          ],
        );
      case MessageStatus.read:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 12, color: Colors.blue),
            Icon(Icons.check, size: 12, color: Colors.blue),
          ],
        );
      default:
        return SizedBox.shrink();
    }
  }

  void _showErrorDialog(ClubMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Message Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The following message could not be sent:',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[600]!
                      : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                '"${message.content}"',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black.withOpacity(0.7),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Error: ${message.errorMessage ?? "Unknown error"}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Dismiss',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryMessage(message);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _retryMessage(ClubMessage failedMessage) {
    // Remove the failed message and resend it
    setState(() {
      _messages.removeWhere((m) => m.id == failedMessage.id);
      _messageController.text = failedMessage.content;
      _isComposing = true;
    });
    
    // Trigger send after a short delay to allow UI to update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendMessage();
    });
  }

  Widget _buildDefaultClubLogo() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.club.name.isNotEmpty ? widget.club.name.substring(0, 1).toUpperCase() : 'C',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(ClubMessage message) {
    return Container(
      width: 28,
      height: 28,
      margin: EdgeInsets.only(right: 6, bottom: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border.all(
          color: _getRoleColor(message.senderRole ?? 'MEMBER').withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: message.senderProfilePicture != null && message.senderProfilePicture!.isNotEmpty
            ? Image.network(
                message.senderProfilePicture!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultSenderAvatar(message);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildDefaultSenderAvatar(message);
                },
              )
            : _buildDefaultSenderAvatar(message),
      ),
    );
  }
  
  Widget _buildDefaultSenderAvatar(ClubMessage message) {
    return Container(
      color: _getRoleColor(message.senderRole ?? 'MEMBER').withOpacity(0.1),
      child: Center(
        child: Text(
          message.senderName.isNotEmpty ? message.senderName.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _getRoleColor(message.senderRole ?? 'MEMBER'),
          ),
        ),
      ),
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return Colors.purple;
      case 'ADMIN':
        return Colors.red;
      case 'CAPTAIN':
        return Colors.orange;
      case 'VICE_CAPTAIN':
        return Colors.amber;
      case 'COACH':
        return Colors.blue;
      case 'MEMBER':
      default:
        return Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[400]! 
            : Colors.grey[600]!;
    }
  }
  
  String _formatRole(String role) {
    switch (role.toUpperCase()) {
      case 'VICE_CAPTAIN':
        return 'VC';
      case 'CAPTAIN':
        return 'C';
      case 'OWNER':
        return 'O';
      case 'ADMIN':
        return 'A';
      case 'COACH':
        return 'Coach';
      case 'MEMBER':
      default:
        return 'M';
    }
  }
  
  bool _shouldShowRole(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
      case 'ADMIN':
        return true;
      case 'UNKNOWN':
      case '':
        return false;
      default:
        return false;
    }
  }

  Widget _buildMessageContent(ClubMessage message, bool isOwn) {
    // Check if emoji-only message
    final emojiOnlyPattern = RegExp(r'^(\s*[\p{Emoji}\p{Emoji_Modifier}\p{Emoji_Component}\p{Emoji_Modifier_Base}\p{Emoji_Presentation}\u200d]*\s*)+$', unicode: true);
    final isEmojiOnly = message.messageType == 'emoji' || 
                       (emojiOnlyPattern.hasMatch(message.content) && message.content.trim().length <= 12);
    
    if (isEmojiOnly) {
      return _buildEmojiMessage(message.content, isOwn);
    } else {
      return _buildFormattedMessage(message.content, isOwn);
    }
  }
  
  Widget _buildEmojiMessage(String content, bool isOwn) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 32, // Large emoji size
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  Widget _buildGifMessage(String gifUrl, bool isOwn) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: 200,
        maxHeight: 200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          gifUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 150,
              width: 200,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              width: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gif,
                    size: 48,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey[600],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'GIF failed to load',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.5)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormattedMessage(String content, bool isOwn) {
    final baseColor = isOwn 
        ? Colors.white 
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.8));

    final codeBackgroundColor = isOwn 
        ? Colors.white.withOpacity(0.2)
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[700]!.withOpacity(0.5)
            : Colors.grey[200]!);

    final quoteColor = isOwn 
        ? Colors.white.withOpacity(0.8) 
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.7)
            : Colors.black.withOpacity(0.6));

    return SelectableText.rich(
      _parseFormattedText(content, baseColor, codeBackgroundColor, quoteColor),
      style: TextStyle(fontSize: 16, color: baseColor),
    );
  }

  TextSpan _parseFormattedText(String text, Color baseColor, Color codeBackgroundColor, Color quoteColor) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');
    
    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      String line = lines[lineIndex];
      
      // Handle block quotes
      if (line.startsWith('> ')) {
        spans.add(TextSpan(
          text: line.substring(2) + (lineIndex < lines.length - 1 ? '\n' : ''),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: quoteColor,
          ),
        ));
        continue;
      }
      
      // Handle bulleted lists
      if (line.startsWith('- ') || line.startsWith('* ')) {
        spans.add(TextSpan(
          text: '• ' + line.substring(2) + (lineIndex < lines.length - 1 ? '\n' : ''),
          style: TextStyle(color: baseColor),
        ));
        continue;
      }
      
      // Handle numbered lists (simple detection)
      final numberListMatch = RegExp(r'^(\d+)\.\s').firstMatch(line);
      if (numberListMatch != null) {
        spans.add(TextSpan(
          text: line + (lineIndex < lines.length - 1 ? '\n' : ''),
          style: TextStyle(color: baseColor),
        ));
        continue;
      }
      
      // Parse inline formatting for regular lines
      spans.addAll(_parseInlineFormatting(line + (lineIndex < lines.length - 1 ? '\n' : ''), baseColor, codeBackgroundColor));
    }
    
    return TextSpan(children: spans);
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
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add to message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildUploadOption(
                  icon: Icons.image,
                  label: 'Photos',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
                _buildUploadOption(
                  icon: Icons.insert_drive_file,
                  label: 'Documents',
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocuments();
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        _startImageUpload(result.files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _pickDocuments() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        _uploadDocuments(result.files);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking documents: $e')),
      );
    }
  }

  Future<void> _startImageUpload(List<PlatformFile> files) async {
    // Show caption dialog for single image, immediate upload for multiple
    if (files.length == 1) {
      _showSingleImageCaptionDialog(files.first);
    } else {
      _uploadImagesWithProgress(files, {});
    }
  }

  void _showSingleImageCaptionDialog(PlatformFile file) {
    final TextEditingController captionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        title: Text(
          'Add Caption',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.9)
                : Colors.black.withOpacity(0.8),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: captionController,
              decoration: InputDecoration(
                hintText: 'Write a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final caption = captionController.text.trim();
              _uploadImagesWithProgress([file], {file.name: caption});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: Text(
              'Send',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadImagesWithProgress(List<PlatformFile> files, Map<String, String> captions) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    // Generate temporary message ID
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    // Get the caption (message body) - use first non-empty caption or empty string
    String messageBody = '';
    for (String caption in captions.values) {
      if (caption.isNotEmpty) {
        messageBody = caption;
        break;
      }
    }
    
    // Create optimistic message with image previews
    final List<MessageImage> tempImages = files.map((file) {
      return MessageImage(
        url: file.path ?? '', // Use local path for preview
        caption: null, // Caption becomes the message body
      );
    }).toList();
    
    // Create optimistic message
    final optimisticMessage = ClubMessage(
      id: tempMessageId,
      clubId: widget.club.id,
      senderId: user.id,
      senderName: user.name,
      senderProfilePicture: user.profilePicture,
      senderRole: 'MEMBER',
      content: messageBody,
      pictures: tempImages,
      messageType: files.length == 1 ? 'image' : 'text_with_images',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    
    // Add message to list immediately with previews
    setState(() {
      _messages.add(optimisticMessage);
    });
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    try {
      // Upload images one by one
      List<MessageImage> uploadedImages = [];
      for (PlatformFile file in files) {
        final uploadedUrl = await _uploadFile(file);
        if (uploadedUrl != null) {
          uploadedImages.add(MessageImage(
            url: uploadedUrl,
            caption: null, // Caption is now the message body
          ));
        }
      }
      
      if (uploadedImages.isNotEmpty) {
        // Send the message with uploaded images
        await _sendMessageWithUploadedImages(tempMessageId, messageBody, uploadedImages);
      } else {
        // Mark as failed if no images uploaded
        setState(() {
          final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
          if (messageIndex != -1) {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              status: MessageStatus.failed,
              errorMessage: 'Failed to upload images',
            );
          }
        });
      }
    } catch (e) {
      print('Error uploading images: $e');
      // Mark as failed
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.failed,
            errorMessage: 'Upload failed: $e',
          );
        }
      });
    }
  }

  Future<void> _sendMessageWithUploadedImages(String tempMessageId, String messageBody, List<MessageImage> uploadedImages) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    try {
      final Map<String, dynamic> contentMap = {
        'type': uploadedImages.length == 1 ? 'image' : 'text_with_images',
        'body': messageBody,
        'pictures': uploadedImages.map((img) => img.toJson()).toList(),
      };

      final requestData = {
        'senderId': user.id,
        'content': contentMap,
      };

      final response = await ApiService.post('/conversations/${widget.club.id}/messages', requestData);

      // Update message with uploaded images and mark as sent
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.sent,
            pictures: uploadedImages,
          );
        }
      });

      print('✅ Message with images sent successfully');
    } catch (e) {
      print('❌ Error sending message with images: $e');
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.failed,
            errorMessage: 'Failed to send message with images',
          );
        }
      });
    }
  }

  Future<void> _uploadDocuments(List<PlatformFile> files) async {
    try {
      List<MessageDocument> uploadedDocs = [];
      
      for (PlatformFile file in files) {
        final uploadedUrl = await _uploadFile(file);
        if (uploadedUrl != null) {
          final extension = file.extension?.toLowerCase() ?? '';
          final fileSize = _formatFileSize(file.size ?? 0);
          uploadedDocs.add(MessageDocument(
            url: uploadedUrl,
            filename: file.name,
            type: extension,
            size: fileSize,
          ));
        }
      }
      
      if (uploadedDocs.isNotEmpty) {
        _sendMessageWithAttachments(documents: uploadedDocs);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading documents: $e')),
      );
    }
  }

  Future<LinkMetadata?> _fetchLinkMetadata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final html = response.body;
        
        // Extract metadata using RegExp
        String? title = _extractMetaContent(html, r'<title[^>]*>([^<]+)</title>');
        if (title == null) {
          title = _extractMetaContent(html, r'<meta[^>]*property=["\047]og:title["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>');
        }
        
        String? description = _extractMetaContent(html, r'<meta[^>]*name=["\047]description["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>');
        if (description == null) {
          description = _extractMetaContent(html, r'<meta[^>]*property=["\047]og:description["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>');
        }
        
        String? image = _extractMetaContent(html, r'<meta[^>]*property=["\047]og:image["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>');
        
        String? siteName = _extractMetaContent(html, r'<meta[^>]*property=["\047]og:site_name["\047][^>]*content=["\047]([^"\047>]*)["\047][^>]*>');
        
        // Get favicon
        String? favicon = _extractMetaContent(html, r'<link[^>]*rel=["\047](?:icon|shortcut icon)["\047][^>]*href=["\047]([^"\047>]*)["\047][^>]*>');
        if (favicon != null && !favicon.startsWith('http')) {
          final uri = Uri.parse(url);
          favicon = '${uri.scheme}://${uri.host}${favicon.startsWith('/') ? '' : '/'}$favicon';
        }
        
        return LinkMetadata(
          url: url,
          title: title,
          description: description,
          image: image,
          siteName: siteName,
          favicon: favicon,
        );
      }
    } catch (e) {
      print('Error fetching metadata for $url: $e');
    }
    return null;
  }
  
  String? _extractMetaContent(String html, String pattern) {
    final regex = RegExp(pattern, caseSensitive: false);
    final match = regex.firstMatch(html);
    return match?.group(1)?.trim();
  }

  Future<String?> _uploadFile(PlatformFile file) async {
    try {
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/upload'),
      );
      
      request.headers.addAll(ApiService.headers);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(responseData);
        return result['url'];
      } else {
        throw Exception('Upload failed: $responseData');
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  void _sendMessageWithAttachments({List<MessageImage>? pictures, List<MessageDocument>? documents}) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    final messageText = _messageController.text.trim();
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    // Create content with attachments
    String messageType = 'text';
    if (pictures != null && pictures.isNotEmpty) {
      if (messageText.isEmpty) {
        messageType = pictures.length == 1 ? 'image' : 'text_with_images';
      } else {
        messageType = 'text_with_images';
      }
    }
    
    final Map<String, dynamic> contentMap = {
      'type': messageType,
      'body': messageText,
    };
    
    if (pictures != null && pictures.isNotEmpty) {
      contentMap['pictures'] = pictures.map((p) => p.toJson()).toList();
    }
    
    if (documents != null && documents.isNotEmpty) {
      contentMap['documents'] = documents.map((d) => d.toJson()).toList();
    }
    
    // Create optimistic message
    final optimisticMessage = ClubMessage(
      id: tempMessageId,
      clubId: widget.club.id,
      senderId: user.id,
      senderName: user.name,
      senderProfilePicture: user.profilePicture,
      senderRole: 'MEMBER',
      content: messageText,
      pictures: pictures ?? [],
      documents: documents ?? [],
      messageType: messageType,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    
    _messageController.clear();
    setState(() {
      _isComposing = false;
      _messages.add(optimisticMessage);
    });
    
    // Debug logging
    print('Sending message with ${pictures?.length ?? 0} pictures');
    print('Message type: $messageType');
    print('Message content: "$messageText"');
    
    // Send message
    try {
      final requestData = {
        'senderId': user.id,
        'content': contentMap,
      };
      
      final response = await ApiService.post('/conversations/${widget.club.id}/messages', requestData);
      
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(status: MessageStatus.sent);
        }
      });
    } catch (e) {
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == tempMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            status: MessageStatus.failed,
            errorMessage: 'Failed to send message with attachments',
          );
        }
      });
    }
  }

  List<TextSpan> _parseInlineFormatting(String text, Color baseColor, Color codeBackgroundColor) {
    final List<TextSpan> spans = [];
    int currentIndex = 0;
    
    // Combined regex for all inline formatting
    final regex = RegExp(r'(\*[^*]+\*)|(_[^_]+_)|(~[^~]+~)|(`[^`]+`)');
    
    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: TextStyle(color: baseColor),
        ));
      }
      
      final matchedText = match.group(0)!;
      
      if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        // Bold: *text*
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: baseColor,
          ),
        ));
      } else if (matchedText.startsWith('_') && matchedText.endsWith('_')) {
        // Italic: _text_
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: baseColor,
          ),
        ));
      } else if (matchedText.startsWith('~') && matchedText.endsWith('~')) {
        // Strikethrough: ~text~
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: TextStyle(
            decoration: TextDecoration.lineThrough,
            color: baseColor,
          ),
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        // Inline code: `text`
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: codeBackgroundColor,
            color: baseColor,
          ),
        ));
      }
      
      currentIndex = match.end;
    }
    
    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: TextStyle(color: baseColor),
      ));
    }
    
    return spans;
  }

  Widget _buildImageWidget(MessageImage image) {
    // Check if it's a local file path (during upload) or network URL
    final isLocalFile = image.url.startsWith('/') || image.url.startsWith('file://') || !image.url.startsWith('http');
    
    if (isLocalFile && File(image.url).existsSync()) {
      return Image.file(
        File(image.url),
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: 48,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[600],
              ),
            ),
          );
        },
      );
    } else {
      return Image.network(
        image.url,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: 48,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey[600],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildImageGallery(List<MessageImage> images) {
    // Debug logging
    print('Building image gallery with ${images.length} images');
    for (int i = 0; i < images.length; i++) {
      print('Image $i: ${images[i].url}');
    }
    
    // If only 1-2 images, show them without borders/background
    if (images.length <= 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          ...images.map((image) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageWidget(image),
                ),
                if (image.caption != null && image.caption!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    image.caption!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.6)
                          : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          )).toList(),
        ],
      );
    }

    // For 3+ images, show gallery grid with +n more
    return Column(
      children: [
        SizedBox(height: 8),
        Container(
          height: 120,
          child: Row(
            children: [
              // Show up to 4 images
              for (int i = 0; i < (images.length > 4 ? 4 : images.length); i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[i].url,
                            fit: BoxFit.cover,
                            height: 120,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 120,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                child: Icon(
                                  Icons.broken_image,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ),
                        // Show +n more on 4th image if there are more
                        if (i == 3 && images.length > 4)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '+${images.length - 4}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Tap to view all images
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _showImageDialog(images, i),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentList(List<MessageDocument> documents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        ...documents.map((doc) => Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[600]!
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  doc.type == 'pdf' ? Icons.picture_as_pdf : Icons.description,
                  color: doc.type == 'pdf' ? Colors.red : Colors.blue,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.filename,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            doc.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.grey[600],
                            ),
                          ),
                          if (doc.size != null) ...[
                            Text(
                              ' • ${doc.size}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.6)
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.download,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey[600],
                ),
              ],
            ),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildLinkPreviews(List<LinkMetadata> linkMeta) {
    return Column(
      children: [
        SizedBox(height: 8),
        ...linkMeta.map((link) => Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _launchUrl(link.url),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[300]!,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image preview if available
                  if (link.image != null && link.image!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        link.image!,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return SizedBox.shrink(); // Hide if image fails to load
                        },
                      ),
                    ),
                  
                  // Content
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        if (link.title != null && link.title!.isNotEmpty)
                          Text(
                            link.title!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.black.withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        
                        // Description
                        if (link.description != null && link.description!.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            link.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black.withOpacity(0.6),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        
                        // Site info
                        SizedBox(height: 8),
                        Row(
                          children: [
                            // Favicon if available
                            if (link.favicon != null && link.favicon!.isNotEmpty) ...[
                              Image.network(
                                link.favicon!,
                                width: 16,
                                height: 16,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.language,
                                    size: 16,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey[600],
                                  );
                                },
                              ),
                              SizedBox(width: 8),
                            ] else ...[
                              Icon(
                                Icons.language,
                                size: 16,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.6)
                                    : Colors.grey[600],
                              ),
                              SizedBox(width: 8),
                            ],
                            
                            Expanded(
                              child: Text(
                                link.siteName ?? Uri.parse(link.url).host,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withOpacity(0.6)
                                      : Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.grey[600],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )).toList(),
      ],
    );
  }

  void _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: $e')),
      );
    }
  }

  void _showImageDialog(List<MessageImage> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        child: Image.network(
                          image.url,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 64, color: Colors.white54),
                                  SizedBox(height: 16),
                                  Text('Failed to load image', style: TextStyle(color: Colors.white54)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (image.caption != null && image.caption!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        color: Colors.black87,
                        child: Text(
                          image.caption!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[900]!
            : Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Upload button
          Material(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]!
                : Colors.grey[300]!,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: _showUploadOptions,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.add,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black.withOpacity(0.7),
                  size: 20,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]!
                    : Theme.of(context).scaffoldBackgroundColor,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (value) {
                setState(() {
                  _isComposing = value.trim().isNotEmpty;
                });
              },
            ),
          ),
          // Send button - only show when there's text to send
          if (_isComposing) ...[
            SizedBox(width: 8),
            Material(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  List<String> _getPopularEmojis() {
    return [
      '😀', '😂', '😍', '🥰', '😊', '😉', '😎', '🤔',
      '😢', '😭', '😡', '🤬', '🥺', '😤', '😴', '🤤',
      '👍', '👎', '👏', '🙌', '👋', '✋', '👌', '🤞',
      '💪', '🙏', '✨', '🔥', '💯', '❤️', '💔', '😘',
      '🏏', '⚾', '🏀', '⚽', '🎾', '🏆', '🥇', '🎉',
      '🎊', '🎈', '🎁', '🍕', '🍔', '🍟', '🍗', '🌮',
    ];
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.6),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              'Unable to load messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMessages,
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start the conversation with ${widget.club.name}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
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
}

