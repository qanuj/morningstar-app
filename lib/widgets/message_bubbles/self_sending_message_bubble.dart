import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/club_message.dart';
import '../../models/message_status.dart';
import '../../models/link_metadata.dart';
import '../../models/message_document.dart';
import '../../models/message_audio.dart';
import '../../services/api_service.dart';
import '../../services/chat_api_service.dart';
import '../../services/message_storage_service.dart';
import '../../services/open_graph_service.dart';
import 'message_bubble_factory.dart';

/// A stateful message bubble that handles its own sending process
/// Supports all upload types: text, images, videos, audio, documents
class SelfSendingMessageBubble extends StatefulWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isDeleted;
  final bool isSelected;
  final bool showSenderInfo;
  final String clubId;
  final List<PlatformFile>? pendingUploads; // Files waiting to be uploaded
  final Function(ClubMessage oldMessage, ClubMessage newMessage)?
  onMessageUpdated;
  final Function(String messageId)? onMessageFailed;

  const SelfSendingMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.isDeleted,
    required this.clubId,
    this.isSelected = false,
    this.showSenderInfo = false,
    this.pendingUploads,
    this.onMessageUpdated,
    this.onMessageFailed,
  });

  @override
  _SelfSendingMessageBubbleState createState() =>
      _SelfSendingMessageBubbleState();
}

class _SelfSendingMessageBubbleState extends State<SelfSendingMessageBubble> {
  late ClubMessage currentMessage;
  bool _isSending = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _currentUploadFile = '';
  int _completedUploads = 0;
  int _totalUploads = 0;

  // Upload results
  List<String> _uploadedImages = [];
  List<String> _uploadedVideos = [];
  List<MessageDocument> _uploadedDocuments = [];
  MessageAudio? _uploadedAudio;

  // Track individual file upload progress
  Map<String, double> _fileUploadProgress = {};

