import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import '../widgets/audio_recording_widget.dart';
import '../widgets/image_caption_dialog.dart';
import '../screens/media_caption_screen.dart';
import '../models/media_item.dart';
import '../services/video_compression_service.dart';
import '../services/file_upload_service.dart';
import '../widgets/selectors/unified_event_picker.dart';
import '../widgets/selectors/poll_picker.dart';
import '../widgets/mentionable_text_field.dart';
import '../widgets/pasteable_text_field.dart';
import '../widgets/url_preview_card.dart';

import '../models/club_message.dart';
import '../models/message_status.dart';
import '../models/message_document.dart';
import '../models/starred_info.dart';
import '../models/message_audio.dart';
import '../models/match.dart';
import '../models/poll.dart';
import '../models/link_metadata.dart';
import '../models/mention.dart';
import '../services/open_graph_service.dart';
import '../services/chat_api_service.dart';
import 'package:provider/provider.dart';
import '../providers/club_provider.dart';
import '../providers/user_provider.dart';

/// A comprehensive self-contained message input widget for chat functionality
/// Handles text input, file attachments, camera capture, and audio recording
class MessageInput extends StatefulWidget {
  /// Closes the attachment menu if it's open
  static void closeAttachmentMenuIfOpen(GlobalKey<MessageInputState> key) {
    key.currentState?.closeAttachmentMenu();
  }

  final TextEditingController messageController;
  final FocusNode textFieldFocusNode;
  final String clubId;
  final GlobalKey<AudioRecordingWidgetState> audioRecordingKey;
  final String? upiId;
  final String? userRole;

  // Simplified callbacks - only what's needed
  final Function(ClubMessage) onSendMessage;
  final VoidCallback? onAttachmentMenuClose;

  // Mention callbacks for external drawer handling
  final Function(bool, List<Mention>, String, bool)? onMentionStateChanged;

  const MessageInput({
    super.key,
    required this.messageController,
    required this.textFieldFocusNode,
    required this.clubId,
    required this.audioRecordingKey,
    required this.onSendMessage,
    this.onAttachmentMenuClose,
    this.upiId,
    this.userRole,
    this.onMentionStateChanged,
  });

  @override
  State<MessageInput> createState() => MessageInputState();
}

class MessageInputState extends State<MessageInput> {
  bool _isComposing = false;
  bool _isAttachmentMenuOpen = false;
  double _lastKnownKeyboardHeight = 0.0;

  // Mention related state
  List<Mention> _mentionSuggestions = [];
  bool _showMentionOverlay = false;
  bool _isLoadingMentions = false;
  String _currentMentionQuery = '';
  late final MentionableTextFieldController _mentionableController;

  /// Closes the attachment menu if it's open
  void closeAttachmentMenu() {
    if (_isAttachmentMenuOpen) {
      setState(() {
        _isAttachmentMenuOpen = false;
      });
    }
  }

  /// Getter to check if attachment menu is open
  bool get isAttachmentMenuOpen => _isAttachmentMenuOpen;

  /// Helper method to close attachment menu
  void _closeAttachmentMenu() {
    if (_isAttachmentMenuOpen) {
      setState(() {
        _isAttachmentMenuOpen = false;
      });
    }
  }

  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _availableUpiApps = [];

  // Mention handling methods
  void _handleMentionTriggered(String query) {
    setState(() {
      _currentMentionQuery = query;
      _showMentionOverlay = true;
      _isLoadingMentions = true;
    });
    _searchMentions(query);
    _notifyMentionStateChanged();
  }

  void _handleMentionCancelled() {
    setState(() {
      _showMentionOverlay = false;
      _mentionSuggestions.clear();
      _currentMentionQuery = '';
      _isLoadingMentions = false;
    });
    _notifyMentionStateChanged();
  }

  void _notifyMentionStateChanged() {
    widget.onMentionStateChanged?.call(
      _showMentionOverlay,
      _mentionSuggestions,
      _currentMentionQuery,
      _isLoadingMentions,
    );
  }

  void handleMentionSelected(Mention mention) {
    print('🔍 handleMentionSelected called with: ${mention.name}');

    // Use the controller to handle mention selection
    _mentionableController.selectMentionExternal(mention);

    print(
      '🔍 After selectMentionExternal, current text: ${_mentionableController.text}',
    );

    // Then close the overlay
    setState(() {
      _showMentionOverlay = false;
      _mentionSuggestions.clear();
      _currentMentionQuery = '';
      _isLoadingMentions = false;
    });
    _notifyMentionStateChanged();

    print('🔍 Overlay closed, final text: ${_mentionableController.text}');
  }

  Future<void> _searchMentions(String query) async {
    try {
      print('🔍 Searching mentions for: "$query"');

      // Get current user ID to filter out self
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.user?.id;

      // Use the new centralized caching system with case-insensitive search
      final response = await ChatApiService.searchMembers(
        widget.clubId,
        query: query,
        limit: 4, // Reduced for compact display
      );

      final mentions = response
          .map(
            (member) => Mention(
              id: member['id'],
              name: member['name'],
              profilePicture: member['profilePicture'],
              role: member['role'],
            ),
          )
          .where(
            (mention) => mention.id != currentUserId,
          ) // Filter out current user
          .toList();

      if (mounted) {
        setState(() {
          _mentionSuggestions = mentions;
          _isLoadingMentions = false;
        });
        _notifyMentionStateChanged();
      }
    } catch (e) {
      print('❌ Error searching mentions: $e');
      if (mounted) {
        setState(() {
          _mentionSuggestions.clear();
          _isLoadingMentions = false;
        });
        _notifyMentionStateChanged();
      }
    }
  }

  // Link preview state
  List<LinkMetadata> _linkMetadata = [];
  String? _lastProcessedText;
  bool _isLoadingLinkPreview = false;

