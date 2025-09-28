// lib/screens/shared/text_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/club_provider.dart';
import '../../models/shared_content.dart';
import '../clubs/club_chat.dart';
import '../../services/chat_api_service.dart';

class TextEditorScreen extends StatefulWidget {
  final Set<String> selectedClubIds;
  final String initialText;

  const TextEditorScreen({
    Key? key,
    required this.selectedClubIds,
    required this.initialText,
  }) : super(key: key);

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late TextEditingController _textController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Compact header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFE5E5E5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 36),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF757575),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Add Caption',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF212121),
                      ),
                    ),
                  ),
                  const SizedBox(width: 60),
                ],
              ),
            ),

            // Compact selected clubs display
            if (widget.selectedClubIds.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sharing with:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSelectedClubsList(),
                  ],
                ),
              ),

            // Clean text editor
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'What\'s on your mind?',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    hintStyle: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFF757575)
                          : const Color(0xFF9E9E9E),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: isDarkMode ? Colors.white : const Color(0xFF212121),
                  ),
                ),
              ),
            ),

            // Minimal share button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _shareText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.selectedClubIds.length == 1
                              ? 'Share'
                              : 'Share to ${widget.selectedClubIds.length} clubs',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedClubsList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ClubProvider>(
      builder: (context, clubProvider, child) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            // Everyone option
            if (widget.selectedClubIds.contains('everyone'))
              _buildClubChip('Everyone', isDarkMode),

            // Selected clubs
            ...clubProvider.clubs
                .where(
                  (membership) =>
                      widget.selectedClubIds.contains(membership.club.id),
                )
                .map(
                  (membership) =>
                      _buildClubChip(membership.club.name, isDarkMode),
                ),
          ],
        );
      },
    );
  }

  Widget _buildClubChip(String name, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF424242) : const Color(0xFFE3F2FD),
          width: 0.5,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF1976D2),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _shareText() async {
    setState(() => _isLoading = true);

    try {
      final messageText = _textController.text.trim();

      // Check if "Everyone" is selected
      if (widget.selectedClubIds.contains('everyone')) {
        _navigateToClubsScreen();
        return;
      }

      // Send to each selected club
      for (final clubId in widget.selectedClubIds) {
        await _sendTextToClub(clubId, messageText);
      }

      // Silent completion - no toast notifications

      _navigateToClubsScreen();
    } catch (e) {
      // Silent error handling - no toast
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _sendTextToClub(String clubId, String messageText) async {
    try {
      final messageData = {
        'content': {'type': 'text', 'body': messageText},
        'type': 'text',
        'metadata': {'forwarded': true},
      };

      final response = await ChatApiService.sendMessage(clubId, messageData);
      return response != null;
    } catch (e) {
      print('Error sending text to club $clubId: $e');
      return false;
    }
  }

  void _navigateToClubsScreen() {
    // Navigate to clubs screen (main navigation)
    Navigator.of(context).popUntil((route) => route.isFirst);
    // The main app should have bottom navigation to clubs tab
  }
}