  @override
  void initState() {
    super.initState();
    print('🔍 SelfSendingMessageBubble: initState called for message: ${widget.message.id}');
    print('🔍 SelfSendingMessageBubble: Message status: ${widget.message.status}');
    print('🔍 SelfSendingMessageBubble: Message images: ${widget.message.images}');
    print('🔍 SelfSendingMessageBubble: Message messageType: ${widget.message.messageType}');
    
    currentMessage = widget.message;
    // If this is a sending message, start the send process
    if (currentMessage.status == MessageStatus.sending && !_isSending) {
      print('🔍 SelfSendingMessageBubble: Scheduling send process start');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('🔍 SelfSendingMessageBubble: Starting send process now');
        _startSendProcess();
      });
    } else {
      print('🔍 SelfSendingMessageBubble: NOT starting send process. Status: ${currentMessage.status}, _isSending: $_isSending');
    }
  }

  @override
  void didUpdateWidget(SelfSendingMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      if (mounted) {
        setState(() {
          currentMessage = widget.message;
        });
      }
    }
  }

  Future<void> _startSendProcess() async {
    if (_isSending || currentMessage.status != MessageStatus.sending) return;

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    try {
      // Step 1: Handle file uploads if any
      if (widget.pendingUploads != null && widget.pendingUploads!.isNotEmpty) {
        await _handleFileUploads(widget.pendingUploads!);
      }

      // Step 2: Handle existing media in the message (from image cropping, etc.)
      await _handleExistingMedia();

      // Step 3: Handle regular message sending
      await _sendMessage();
    } catch (e) {
      await _handleSendFailure('Send failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _handleFileUploads(List<PlatformFile> files) async {
    if (mounted) {
      setState(() {
        _isUploading = true;
        _totalUploads = files.length;
        _completedUploads = 0;
        _uploadProgress = 0.0;
        // Initialize progress tracking for each file
        _fileUploadProgress.clear();
        for (final file in files) {
          _fileUploadProgress[file.name] = 0.0;
        }
      });
    }

    for (int i = 0; i < files.length; i++) {
      final file = files[i];

      if (mounted) {
        setState(() {
          _currentUploadFile = file.name;
          _uploadProgress = i / files.length;
          _fileUploadProgress[file.name] = 0.5; // In progress
        });
      }

      try {
        final uploadUrl = await ApiService.uploadFile(file);
        if (uploadUrl != null) {
          await _processUploadedFile(file, uploadUrl);
        } else {
          throw Exception('Upload failed for ${file.name}');
        }
      } catch (e) {
        throw Exception('Failed to upload ${file.name}: $e');
      }

      if (mounted) {
        setState(() {
          _completedUploads = i + 1;
          _uploadProgress = (i + 1) / files.length;
          _fileUploadProgress[file.name] = 1.0; // Complete
        });
      }
    }

    if (mounted) {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _handleExistingMedia() async {
    print(
      '🔍 _handleExistingMedia: currentMessage.images.length = ${currentMessage.images.length}',
    );
    // Handle images that are already in the message (from cropping, etc.)
    if (currentMessage.images.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isUploading = true;
          _totalUploads = currentMessage.images.length;
          _completedUploads = 0;
        });
      }

      for (int i = 0; i < currentMessage.images.length; i++) {
        final image = currentMessage.images[i];
        final imagePath = image;

        // Skip if it's already a remote URL (already uploaded)
        if (imagePath.startsWith('http')) {
          _uploadedImages.add(image);
          continue;
        }

        if (mounted) {
          setState(() {
            _currentUploadFile = imagePath.split('/').last;
            _uploadProgress = i / currentMessage.images.length;
          });
        }

        try {
          // Create a temporary PlatformFile for the image
          final file = File(imagePath);
          if (await file.exists()) {
            final fileName = imagePath.split('/').last;
            final fileSize = await file.length();

            final platformFile = PlatformFile(
              name: fileName,
              path: imagePath,
              size: fileSize,
              bytes: null,
            );
            final uploadUrl = await ApiService.uploadFile(platformFile);
            if (uploadUrl != null) {
              _uploadedImages.add(uploadUrl);
            } else {
              throw Exception('Upload failed for $fileName');
            }
          }
        } catch (e) {
          throw Exception('Failed to upload ${imagePath.split('/').last}: $e');
        }

        if (mounted) {
          setState(() {
            _completedUploads = i + 1;
            _uploadProgress = (i + 1) / currentMessage.images.length;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }

    // Handle audio that's already in the message
    if (currentMessage.audio != null) {
      final audio = currentMessage.audio!;
      final audioPath = audio.url;

      // Skip if it's already a remote URL
      if (!audioPath.startsWith('http')) {
        try {
          final file = File(audioPath);
          if (await file.exists()) {
            final fileName = audioPath.split('/').last;
            final fileSize = await file.length();

            final platformFile = PlatformFile(
              name: fileName,
              path: audioPath,
              size: fileSize,
              bytes: null,
            );

            final uploadUrl = await ApiService.uploadFile(platformFile);
            if (uploadUrl != null) {
              _uploadedAudio = MessageAudio(
                url: uploadUrl,
                filename: audio.filename,
                duration: audio.duration,
                size: audio.size,
              );
            } else {
              throw Exception('Failed to upload audio: No upload URL returned');
            }
          } else {
            throw Exception('Audio file not found: $audioPath');
          }
        } catch (e) {
          print('Failed to upload audio: $e');
          rethrow; // Propagate the error instead of silencing it
        }
      } else {
        _uploadedAudio = audio;
      }
    }

    // Handle document that is already in the message
    if (currentMessage.document != null) {
      final document = currentMessage.document!;
      final docPath = document.url;

      // Skip if it's already a remote URL
      if (!docPath.startsWith('http')) {
        try {
          final file = File(docPath);
          if (await file.exists()) {
            final fileName = docPath.split('/').last;
            final fileSize = await file.length();

            final platformFile = PlatformFile(
              name: fileName,
              path: docPath,
              size: fileSize,
              bytes: null,
            );

            final uploadUrl = await ApiService.uploadFile(platformFile);
            if (uploadUrl != null) {
              _uploadedDocuments.add(
                MessageDocument(
                  url: uploadUrl,
                  filename: document.filename,
                  type: document.type,
                  size: document.size,
                ),
              );
            }
          }
        } catch (e) {
          print('Failed to upload document: $e');
        }
      } else {
        _uploadedDocuments.add(document);
      }
    }
  }

  Future<void> _processUploadedFile(PlatformFile file, String uploadUrl) async {
    final fileType = _getFileType(file);
    final fileSize = file.size;

    switch (fileType) {
      case 'image':
        _uploadedImages.add(uploadUrl);
        break;

      case 'video':
        _uploadedVideos.add(uploadUrl);
        break;

      case 'audio':
        _uploadedAudio = MessageAudio(
          url: uploadUrl,
          filename: file.name,
          duration: 0, // Duration would need to be calculated
          size: fileSize,
        );
        break;

      case 'document':
      default:
        _uploadedDocuments.add(
          MessageDocument(
            url: uploadUrl,
            filename: file.name,
            type: file.extension ?? 'unknown',
            size: fileSize.toString(),
          ),
        );
        break;
    }
  }

  String _getFileType(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    if (extension == null) return 'document';

    // Image types
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return 'image';
    }

    // Video types
    if ([
      'mp4',
      'mov',
      'avi',
      'mkv',
      'wmv',
      'flv',
      'webm',
    ].contains(extension)) {
      return 'video';
    }

    // Audio types
    if ([
      'mp3',
      'wav',
      'aac',
      'flac',
      'ogg',
      'm4a',
      'wma',
    ].contains(extension)) {
      return 'audio';
    }

    return 'document';
  }

  Future<void> _sendMessage() async {
    try {
      // Use the message data as-is (messageType and linkMeta already set during input)
      String messageType = currentMessage.messageType ?? 'text';
      List<LinkMetadata> linkMeta = currentMessage.linkMeta ?? [];

      // Only override messageType for media uploads (since media changes the type)
      if (_hasUploads()) {
        messageType = _determineMessageType(currentMessage.content, linkMeta);
      }

      print('🔍 SelfSendingMessageBubble: Sending messageType: $messageType');

      // Prepare API request - all images/videos use 'text' type with arrays
      Map<String, dynamic> contentMap;

      if (messageType == 'document' &&
          _uploadedDocuments.length == 1 &&
          currentMessage.content.trim().isEmpty) {
        // Single document without text
        final doc = _uploadedDocuments.first;
        contentMap = {
          'type': 'document',
          'url': doc.url,
          'name': doc.filename,
          'size': doc.size,
        };
      } else if (messageType == 'audio' &&
          _uploadedAudio != null &&
          currentMessage.content.trim().isEmpty) {
        // Single audio without text
        print(
          '🎵 Building audio contentMap: duration=${_uploadedAudio!.duration}, size=${_uploadedAudio!.size}',
        );
        contentMap = {
          'type': 'audio',
          'url': _uploadedAudio!.url,
          'duration': _uploadedAudio!.duration,
          'size': _uploadedAudio!.size?.toString(),
        };
      } else if (messageType == 'link' && linkMeta.isNotEmpty) {
        // Link message with special schema format (parsed during input)
        final firstLink = linkMeta.first;
        contentMap = {
          'type': 'link',
          'url': firstLink.url,
          'body': currentMessage.content.trim().isEmpty
              ? ' '
              : currentMessage.content,
        };

        // Add optional fields only if they exist
        if (firstLink.title != null && firstLink.title!.isNotEmpty) {
          contentMap['title'] = firstLink.title;
        }
        if (firstLink.description != null &&
            firstLink.description!.isNotEmpty) {
          contentMap['description'] = firstLink.description;
        }
        if (firstLink.image != null && firstLink.image!.isNotEmpty) {
          contentMap['images'] = [firstLink.image!]; // Array with one image
        }
      } else if (messageType == 'practice') {
        // Practice message with special schema format
        contentMap = {
          'type': 'practice',
          'body': currentMessage.content.trim().isEmpty
              ? ' '
              : currentMessage.content,
          'practiceId': currentMessage.practiceId,
          'meta': currentMessage.meta,
        };
        print('🔍 SelfSendingMessageBubble: Created practice contentMap: $contentMap');
      } else if (messageType == 'match') {
        // Match message with special schema format
        contentMap = {
          'type': 'match',
          'body': currentMessage.content.trim().isEmpty
              ? ' '
              : currentMessage.content,
          'matchId': currentMessage.matchId,
          'meta': currentMessage.meta,
        };
      } else if (messageType == 'poll') {
        // Poll message with special schema format
        contentMap = {
          'type': 'poll',
          'body': currentMessage.content.trim().isEmpty
              ? ' '
              : currentMessage.content,
          'pollId': currentMessage.pollId,
          'meta': currentMessage.meta,
        };
      } else if (messageType == 'location') {
        // Location message with special schema format
        contentMap = {
          'type': 'location',
          'body': currentMessage.content.trim().isEmpty
              ? ' '
              : currentMessage.content,
          'meta': currentMessage.meta,
        };
      } else {
        // All other cases: text, emoji, and ALL images/videos (single or multiple)
        contentMap = {
          'type': messageType,
          'body': currentMessage.content.trim().isEmpty
              ? ' '
              : currentMessage.content,
        };

        // Add media arrays for text messages with media
        print(
          '🔍 Building contentMap. _uploadedImages.length = ${_uploadedImages.length}',
        );
        if (_uploadedImages.isNotEmpty) {
          contentMap['images'] = _uploadedImages;
          print('🔍 Added images to contentMap: $_uploadedImages');
        }

        if (_uploadedVideos.isNotEmpty) {
          contentMap['videos'] = _uploadedVideos;
        }

        // Note: meta field is deprecated - we only use the new linkSchema format now
      }

      final requestData = {
        'content': contentMap,
        if (currentMessage.replyTo != null)
          'replyToId': currentMessage.replyTo!.messageId,
      };

      // Send to API using the unified sendMessage method
      Map<String, dynamic>? response = await ChatApiService.sendMessage(
        widget.clubId,
        requestData,
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      // Handle successful response
      await _handleSuccessResponse(response, linkMeta);
    } catch (e) {
      await _handleSendFailure('Failed to send message: $e');
    }
  }

  bool _hasUploads() {
    return _uploadedImages.isNotEmpty ||
        _uploadedVideos.isNotEmpty ||
        _uploadedDocuments.isNotEmpty ||
        _uploadedAudio != null;
  }

  Future<void> _handleSuccessResponse(
    Map<String, dynamic> response,
    List<LinkMetadata> linkMeta,
  ) async {
    try {
      print('🔍 _handleSuccessResponse: Full response = $response');

      // Extract message data from response
      Map<String, dynamic>? messageData;

      if (response.containsKey('data') && response['data'] is Map) {
        messageData = response['data'] as Map<String, dynamic>;
      } else if (response.containsKey('message') &&
          response['message'] is Map) {
        messageData = response['message'] as Map<String, dynamic>;
      } else {
        messageData = response;
      }

      print('🔍 _handleSuccessResponse: Extracted messageData = $messageData');

      // Create new message from server response
      var finalMessage = ClubMessage.fromJson(messageData);
      
      // Preserve locally extracted link metadata if we have richer local data
      if (linkMeta.isNotEmpty) {
        if (finalMessage.linkMeta.isEmpty) {
          // Server provided no link metadata, use our local data
          finalMessage = finalMessage.copyWith(linkMeta: linkMeta);
        } else {
          // Check if our local metadata is more complete than server's
          final serverMeta = finalMessage.linkMeta.first;
          final localMeta = linkMeta.first;
          
          // Prefer local metadata if it has siteName/favicon (richer data)
          if (localMeta.siteName != null || localMeta.favicon != null) {
            finalMessage = finalMessage.copyWith(linkMeta: linkMeta);
          }
        }
      }

      // Save to storage
      await MessageStorageService.addMessage(widget.clubId, finalMessage);

      // Update current message
      if (mounted) {
        setState(() {
          currentMessage = finalMessage;
        });
      }

      // Notify parent of update
      widget.onMessageUpdated?.call(widget.message, finalMessage);

      // Mark as delivered
      await _markAsDelivered(finalMessage.id);
    } catch (e) {
      await _handleSendFailure('Failed to process response: $e');
    }
  }

  Future<void> _handleSendFailure(String errorMessage) async {
    final failedMessage = currentMessage.copyWith(
      status: MessageStatus.failed,
      errorMessage: errorMessage,
    );

    if (mounted) {
      setState(() {
        currentMessage = failedMessage;
      });
    }

    widget.onMessageUpdated?.call(widget.message, failedMessage);
    widget.onMessageFailed?.call(currentMessage.id);
  }

  Future<void> _markAsDelivered(String messageId) async {
    try {
      await ChatApiService.markAsDelivered(widget.clubId, messageId);

      await MessageStorageService.markAsDelivered(widget.clubId, messageId);

      // Update message status to delivered
      final deliveredMessage = currentMessage.copyWith(
        status: MessageStatus.delivered,
        deliveredAt: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          currentMessage = deliveredMessage;
        });
      }

      widget.onMessageUpdated?.call(currentMessage, deliveredMessage);
    } catch (e) {
      print('⚠️ Failed to mark message as delivered: $e');
    }
  }

  Future<LinkMetadata?> _fetchLinkMetadata(String url) async {
    try {
      final ogData = await OpenGraphService.fetchMetadata(url);
      return LinkMetadata(
        url: ogData.url,
        title: ogData.title,
        description: ogData.description,
        image: ogData.image,
        siteName: ogData.siteName ?? Uri.parse(url).host, // Get domain name as fallback
        favicon: ogData.favicon,
      );
    } catch (e) {
      debugPrint('Failed to fetch link metadata for $url: $e');
      // Create basic link metadata if OG data fails
      return LinkMetadata(
        url: url, 
        title: url,
        siteName: Uri.parse(url).host,
      );
    }
  }

  String _determineMessageType(String content, List<LinkMetadata> linkMeta) {
    // PRIORITY 1: Check for uploaded media first (highest priority)
    // For standalone media files without meaningful text content, use specific media types
    if (_uploadedAudio != null && content.trim().isEmpty) return 'audio';
    if (_uploadedDocuments.isNotEmpty && content.trim().isEmpty) {
      return 'document';
    }

    // IMPORTANT: According to API schema, there is NO 'image' or 'video' type!
    // Images and videos should be sent as 'text' type with images/videos arrays

    // PRIORITY 2: If we have ANY uploaded media, always use 'text' type
    // This includes images, videos, and mixed media
    if (_uploadedImages.isNotEmpty ||
        _uploadedVideos.isNotEmpty ||
        _uploadedAudio != null ||
        _uploadedDocuments.isNotEmpty) {
      return 'text';
    }

    // PRIORITY 3: Check if message is emoji-only (only if no media)
    final emojiOnlyPattern = RegExp(
      r'^(\s*[\p{Emoji}\p{Emoji_Modifier}\p{Emoji_Component}\p{Emoji_Modifier_Base}\p{Emoji_Presentation}\u200d]*\s*)+$',
      unicode: true,
    );
    final isEmojiOnly =
        emojiOnlyPattern.hasMatch(content) &&
        content.trim().length <= 12 &&
        content.trim().isNotEmpty;

    if (isEmojiOnly) {
      return 'emoji';
    } else if (linkMeta.isNotEmpty) {
      // If we have link metadata, this is a link message (regardless of additional text)
      return 'link';
    } else {
      // For all other cases (pure text messages), use 'text'
      return 'text';
    }
  }

  void _handleRetry() {
    if (currentMessage.status == MessageStatus.failed) {
      final retryMessage = currentMessage.copyWith(
        status: MessageStatus.sending,
        errorMessage: null,
      );
      if (mounted) {
        setState(() {
          currentMessage = retryMessage;
          // Reset upload state for retry
          _uploadProgress = 0.0;
          _completedUploads = 0;
          _isUploading = false;
        });
      }
      widget.onMessageUpdated?.call(widget.message, retryMessage);
      _startSendProcess();
    }
  }

  Widget _buildImageUploadPreview() {
    if (widget.pendingUploads == null || widget.pendingUploads!.isEmpty) {
      return SizedBox.shrink();
    }

    final imageFiles = widget.pendingUploads!.where(_isImageFile).toList();
    if (imageFiles.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: imageFiles.length == 1
          ? _buildImageWithProgress(imageFiles[0].path!, imageFiles[0].name)
          : GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: imageFiles.length > 4 ? 4 : imageFiles.length,
              itemBuilder: (context, index) {
                final file = imageFiles[index];
                return _buildImageWithProgress(file.path!, file.name);
              },
            ),
    );
  }

  bool _isImageFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase() ?? '';
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }

  Widget _buildImageWithProgress(String imagePath, String fileName) {
    final progress = _fileUploadProgress[fileName] ?? 0.0;
    final isUploading = progress > 0.0 && progress < 1.0;
    final isLocal =
        imagePath.startsWith('/') || imagePath.startsWith('file://');

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isLocal
                ? Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.image,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  )
                : Image.network(
                    imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.image,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
          ),

          // Upload progress overlay
          if (isUploading)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withOpacity(0.6),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadProgressWidget() {
    if (!_isUploading && !_isSending) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUploading) ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Uploading $_currentUploadFile...',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$_completedUploads/$_totalUploads',
                  style: const TextStyle(fontSize: 10, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.blue.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ] else if (_isSending) ...[
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Sending message...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show upload progress if uploading or sending
    if (_isUploading || (_isSending && !_hasUploads())) {
      return Column(
        crossAxisAlignment: widget.isOwn
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Show image upload preview with progress
          _buildImageUploadPreview(),

          // Show basic progress info for text/other uploads
          _buildUploadProgressWidget(),

          // Show text content if any
          if (currentMessage.content.trim().isNotEmpty)
            Opacity(
              opacity: 0.7,
              child: MessageBubbleFactory(
                message: currentMessage.copyWith(
                  images: [],
                ), // Remove pictures to avoid duplication
                isOwn: widget.isOwn,
                isPinned: widget.isPinned,
                isDeleted: widget.isDeleted,
                isSelected: widget.isSelected,
                showSenderInfo: widget.showSenderInfo,
                onRetryUpload: null,
              ),
            ),
        ],
      );
    }

    // Show normal bubble with retry functionality for failed messages
    return GestureDetector(
      onTap: currentMessage.status == MessageStatus.failed
          ? _handleRetry
          : null,
      child: Column(
        crossAxisAlignment: widget.isOwn
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          MessageBubbleFactory(
            message: currentMessage,
            isOwn: widget.isOwn,
            isPinned: widget.isPinned,
            isDeleted: widget.isDeleted,
            isSelected: widget.isSelected,
            showSenderInfo: widget.showSenderInfo,
            onRetryUpload: currentMessage.status == MessageStatus.failed
                ? _handleRetry
                : null,
          ),
          // Show error message for failed sends
          if (currentMessage.status == MessageStatus.failed &&
              currentMessage.errorMessage != null)
            Container(
              margin: EdgeInsets.only(
                top: 4,
                left: widget.isOwn ? 60 : 40,
                right: widget.isOwn ? 40 : 60,
              ),
              child: Row(
                mainAxisAlignment: widget.isOwn
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      currentMessage.errorMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