  @override
  void initState() {
    super.initState();
    _mentionableController = MentionableTextFieldController();
    // Initialize with the same text as the original controller
    _mentionableController.text = widget.messageController.text;

    // Keep controllers synchronized
    _mentionableController.addListener(_syncFromMentionableController);
    widget.messageController.addListener(_syncFromOriginalController);

    if (widget.upiId != null && widget.upiId!.isNotEmpty) {
      _checkAvailableUpiApps();
    }

    // Listen for focus changes to close attachment menu when keyboard opens
    widget.textFieldFocusNode.addListener(_onFocusChange);

    // Preload members cache for faster mention search
    _preloadMembersCache();
  }

  /// Preload members cache for faster mention suggestions
  void _preloadMembersCache() {
    // Run in background without blocking UI
    ChatApiService.getAllMembers(widget.clubId)
        .then((members) {
          print(
            '📋 Preloaded ${members.length} members for club ${widget.clubId}',
          );
        })
        .catchError((error) {
          print('⚠️ Failed to preload members cache: $error');
        });
  }

  @override
  void dispose() {
    widget.textFieldFocusNode.removeListener(_onFocusChange);
    _mentionableController.removeListener(_syncFromMentionableController);
    widget.messageController.removeListener(_syncFromOriginalController);
    super.dispose();
  }

  // Synchronization methods to keep both controllers in sync
  void _syncFromMentionableController() {
    if (_mentionableController.text != widget.messageController.text) {
      widget.messageController.value = widget.messageController.value.copyWith(
        text: _mentionableController.text,
      );
    }
  }

  void _syncFromOriginalController() {
    if (widget.messageController.text != _mentionableController.text) {
      _mentionableController.value = _mentionableController.value.copyWith(
        text: widget.messageController.text,
      );

      // Also trigger link preview processing when text is set programmatically (e.g., from shared content)
      print('🔄 [MessageInput] Text synced from original controller: ${widget.messageController.text}');
      _handleTextChanged(widget.messageController.text);
    }
  }

