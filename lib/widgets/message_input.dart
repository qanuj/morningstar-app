import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import '../widgets/audio_recording_widget.dart';
import '../widgets/image_caption_dialog.dart';
import '../widgets/selectors/match_picker.dart';
import '../widgets/selectors/practice_picker.dart';
import '../models/club_message.dart';
import '../models/message_status.dart';
import '../models/message_document.dart';
import '../models/starred_info.dart';
import '../models/message_audio.dart';
import '../models/match.dart';
import '../services/chat_api_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/club_provider.dart';
import '../screens/matches/create_match_screen.dart';
import '../screens/practices/create_practice_screen.dart';

/// A comprehensive self-contained message input widget for chat functionality
/// Handles text input, file attachments, camera capture, and audio recording
class MessageInput extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode textFieldFocusNode;
  final String clubId;
  final GlobalKey<AudioRecordingWidgetState> audioRecordingKey;
  final String? upiId;
  final String? userRole;

  // Simplified callbacks - only what's needed
  final Function(ClubMessage) onSendMessage;

  const MessageInput({
    super.key,
    required this.messageController,
    required this.textFieldFocusNode,
    required this.clubId,
    required this.audioRecordingKey,
    required this.onSendMessage,
    this.upiId,
    this.userRole,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _isComposing = false;
  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _availableUpiApps = [];

  @override
  void initState() {
    super.initState();
    if (widget.upiId != null && widget.upiId!.isNotEmpty) {
      _checkAvailableUpiApps();
    }
  }

  void _handleTextChanged(String value) {
    final isComposing = value.trim().isNotEmpty;
    if (_isComposing != isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
    }
  }

  bool get _isAdminOrOwner {
    return widget.userRole?.toLowerCase() == 'admin' || 
           widget.userRole?.toLowerCase() == 'owner';
  }

  void _sendTextMessage() {
    final text = widget.messageController.text.trim();
    if (text.isEmpty) return;

    // Create temp message - SelfSendingMessageBubble will handle link detection and processing
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchPicker(
          clubId: widget.clubId,
          onExistingMatchSelected: (match) {
            _sendExistingMatchMessage(match);
          },
          onCreateNewMatch: () {
            _navigateToCreateNewMatch();
          },
        ),
      ),
    );
    widget.textFieldFocusNode.unfocus();
  }

  void _openPracticePicker() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PracticePicker(
          clubId: widget.clubId,
          onExistingPracticeSelected: (practice) {
            // Send existing practice message to chat
            _sendExistingPracticeMessage(practice);
            // Unfocus text field to prevent keyboard from opening
            widget.textFieldFocusNode.unfocus();
          },
          onCreateNewPractice: () {
            // Navigate to create new practice
            _navigateToCreateNewPractice();
            // Unfocus text field to prevent keyboard from opening
            widget.textFieldFocusNode.unfocus();
          },
        ),
      ),
    );
  }

  void _navigateToCreateNewPractice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePracticeScreen(
          clubId: widget.clubId,
          // Server handles practice message posting automatically when notifyMembers: true
        ),
      ),
    );
  }

  void _navigateToCreateNewMatch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateMatchScreen(
          onMatchCreated: (match) {
            // Reuse existing flow for sending match announcements
            _sendExistingMatchMessage(match);
          },
        ),
      ),
    );
  }

  void _sendExistingPracticeMessage(MatchListItem practice) async {
    // Get user's membership to determine role
    final clubProvider = context.read<ClubProvider>();
    final membership = clubProvider.clubs
        .where((m) => m.club.id == widget.clubId)
        .firstOrNull;

    // Create temporary message for immediate UI feedback with 'sent' status to prevent duplicate sending
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user',
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: membership?.role ?? 'ADMIN',
      content:
          '⚽ Practice session: ${practice.opponent?.isNotEmpty == true ? practice.opponent! : 'Practice Session'}',
      messageType: 'practice',
      matchId: practice.id, // Use unified matchId instead of practiceId
      matchDetails: {
        // Use unified matchDetails instead of practiceDetails
        'title': practice.opponent?.isNotEmpty == true
            ? practice.opponent!
            : 'Practice Session',
        'description': 'Join our training session',
        'date': practice.matchDate.toIso8601String().split('T')[0],
        'time':
            '${practice.matchDate.hour.toString().padLeft(2, '0')}:${practice.matchDate.minute.toString().padLeft(2, '0')}',
        'venue': practice.location.isNotEmpty
            ? practice.location
            : 'Training Ground',
        'duration': '2 hours',
        'type': 'PRACTICE', // Set type to indicate this is a practice
        'maxParticipants': practice.spots,
        'confirmedPlayers': practice.confirmedPlayers,
        'isJoined':
            practice.userRsvp != null && practice.userRsvp!.status == 'YES',
        'isCancelled': practice.isCancelled,
        'cancellationReason': practice.cancellationReason,
      },
      createdAt: DateTime.now(),
      status: MessageStatus
          .sent, // Use 'sent' to prevent SelfSendingMessageBubble from sending again
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
    );

    // Add to local messages immediately for UI feedback
    widget.onSendMessage(tempMessage);

    // Send practice message to backend directly
    try {
      final practiceData = {
        'content':
            '⚽ Practice session: ${practice.opponent?.isNotEmpty == true ? practice.opponent! : 'Practice Session'}',
        'matchId': practice.id, // Use unified matchId instead of practiceId
        'matchDetails': {
          // Use unified matchDetails instead of practiceDetails
          'title': practice.opponent?.isNotEmpty == true
              ? practice.opponent!
              : 'Practice Session',
          'description': 'Join our training session',
          'date': practice.matchDate.toIso8601String().split('T')[0],
          'time':
              '${practice.matchDate.hour.toString().padLeft(2, '0')}:${practice.matchDate.minute.toString().padLeft(2, '0')}',
          'venue': practice.location.isNotEmpty
              ? practice.location
              : 'Training Ground',
          'duration': '2 hours',
          'type': 'PRACTICE', // Set type to indicate this is a practice
          'maxParticipants': practice.spots,
          'confirmedPlayers': practice.confirmedPlayers,
          'isJoined':
              practice.userRsvp != null && practice.userRsvp!.status == 'YES',
          'isCancelled': practice.isCancelled,
          'cancellationReason': practice.cancellationReason,
        },
      };

      await ChatApiService.sendPracticeMessage(widget.clubId, practiceData);
    } catch (e) {
      print('❌ Error sending practice message: $e');
      // Handle error - show snackbar or retry
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send practice announcement'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendExistingPracticeMessage(practice),
            ),
          ),
        );
      }
    }
  }

  void _sendExistingMatchMessage(MatchListItem match) async {
    // Get user's membership to determine role
    final clubProvider = context.read<ClubProvider>();
    final membership = clubProvider.clubs
        .where((m) => m.club.id == widget.clubId)
        .firstOrNull;

    // Create temporary message for immediate UI feedback with 'sent' status to prevent duplicate sending
    final tempMessage = ClubMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      clubId: widget.clubId,
      senderId: 'current_user',
      senderName: 'You',
      senderProfilePicture: null,
      senderRole: membership?.role ?? 'ADMIN',
      content:
          '📅 Match announcement: ${match.team?.name ?? match.club.name} vs ${match.opponentTeam?.name ?? match.opponent ?? "TBD"}',
      messageType: 'match',
      matchId: match.id,
      matchDetails: {
        'homeTeam': {
          'name': match.team?.name ?? match.club.name,
          'logo': match.team?.logo ?? match.club.logo,
        },
        'opponentTeam': {
          'name': match.opponentTeam?.name ?? match.opponent ?? 'TBD',
          'logo': match.opponentTeam?.logo,
        },
        'dateTime': match.matchDate.toIso8601String(),
        'venue': {
          'name': match.location.isNotEmpty ? match.location : 'Venue TBD',
          'address': match.location,
        },
      },
      createdAt: DateTime.now(),
      status: MessageStatus
          .sent, // Use 'sent' to prevent SelfSendingMessageBubble from sending again
      starred: StarredInfo(isStarred: false),
      pin: PinInfo(isPinned: false),
    );

    // Add to local messages immediately for UI feedback
    widget.onSendMessage(tempMessage);

    // Send match message to backend directly
    try {
      final matchData = {
        'content':
            '📅 Match announcement: ${match.team?.name ?? match.club.name} vs ${match.opponentTeam?.name ?? match.opponent ?? "TBD"}',
        'matchId': match.id,
        'matchDetails': {
          'homeTeam': {
            'name': match.team?.name ?? match.club.name,
            'logo': match.team?.logo ?? match.club.logo,
          },
          'opponentTeam': {
            'name': match.opponentTeam?.name ?? match.opponent ?? 'TBD',
            'logo': match.opponentTeam?.logo,
          },
          'dateTime': match.matchDate.toIso8601String(),
          'venue': {
            'name': match.location.isNotEmpty ? match.location : 'Venue TBD',
            'address': match.location,
          },
        },
      };

      await ChatApiService.sendMatchMessage(widget.clubId, matchData);
    } catch (e) {
      print('❌ Error sending existing match message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send match announcement'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendExistingMatchMessage(match),
            ),
          ),
        );
      }
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
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
            color: Theme.of(context).dialogBackgroundColor,
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
                      // First row - Photos, Document, Location
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
                      // Second row - Contact, Poll, Event (for regular users)
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
                          // Show Event for all users (simplified)
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
                      // Third row - Admin/Owner only options (Match and Practice)
                      if (_isAdminOrOwner) ...[
                        SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildGridOption(
                              icon: Icons.sports_cricket,
                              iconColor: Color(0xFF4CAF50),
                              title: 'Match',
                              onTap: () {
                                Navigator.pop(context);
                                _openMatchPicker();
                              },
                            ),
                            _buildGridOption(
                              icon: Icons.fitness_center,
                              iconColor: Color(0xFF00BCD4),
                              title: 'Practice',
                              onTap: () {
                                Navigator.pop(context);
                                _openPracticePicker();
                              },
                            ),
                            SizedBox(width: 70), // Placeholder for symmetry
                          ],
                        ),
                      ],
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
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
                color: Theme.of(context).textTheme.bodyMedium?.color,
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
          _showError('Please install a UPI payment app to complete the payment.');
        }
      }
    } catch (e) {
      _showError('Failed to initiate payment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      top: false,
      child: Row(
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
            ),

            // Expanded message input area
            Expanded(
              child: TextField(
                controller: widget.messageController,
                focusNode: widget.textFieldFocusNode,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                keyboardAppearance: Theme.of(context).brightness == Brightness.dark
                    ? Brightness.dark
                    : Brightness.light,
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
                      ? Colors.grey[400]
                      : Colors.grey[600],
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
    );
  }
}
