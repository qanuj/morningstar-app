import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import '../widgets/audio_recording_widget.dart';
import '../widgets/image_caption_dialog.dart';
import '../widgets/selectors/unified_event_picker.dart';
import '../widgets/selectors/poll_picker.dart';
import '../widgets/mentionable_text_field.dart';

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

    // Look for URLs in the text
    final urlPattern = RegExp(
      r'http?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?',
      caseSensitive: false,
    );
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

    // Don't fetch if we already have metadata for this URL
    if (_linkMetadata.isNotEmpty && _linkMetadata.first.url == url) {
      return;
    }

    // Start loading indicator - metadata will be fetched

    try {
      final metadata = await _fetchLinkMetadata(url);
      if (metadata != null && _lastProcessedText == text) {
        setState(() {
          _linkMetadata = [metadata];
        });
      } else {
        setState(() {
          _linkMetadata.clear();
        });
      }
    } catch (e) {
      print('❌ Error fetching link metadata: $e');
      setState(() {
        _linkMetadata.clear();
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

    // Extract mentions from the mentionable text field
    final mentions = <MentionedUser>[];

    // Get the display text (with mentions formatted for UI)
    String displayText = text;

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

    // Replace mention format with display format for UI
    displayText = text.replaceAllMapped(
      mentionRegex,
      (match) =>
          '@${match.group(2)}', // Show @Username instead of @[id:username]
    );

    print('📝 Sending message with ${mentions.length} mentions');
    for (final mention in mentions) {
      print('   - @${mention.name} (${mention.id})');
    }

    // Create temp message with link metadata and mentions
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user', // Will be filled by parent
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: 'MEMBER',
      content: displayText, // Use display text for UI
      messageType: _linkMetadata.isNotEmpty ? 'link' : 'text',
      linkMeta: _linkMetadata, // Include parsed link metadata
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
      mentions: mentions, // Include extracted mentions
      hasMentions: mentions.isNotEmpty,
    );

    _mentionableController.clear();
    // Also clear the original controller to keep them in sync
    widget.messageController.clear();
    setState(() {
      _isComposing = false;
      _linkMetadata.clear();
      _lastProcessedText = null;
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
              _sendImageMessageWithCaption(
                caption,
                croppedImagePath ?? image.path,
              );
            },
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _sendImageMessageWithCaption(String caption, String imagePath) {
    print('🔍 MessageInput: Creating message with imagePath: $imagePath');
    print('🔍 MessageInput: Caption: "$caption"');
    print('🔍 MessageInput: ClubId: ${widget.clubId}');
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
      images: [imagePath],
    );
    print(
      '🔍 MessageInput: Created tempMessage with status: ${tempMessage.status}',
    );
    print('🔍 MessageInput: Calling widget.onSendMessage');
    widget.onSendMessage(tempMessage);
    print('🔍 MessageInput: widget.onSendMessage completed');
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
        images: [image.path],
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
                          // Empty space for better alignment
                          SizedBox(width: 60),
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

                  // Expanded message input area with mention support
                  Expanded(
                    child: MentionableTextField(
                      controller: _mentionableController,
                      focusNode: widget.textFieldFocusNode,
                      autofocus: false,
                      mentionSuggestions: _mentionSuggestions,
                      showMentionOverlay: _showMentionOverlay,
                      onMentionTriggered: _handleMentionTriggered,
                      onMentionCancelled: _handleMentionCancelled,
                      // onMentionSelected removed to avoid circular callback
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
                          fontSize: 22, // Increased for better readability
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
                        fontSize:
                            22, // Increased for better readability and visual balance
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