  void _onFocusChange() {
    // Only close attachment menu if keyboard is becoming visible
    // This prevents the jarring close/reopen behavior
    if (widget.textFieldFocusNode.hasFocus && _isAttachmentMenuOpen) {
      print('🎯 Focus gained, will close attachment menu');
      // Only close if this is a user-initiated focus, not programmatic
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isAttachmentMenuOpen) {
          _closeAttachmentMenu();
        }
      });
    }
  }

  void _handleTextChanged(String value) {
    final isComposing = value.trim().isNotEmpty;
    if (_isComposing != isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
    }

    // Handle link preview parsing
    _handleLinkPreview(value);
  }

  void _handleLinkPreview(String text) async {
    // Avoid processing the same text multiple times
    if (_lastProcessedText == text) return;
    _lastProcessedText = text;

    // Clear previous metadata if text is empty
    if (text.trim().isEmpty) {
      if (_linkMetadata.isNotEmpty) {
        setState(() {
          _linkMetadata.clear();
        });
      }
      return;
    }

    // Look for URLs in the text with enhanced pattern
    final urlPattern = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?',
      caseSensitive: false,
    );

    print('🔗 [LinkPreview] Processing text: $text');
    print('🔗 [LinkPreview] URL pattern matches: ${urlPattern.allMatches(text).map((m) => m.group(0)).toList()}');
    final matches = urlPattern.allMatches(text);

    if (matches.isEmpty) {
      // No URLs found, clear metadata
      if (_linkMetadata.isNotEmpty) {
        setState(() {
          _linkMetadata.clear();
        });
      }
      return;
    }

    // Process the first URL found
    final url = matches.first.group(0)!;
    print('🔗 [LinkPreview] Found URL: $url');

    // Don't fetch if we already have metadata for this URL
    if (_linkMetadata.isNotEmpty && _linkMetadata.first.url == url) {
      print('🔗 [LinkPreview] Already have metadata for this URL, skipping');
      return;
    }

    print('🔗 [LinkPreview] Fetching metadata for URL: $url');

    // Show loading state
    setState(() {
      _isLoadingLinkPreview = true;
    });

    try {
      final metadata = await _fetchLinkMetadata(url);
      print('🔗 [LinkPreview] Metadata fetch result: ${metadata != null ? 'SUCCESS' : 'FAILED'}');
      if (metadata != null) {
        print('🔗 [LinkPreview] Metadata: title="${metadata.title}", description="${metadata.description}", image="${metadata.image}"');
      }

      if (metadata != null && _lastProcessedText == text) {
        setState(() {
          _linkMetadata = [metadata];
          _isLoadingLinkPreview = false;
        });
        print('🔗 [LinkPreview] Metadata stored in state');
      } else {
        setState(() {
          _linkMetadata.clear();
          _isLoadingLinkPreview = false;
        });
        print('🔗 [LinkPreview] Metadata cleared (either null or text changed)');
      }
    } catch (e) {
      print('❌ [LinkPreview] Error fetching link metadata: $e');
      setState(() {
        _linkMetadata.clear();
        _isLoadingLinkPreview = false;
      });
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
        siteName: ogData.siteName ?? Uri.parse(url).host,
        favicon: ogData.favicon,
      );
    } catch (e) {
      print('❌ Failed to fetch link metadata for $url: $e');
      return null;
    }
  }

  void _sendTextMessage() {
    final text = _mentionableController.text.trim();

    if (text.isEmpty) return;

    // Extract mentions from the text field (contains @[id:name] format)
    final mentions = <MentionedUser>[];

    // Extract mentions from the text using regex
    final mentionRegex = RegExp(r'@\[([^:]+):([^\]]+)\]');
    final mentionMatches = mentionRegex.allMatches(text);

    for (final match in mentionMatches) {
      final userId = match.group(1);
      final userName = match.group(2);

      if (userId != null && userName != null) {
        mentions.add(
          MentionedUser(
            id: userId,
            name: userName,
            role: 'MEMBER', // Default role
          ),
        );
      }
    }

    // Create display text by replacing mention format for UI
    final finalDisplayText = text.replaceAllMapped(
      mentionRegex,
      (match) =>
          '@${match.group(2)}', // Show @Username instead of @[id:username]
    );

    print('📝 Sending message with ${mentions.length} mentions');
    for (final mention in mentions) {
      print('   - @${mention.name} (${mention.id})');
    }

    print('📤 [MessageInput] Creating message...');
    print('📤 [MessageInput] Content: $finalDisplayText');
    print('📤 [MessageInput] Link metadata count: ${_linkMetadata.length}');
    if (_linkMetadata.isNotEmpty) {
      print('📤 [MessageInput] First link metadata: title="${_linkMetadata.first.title}", url="${_linkMetadata.first.url}"');
    }
    print('📤 [MessageInput] Message type: ${_linkMetadata.isNotEmpty ? 'link' : 'text'}');

    // Create temp message with link metadata and mentions
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user', // Will be filled by parent
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: finalDisplayText, // Use display text for UI
      messageType: _linkMetadata.isNotEmpty ? 'link' : 'text',
      linkMeta: _linkMetadata, // Include parsed link metadata
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      mentions: mentions, // Include extracted mentions
      hasMentions: mentions.isNotEmpty,
    );

    print('📤 [MessageInput] Message created with ${tempMessage.linkMeta.length} link metadata items');

    _mentionableController.clear();
    // Also clear the original controller to keep them in sync
    widget.messageController.clear();
    setState(() {
      _isComposing = false;
      _linkMetadata.clear();
      _lastProcessedText = null;
      _isLoadingLinkPreview = false;
    });

    widget.onSendMessage(tempMessage);
  }

  void _handleCameraCapture() {
    // Directly capture photo (camera button = photo)
    _capturePhoto();
  }

  void _pickImages() async {
    // Allow selecting both images and videos from gallery
    _pickImagesAndVideos();
  }

  void _pickImagesAndVideos() async {
    try {
      // Use file picker to allow both images and videos
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media, // This allows both images and videos
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // Convert all selected files to XFile objects
        final selectedFiles = <XFile>[];
        for (final file in result.files) {
          if (file.path != null) {
            selectedFiles.add(XFile(file.path!));
          }
        }

        if (selectedFiles.isNotEmpty) {
          // Show caption screen for all selected media at once
          _showMediaCaptionScreen(selectedFiles);
        }
      }
    } catch (e) {
      _showError('Failed to pick media: $e');
    }
  }

  void _capturePhoto() async {
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

  void _captureVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2), // Limit video duration
      );

      if (video != null) {
        _showVideoCaptionDialog(video);
      }
    } catch (e) {
      _showError('Failed to capture video: $e');
    }
  }

  void _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        _sendDocumentMessage(result.files);
      }
    } catch (e) {
      _showError('Failed to pick documents: $e');
    }
  }

  void _pickAudioFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
      );

      if (result != null && result.files.isNotEmpty) {
        _sendAudioFileMessage(result.files);
      }
    } catch (e) {
      _showError('Failed to pick audio files: $e');
    }
  }

  void _showMediaCaptionScreen(List<XFile> mediaFiles) async {
    // Convert XFiles to MediaItem objects and generate thumbnails for videos
    final mediaItems = <MediaItem>[];

    for (final file in mediaFiles) {
      var mediaItem = MediaItem.fromPath(file.path);

      // Generate thumbnail for videos
      if (mediaItem.isVideo) {
        print('🖼️ MessageInput: Generating thumbnail for video: ${file.path}');
        final thumbnailPath = await VideoCompressionService.generateThumbnail(
          file.path,
        );
        if (thumbnailPath != null) {
          mediaItem = mediaItem.copyWith(thumbnailPath: thumbnailPath);
          print('✅ MessageInput: Thumbnail generated: $thumbnailPath');
        } else {
          print('⚠️ MessageInput: Failed to generate thumbnail for video');
        }
      }

      mediaItems.add(mediaItem);
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaCaptionScreen(
            mediaItems: mediaItems,
            title: mediaFiles.length == 1
                ? (mediaItems.first.isVideo ? 'Send Video' : 'Send Image')
                : 'Send ${mediaFiles.length} items',
            onSend: (mediaItems) {
              _sendMediaMessage(mediaItems);
            },
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  // Legacy method for single image - redirects to new media screen
  void _showImageCaptionDialog(XFile image) async {
    _showMediaCaptionScreen([image]);
  }

  // Legacy method for single video - redirects to new media screen
  void _showVideoCaptionDialog(XFile video) async {
    _showMediaCaptionScreen([video]);
  }

  void _sendMediaMessage(List<MediaItem> mediaItems) async {
    print(
      '🔍 MessageInput: Creating message with ${mediaItems.length} media items',
    );

    // Use empty content - individual captions are preserved in media items
    String content = '';

    // Create initial message with all media items
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user',
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: content,
      messageType: mediaItems.length == 1
          ? (mediaItems.first.isVideo ? 'video' : 'image')
          : 'media',
      createdAt: DateTime.now(),
      status: MessageStatus.preparing,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      media: mediaItems,
      processingStatus: 'Preparing media...',
    );

    // Send the message immediately to show in chat
    widget.onSendMessage(tempMessage);

    // Process media items in background
    _processMediaItems(tempMessage, mediaItems);
  }

  Future<void> _processMediaItems(
    ClubMessage message,
    List<MediaItem> mediaItems,
  ) async {
    final processedMediaItems = <MediaItem>[];

    for (int i = 0; i < mediaItems.length; i++) {
      final item = mediaItems[i];

      try {
        if (item.isVideo) {
          // Update status for compression
          _updateMessageProgress(
            message,
            i,
            mediaItems.length,
            'Processing video ${i + 1}/${mediaItems.length}...',
            MessageStatus.compressing,
          );

          final needsCompression =
              await VideoCompressionService.needsCompression(item.url);
          String finalVideoPath = item.url;
          String? thumbnailPath = item.thumbnailPath;

          // Generate thumbnail if not already generated
          if (thumbnailPath == null) {
            print(
              '🖼️ MessageInput: Generating thumbnail during processing for ${item.url}',
            );
            thumbnailPath = await VideoCompressionService.generateThumbnail(
              item.url,
            );
          }

          if (needsCompression) {
            final compressedPath = await VideoCompressionService.compressVideo(
              inputPath: item.url,
              deleteOriginal: false,
              onProgress: (progress) {
                // Update compression progress for this specific item
                _updateMediaItemProgress(
                  message,
                  i,
                  compressionProgress: progress,
                );
              },
            );

            if (compressedPath != null) {
              finalVideoPath = compressedPath;
            }
          }

          processedMediaItems.add(
            item.copyWith(
              url: finalVideoPath,
              originalPath: item.url,
              thumbnailPath: thumbnailPath,
              compressionProgress: 100.0,
            ),
          );
        } else {
          // For images, just add directly
          processedMediaItems.add(item);
        }
      } catch (e) {
        print('❌ Error processing media item $i: $e');
        // Add original item if processing fails
        processedMediaItems.add(item);
      }
    }

    // Update message with processed media and start uploading
    _updateMessageProgress(
      message,
      0,
      mediaItems.length,
      'Uploading media...',
      MessageStatus.uploading,
    );

    // Upload media files and update URLs
    final uploadedMediaItems = <MediaItem>[];

    for (int i = 0; i < processedMediaItems.length; i++) {
      final item = processedMediaItems[i];

      try {
        // Update upload progress for this specific item
        _updateMediaItemProgress(message, i, uploadProgress: 0.0);

        if (item.isVideo) {
          // Upload video with thumbnail
          final uploadResult = await FileUploadService.uploadVideoWithThumbnail(
            videoPath: item.url,
            thumbnailPath: item.thumbnailPath!,
            videoName: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
            thumbnailName: 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

          final videoUrl = uploadResult['videoUrl'];
          final thumbnailUrl = uploadResult['thumbnailUrl'];

          if (videoUrl != null) {
            print('✅ Video uploaded successfully: $videoUrl');
            print('🖼️ Thumbnail uploaded: $thumbnailUrl');

            uploadedMediaItems.add(
              item.copyWith(
                url: videoUrl,
                thumbnailUrl: thumbnailUrl,
                isLocal: false,
                uploadProgress: 100.0,
              ),
            );
          } else {
            print('❌ Video upload failed, keeping local file');
            uploadedMediaItems.add(item.copyWith(uploadProgress: 0.0));
          }
        } else if (item.isImage) {
          // Upload image
          final imageUrl = await FileUploadService.uploadFileFromPath(
            item.url,
            customName: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

          if (imageUrl != null) {
            print('✅ Image uploaded successfully: $imageUrl');
            uploadedMediaItems.add(
              item.copyWith(
                url: imageUrl,
                isLocal: false,
                uploadProgress: 100.0,
              ),
            );
          } else {
            print('❌ Image upload failed, keeping local file');
            uploadedMediaItems.add(item.copyWith(uploadProgress: 0.0));
          }
        } else {
          // For other types, just add as-is
          uploadedMediaItems.add(item);
        }

        // Update upload progress for this specific item
        _updateMediaItemProgress(message, i, uploadProgress: 100.0);
      } catch (e) {
        print('❌ Upload failed for item $i: $e');
        uploadedMediaItems.add(item.copyWith(uploadProgress: 0.0));
      }
    }

    // Create final message with uploaded media - mark as sending (not sent) so API call happens
    final finalMessage = message.copyWith(
      media: uploadedMediaItems,
      status: MessageStatus.sending,
      processingStatus: null,
      uploadProgress: null,
      compressionProgress: null,
    );

    widget.onSendMessage(finalMessage);
  }

  void _updateMessageProgress(
    ClubMessage message,
    int currentItem,
    int totalItems,
    String status,
    MessageStatus messageStatus,
  ) {
    final updatedMessage = message.copyWith(
      status: messageStatus,
      processingStatus: status,
    );
    widget.onSendMessage(updatedMessage);
  }

  void _updateMediaItemProgress(
    ClubMessage message,
    int itemIndex, {
    double? compressionProgress,
    double? uploadProgress,
  }) {
    final updatedMedia = List<MediaItem>.from(message.media);
    if (itemIndex < updatedMedia.length) {
      updatedMedia[itemIndex] = updatedMedia[itemIndex].copyWith(
        compressionProgress: compressionProgress,
        uploadProgress: uploadProgress,
      );

      final updatedMessage = message.copyWith(media: updatedMedia);
      widget.onSendMessage(updatedMessage);
    }
  }

  // Legacy method for backward compatibility
  void _sendImageMessageWithCaption(String caption, String imagePath) {
    final mediaItem = MediaItem.fromPath(imagePath, caption: caption);
    _sendMediaMessage([mediaItem]);
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
        media: [MediaItem.fromPath(image.path)],
      );

      widget.onSendMessage(tempMessage);
    }
  }

  void _sendVideoMessageWithCaption(String caption, String videoPath) async {
    print('🔍 MessageInput: Creating message with videoPath: $videoPath');
    print('🔍 MessageInput: Caption: "$caption"');
    print('🔍 MessageInput: ClubId: ${widget.clubId}');

    try {
      // Check if video needs compression BEFORE creating message
      final needsCompression = await VideoCompressionService.needsCompression(
        videoPath,
      );
      String finalVideoPath = videoPath;

      if (needsCompression) {
        print('🎬 MessageInput: Video needs compression, starting...');

        // Show compression progress if needed
        final compressedPath = await VideoCompressionService.compressVideo(
          inputPath: videoPath,
          deleteOriginal: false,
          onProgress: (progress) {
            print(
              '📊 Video compression progress: ${progress.toStringAsFixed(1)}%',
            );
            // You could update UI here to show compression progress
          },
        );

        if (compressedPath != null) {
          finalVideoPath = compressedPath;
          print(
            '✅ MessageInput: Video compressed successfully: $finalVideoPath',
          );
        } else {
          print('❌ MessageInput: Video compression failed, using original');
          // Continue with original file if compression fails
        }
      } else {
        print('✅ MessageInput: Video doesn\'t need compression');
      }

      // Create final message with compressed video path (only send once)
      final finalMessage = ClubMessage(
        id: 'temp_video_${DateTime.now().millisecondsSinceEpoch}',
        clubId: widget.clubId,
        senderId: 'current_user',
        senderName: 'You',
        senderProfilePicture: null,
        senderRole: 'MEMBER',
        content: caption.trim(),
        messageType: 'video',
        createdAt: DateTime.now(),
        status: MessageStatus.sending,
        starred: StarredInfo(isStarred: false),
        pin: PinInfo(isPinned: false),
        // Store final compressed file path for upload (videos go in images array)
        media: [MediaItem.fromPath(finalVideoPath, caption: caption)],
      );

      // Send only the final message with compressed video
      print(
        '🔍 MessageInput: Calling widget.onSendMessage for compressed video',
      );
      widget.onSendMessage(finalMessage);
      print('🔍 MessageInput: Sent final message with compressed video');
    } catch (e) {
      print('❌ MessageInput: Error during video compression: $e');

      // Create fallback message with original video if compression fails
      final fallbackMessage = ClubMessage(
        id: 'temp_video_${DateTime.now().millisecondsSinceEpoch}',
        clubId: widget.clubId,
        senderId: 'current_user',
        senderName: 'You',
        senderProfilePicture: null,
        senderRole: 'MEMBER',
        content: caption.trim(),
        messageType: 'video',
        createdAt: DateTime.now(),
        status: MessageStatus.sending,
        starred: StarredInfo(isStarred: false),
        pin: PinInfo(isPinned: false),
        media: [MediaItem.fromPath(videoPath, caption: caption)],
      );

      widget.onSendMessage(fallbackMessage);
    }
  }

  void _handlePastedImages(List<String> imagePaths) {
    print('📋 Handling pasted images: ${imagePaths.length} images');

    if (imagePaths.isEmpty) return;

    // Add a temporary placeholder text to show send arrow
    final placeholderText = '📋 Image ready to send';
    widget.messageController.text = placeholderText;
    _mentionableController.text = placeholderText;

    // Update composing state to show send arrow
    setState(() {
      _isComposing = true;
    });

    // Handle the first image through the caption dialog (same as regular image selection)
    _showPastedImageCaptionDialog(imagePaths.first);

    // If there are multiple pasted images, send the rest without caption dialog
    if (imagePaths.length > 1) {
      for (int i = 1; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final tempMessage = ClubMessage(
          id: 'temp_pasted_${DateTime.now().millisecondsSinceEpoch}_$i',
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
          media: [MediaItem.fromPath(imagePath)],
        );

        print('📋 Sending additional pasted image: $imagePath');
        widget.onSendMessage(tempMessage);
      }
    }
  }

  void _showPastedImageCaptionDialog(String imagePath) async {
    try {
      final file = File(imagePath);
      final platformFile = PlatformFile(
        name: 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
        path: imagePath,
        size: await file.length(),
        bytes: null,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageCaptionDialog(
              imageFile: platformFile,
              title: 'Send Pasted Image',
              onSend: (caption, croppedImagePath) {
                // Clear the placeholder text
                _clearPastedImagePlaceholder();
                _sendImageMessageWithCaption(
                  caption,
                  croppedImagePath ?? imagePath,
                );
              },
            ),
            fullscreenDialog: true,
          ),
        ).then((_) {
          // Clear placeholder if dialog is dismissed without sending
          if (widget.messageController.text == '📋 Image ready to send') {
            _clearPastedImagePlaceholder();
          }
        });
      }
    } catch (e) {
      print('❌ Error showing pasted image caption dialog: $e');
      // Clear placeholder and fallback: send without caption dialog
      _clearPastedImagePlaceholder();
      _sendImageMessageWithCaption('', imagePath);
    }
  }

  void _clearPastedImagePlaceholder() {
    if (widget.messageController.text == '📋 Image ready to send') {
      widget.messageController.clear();
      _mentionableController.clear();
      setState(() {
        _isComposing = false;
      });
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
        document: MessageDocument(
          url: doc.path ?? '',
          filename: doc.name,
          type: doc.extension ?? 'file',
          size: doc.size.toString(),
        ),
      );

      widget.onSendMessage(tempMessage);
    }
  }

  void _sendAudioFileMessage(List<PlatformFile> audioFiles) {
    for (final audioFile in audioFiles) {
      if (audioFile.path != null) {
        // Use existing _sendAudioMessage function with default duration
        // Duration will be calculated by the backend or during processing
        _sendAudioMessage(audioFile.path!, Duration.zero);
      }
    }
  }

  void _sendAudioMessage(String audioPath, Duration recordingDuration) {
    // Extract audio file information
    final file = File(audioPath);
    final fileName = audioPath.split('/').last;
    final fileSize = file.existsSync() ? file.lengthSync() : 0;

    // Use the duration passed from the recording widget
    final durationInSeconds = recordingDuration.inSeconds;

    print(
      '🎵 _sendAudioMessage: Recording duration = ${recordingDuration.inSeconds}s',
    );
    print('🎵 _sendAudioMessage: File size = $fileSize bytes');

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
        duration: durationInSeconds,
      ),
    );

    widget.onSendMessage(tempMessage);
  }

  void _openMatchPicker() async {
    final clubProvider = Provider.of<ClubProvider>(context, listen: false);
    final selectedMatch = await UnifiedEventPicker.showEventPicker(
      context: context,
      clubId: widget.clubId,
      initialEventType: EventType.match,
      userRole: widget.userRole,
      clubName: clubProvider.currentClub?.club.name,
    );

    if (selectedMatch != null) {
      if (selectedMatch.type.toLowerCase() == 'game' ||
          selectedMatch.type.toLowerCase() == 'match' ||
          selectedMatch.type.toLowerCase() == 'tournament') {
        _sendExistingMatchMessage(selectedMatch);
      } else if (selectedMatch.type.toLowerCase() == 'practice') {
        _sendExistingPracticeMessage(selectedMatch);
      }
    }

    widget.textFieldFocusNode.unfocus();
  }

  void _openPollPicker() async {
    final selectedPoll = await PollPicker.showPollPicker(
      context: context,
      clubId: widget.clubId,
      title: 'Send Poll to Chat',
    );

    if (selectedPoll != null) {
      _sendExistingPollMessage(selectedPoll);
    }

    widget.textFieldFocusNode.unfocus();
  }

  void _sendExistingPracticeMessage(MatchListItem practice) async {
    final practiceBody =
        '⚽ Practice session: ${practice.opponent?.isNotEmpty == true ? practice.opponent! : 'Practice Session'}';

    // Create temporary message for immediate UI update
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user', // Will be filled by parent
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: practiceBody,
      messageType: 'practice',
      practiceId: practice.id,
      meta: _createCleanPracticeMetadata(practice),
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      reactions: const [],
      deliveredTo: const [],
      readBy: const [],
    );

    // Show message immediately in UI
    widget.onSendMessage(tempMessage);

    // Note: Parent widget will handle the API call based on the messageType
    // No manual API call needed - this prevents the duplicate sending issue
  }

  void _sendExistingMatchMessage(MatchListItem match) async {
    final matchBody =
        '📅 Match announcement: ${match.team?.name ?? match.club.name} vs ${match.opponentTeam?.name ?? match.opponent ?? "TBD"}';

    // Create temporary message for immediate UI update
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user', // Will be filled by parent
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: matchBody,
      messageType: 'match',
      matchId: match.id,
      meta: _createCleanMatchMetadata(match),
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      reactions: const [],
      deliveredTo: const [],
      readBy: const [],
    );

    // Show message immediately in UI
    widget.onSendMessage(tempMessage);

    // Note: Parent widget will handle the API call based on the messageType
    // No manual API call needed - this prevents the duplicate sending issue
  }

  void _sendExistingPollMessage(Poll poll) async {
    final pollBody = '📊 Poll: ${poll.question}';

    // Create temporary message for immediate UI update
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user', // Will be filled by parent
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: pollBody,
      messageType: 'poll',
      pollId: poll.id,
      meta: _createCleanPollMetadata(poll),
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      reactions: const [],
      deliveredTo: const [],
      readBy: const [],
    );

    // Show message immediately in UI
    widget.onSendMessage(tempMessage);

    // Note: Parent widget will handle the API call based on the messageType
    // No manual API call needed - this prevents the duplicate sending issue
  }

  void _showKeyboard() {
    // Smooth transition from attachment menu to keyboard
    if (_isAttachmentMenuOpen) {
      _closeAttachmentMenu();
      // Small delay to ensure smooth transition
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          widget.textFieldFocusNode.requestFocus();
        }
      });
    } else {
      widget.textFieldFocusNode.requestFocus();
    }
  }

  void _showUploadOptions() {
    final currentKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Smooth transition from keyboard to attachment menu
    if (widget.textFieldFocusNode.hasFocus && currentKeyboardHeight > 100) {
      // Capture current keyboard height for smooth transition
      _lastKnownKeyboardHeight = currentKeyboardHeight;

      // Show attachment menu IMMEDIATELY at captured height
      setState(() {
        _isAttachmentMenuOpen = true;
      });

      // THEN unfocus to start keyboard hide animation
      // This creates a smooth "morphing" effect as keyboard collapses and attachment menu maintains height
      widget.textFieldFocusNode.unfocus();
    } else {
      // No keyboard visible, show attachment menu normally
      setState(() {
        _isAttachmentMenuOpen = true;
      });
    }
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
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: iconColor),
            ),
            SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _checkAvailableUpiApps() async {
    final clubUpiId = widget.upiId!;
    final clubName = 'Club Payment';

    // Define all UPI apps with their schemes and SVG assets
    // Show all apps as choices without checking availability
    final allUpiApps = [
      {
        'name': 'Google Pay',
        'scheme': 'tez://upi/pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'fallback': 'upi://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'logo': 'assets/icons/upi/google_pay.svg',
        'color': Color(0xFF4285F4),
      },
      {
        'name': 'PhonePe',
        'scheme': 'phonepe://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'fallback': 'upi://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'logo': 'assets/icons/upi/phonepe.svg',
        'color': Color(0xFF5F259F),
      },
      {
        'name': 'Paytm',
        'scheme': 'paytmmp://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'fallback': 'upi://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'logo': 'assets/icons/upi/paytm.svg',
        'color': Color(0xFF00BAF2),
      },
      {
        'name': 'BHIM UPI',
        'scheme': 'bhim://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'fallback': 'upi://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'logo': 'assets/icons/upi/bhim.png',
        'color': Color(0xFF00A651),
      },
      {
        'name': 'Amazon Pay',
        'scheme': 'amazonpay://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'fallback': 'upi://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'logo': 'assets/icons/upi/amazon_pay.svg',
        'color': Color(0xFFFF9900),
      },
      {
        'name': 'Any UPI App',
        'scheme': 'upi://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'fallback': 'upi://pay?pa=$clubUpiId&pn=$clubName&cu=INR',
        'logo': 'assets/icons/upi/upi_generic.svg',
        'color': Colors.grey[700]!,
      },
    ];

    if (mounted) {
      setState(() {
        _availableUpiApps = allUpiApps;
      });
    }
  }

  void _openUPIPayment() async {
    try {
      // Check if UPI ID is available
      if (widget.upiId == null || widget.upiId!.isEmpty) {
        _showError('UPI payment not available for this club.');
        return;
      }

      // Show UPI app selection dialog
      _showUPIAppSelection();
    } catch (e) {
      _showError('Failed to open UPI payment: $e');
    }
  }

  void _showUPIAppSelection() {
    // Use the pre-filtered available UPI apps instead of hardcoded list

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.currency_rupee,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Choose Payment App',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // UPI apps grid
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: _availableUpiApps.length,
              itemBuilder: (context, index) {
                final app = _availableUpiApps[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      _launchUPIApp(
                        app['scheme'] as String,
                        app['fallback'] as String,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.2),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(shape: BoxShape.circle),
                            child: SvgPicture.asset(
                              app['logo'] as String,
                              width: 60,
                              height: 60,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            app['name'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _launchUPIApp(String primaryScheme, String fallbackScheme) async {
    try {
      final primaryUri = Uri.parse(primaryScheme);

      try {
        // Try primary scheme first (app-specific)
        await launchUrl(primaryUri, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // Primary scheme failed, try fallback
        try {
          final fallbackUri = Uri.parse(fallbackScheme);
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          return;
        } catch (e2) {
          // Both schemes failed, show user-friendly error
          _showError(
            'Please install a UPI payment app to complete the payment.',
          );
        }
      }
    } catch (e) {
      _showError('Failed to initiate payment: $e');
    }
  }

  Widget _buildAttachmentMenu() {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final screenSize = mediaQuery.size;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    final breakpointHeight = 335.0 - 50.0; // 285.0

    // Use actual keyboard height when available, otherwise use last known or estimate
    double getTargetHeight() {
      // If keyboard is currently visible and substantial, use its exact height and store it
      if (keyboardHeight > breakpointHeight) {
        _lastKnownKeyboardHeight = keyboardHeight;
        return keyboardHeight;
      }

      // When attachment menu is open, ALWAYS use last known keyboard height if available
      // This prevents collapsing during keyboard hide animation
      if (_isAttachmentMenuOpen &&
          _lastKnownKeyboardHeight > breakpointHeight) {
        return _lastKnownKeyboardHeight;
      }

      // If we have a stored height from recent use and it's reasonable, use that
      if (_lastKnownKeyboardHeight > breakpointHeight) {
        return _lastKnownKeyboardHeight;
      }

      // Otherwise, estimate the height based on device characteristics
      if (isLandscape) {
        // Landscape keyboard heights
        if (screenSize.width > 800) {
          return 240.0; // iPad landscape (increased)
        } else {
          return 200.0; // iPhone landscape (increased)
        }
      } else {
        // Portrait keyboard heights
        if (screenSize.width > 400) {
          return 350.0; // iPad portrait (increased)
        } else if (screenSize.height > 800) {
          return 320.0; // iPhone Plus/Pro Max (increased)
        } else {
          return 300.0; // Standard iPhone (increased)
        }
      }
    }

    final targetHeight = getTargetHeight();

    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: _isAttachmentMenuOpen ? targetHeight : 0.0,
      child: _isAttachmentMenuOpen
          ? ClipRect(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // First row - Photos, Camera, Documents, Audio
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGridOption(
                            icon: Icons.photo_library,
                            iconColor: Color(0xFF2196F3),
                            title: 'Photos',
                            onTap: () {
                              _closeAttachmentMenu();
                              _pickImages();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.camera_alt,
                            iconColor: Color(0xFF4CAF50),
                            title: 'Camera',
                            onTap: () {
                              _closeAttachmentMenu();
                              _handleCameraCapture();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.description,
                            iconColor: Color(0xFF2196F3),
                            title: 'Document',
                            onTap: () {
                              _closeAttachmentMenu();
                              _pickDocuments();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.videocam,
                            iconColor: Color(0xFFE91E63),
                            title: 'Video',
                            onTap: () {
                              _closeAttachmentMenu();
                              _captureVideo();
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Second row - Poll, Match, Payment
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGridOption(
                            icon: Icons.poll,
                            iconColor: Color(0xFFFFC107),
                            title: 'Poll',
                            onTap: () {
                              _closeAttachmentMenu();
                              _openPollPicker();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.sports_cricket,
                            iconColor: Color(0xFFE91E63),
                            title: 'Match',
                            onTap: () {
                              _closeAttachmentMenu();
                              _openMatchPicker();
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.currency_rupee,
                            iconColor: Color(0xFF4CAF50),
                            title: 'Payment',
                            onTap: () {
                              _closeAttachmentMenu();
                              if (_availableUpiApps.isNotEmpty) {
                                _openUPIPayment();
                              }
                            },
                          ),
                          _buildGridOption(
                            icon: Icons.audiotrack,
                            iconColor: Color(0xFFFF9800),
                            title: 'Audio',
                            onTap: () {
                              _closeAttachmentMenu();
                              _pickAudioFiles();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null, // Empty when closed for better performance
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      top: false,
      child: Container(
        //main container
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    Color(0xFF0d1117), // Very dark background
                    Color(0xFF161b22), // Darker background
                  ]
                : [
                    Color(0xFFe3f2fd), // Light blue shade
                    Color(0xFFbbdefb), // Slightly darker light blue
                  ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // URL Preview Card (shown above input when URL is detected)
            if (_linkMetadata.isNotEmpty || _isLoadingLinkPreview)
              UrlPreviewCard(
                linkMetadata: _linkMetadata.isNotEmpty
                    ? _linkMetadata.first
                    : LinkMetadata(url: '', title: 'Loading...', description: '', image: '', siteName: '', favicon: ''),
                isLoading: _isLoadingLinkPreview,
                onClose: () {
                  setState(() {
                    _linkMetadata.clear();
                    _isLoadingLinkPreview = false;
                    _lastProcessedText = null;
                  });
                },
              ),

            // Input field row
            Row(
              children: [
                // Check if audio recording is active - if so, show full-width recording interface
                if (widget.audioRecordingKey.currentState?.isRecording ==
                        true ||
                    widget.audioRecordingKey.currentState?.hasRecording ==
                        true) ...[
                  // Full-width audio recording interface
                  AudioRecordingWidget(
                    key: widget.audioRecordingKey,
                    onAudioRecorded: _sendAudioMessage,
                    isComposing: _isComposing,
                    onRecordingStateChanged: () => setState(() {}),
                  ),
                ] else ...[
                  // Normal input interface
                  // Attachment button (+) or keyboard button
                  IconButton(
                    onPressed: _isAttachmentMenuOpen
                        ? _showKeyboard
                        : _showUploadOptions,
                    icon: Icon(
                      _isAttachmentMenuOpen ? Icons.keyboard : Icons.add,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.9)
                          : Colors.black87,
                    ),
                  ),

                  // Expanded message input area with mention support and image pasting
                  Expanded(
                    child: PasteableTextField(
                      controller: _mentionableController,
                      focusNode: widget.textFieldFocusNode,
                      autofocus: false,
                      mentionSuggestions: _mentionSuggestions,
                      showMentionOverlay: _showMentionOverlay,
                      onMentionTriggered: _handleMentionTriggered,
                      onMentionCancelled: _handleMentionCancelled,
                      onImagesPasted: _handlePastedImages,
                      onTap: () {
                        // Only close attachment menu if it's currently open
                        // This ensures smooth transitions without interference
                        if (_isAttachmentMenuOpen) {
                          print('🎯 TextField tapped, closing attachment menu');
                          _closeAttachmentMenu();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 16, // Reduced for better proportions
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(24),
                          ), // Slightly reduced for cleaner look
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical:
                              6, // Reduced vertical padding for cleaner proportions
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 16, // Reduced for better proportions
                        fontWeight: FontWeight
                            .w400, // Normal weight for clean appearance
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                      maxLines:
                          4, // Reduced from 5 for cleaner multiline handling
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      onChanged: _handleTextChanged,
                    ),
                  ),

                  // UPI Payment button - hidden when composing or no UPI apps available
                  if (!_isComposing && _availableUpiApps.isNotEmpty)
                    IconButton(
                      onPressed: () => _openUPIPayment(),
                      icon: Icon(
                        Icons.currency_rupee,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.9)
                            : Colors.black87,
                      ),
                    ),

                  // Camera button - hidden when composing
                  if (!_isComposing)
                    IconButton(
                      onPressed: _handleCameraCapture,
                      icon: Icon(
                        Icons.camera_alt,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.9)
                            : Colors.black87,
                      ),
                    ),

                  // Send button or audio recording widget
                  if (_isComposing)
                    IconButton(
                      onPressed: _sendTextMessage,
                      icon: const Icon(Icons.send, color: Color(0xFF003f9b)),
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
            // Attachment menu (always present but height animated)
            _buildAttachmentMenu(),
          ],
        ),
      ),
    );
  }

  /// Create clean metadata for practice messages (excludes user-specific data)
  Map<String, dynamic> _createCleanPracticeMetadata(MatchListItem practice) {
    final practiceData = practice.toJson();
    // Remove user-specific fields that shouldn't be in shared meta
    practiceData.remove('userRsvp');
    practiceData.remove('canRsvp');
    practiceData.remove('canSeeDetails');
    return practiceData;
  }

  /// Create clean metadata for match messages (excludes user-specific data)
  Map<String, dynamic> _createCleanPollMetadata(Poll poll) {
    final pollData = poll.toJson();
    // Remove user-specific fields that shouldn't be in shared meta
    pollData.remove('userVote');
    // Transform poll data for message bubble format
    final cleanData = {
      'question': poll.question,
      'options': poll.options
          .map(
            (option) => {
              'id': option.id,
              'text': option.text,
              'votes': option.voteCount,
            },
          )
          .toList(),
      'totalVotes': poll.totalVotes,
      'hasVoted':
          false, // Always false for shared messages - each user tracks their own vote
      'userVotes':
          [], // Empty for shared messages - each user tracks their own votes
      'allowMultiple': false, // Can be expanded later
      'anonymous': false, // Can be expanded later
      'expiresAt': poll.expiresAt?.toIso8601String(),
    };
    return cleanData;
  }

  Map<String, dynamic> _createCleanMatchMetadata(MatchListItem match) {
    final matchData = match.toJson();
    // Remove user-specific fields that shouldn't be in shared meta
    matchData.remove('userRsvp');
    matchData.remove('canRsvp');
    matchData.remove('canSeeDetails');
    // Keep rsvps array for RSVP status detection in message bubbles
    return matchData;
  }
}
