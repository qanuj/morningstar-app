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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFDEE2E6))),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6C757D),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Add Caption',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003f9b),
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                ],
              ),
            ),

            // Selected clubs display
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sharing with:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003f9b),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSelectedClubsList(),
                ],
              ),
            ),

            // Text editor
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDEE2E6)),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Add a caption...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    hintStyle: TextStyle(
                      color: Color(0xFF6C757D),
                      fontSize: 16,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            // Share button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _shareText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003f9b),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Share to ${widget.selectedClubIds.length} ${widget.selectedClubIds.length == 1 ? 'club' : 'clubs'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
    return Consumer<ClubProvider>(
      builder: (context, clubProvider, child) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Everyone option
            if (widget.selectedClubIds.contains('everyone'))
              _buildClubChip('Everyone', const Color(0xFF16a34a)),

            // Selected clubs
            ...clubProvider.clubs
                .where((membership) => widget.selectedClubIds.contains(membership.club.id))
                .map((membership) => _buildClubChip(
                      membership.club.name,
                      const Color(0xFF06aeef),
                    )),
          ],
        );
      },
    );
  }

  Widget _buildClubChip(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _shareText() async {
    setState(() => _isLoading = true);

    try {
      final messageText = _textController.text.trim();

      // Check if "Everyone" is selected
      if (widget.selectedClubIds.contains('everyone')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shared with everyone! (Feature coming soon)'),
              backgroundColor: Color(0xFF16a34a),
            ),
          );
        }
        _navigateToClubsScreen();
        return;
      }

      // Send to each selected club
      int successCount = 0;
      for (final clubId in widget.selectedClubIds) {
        final success = await _sendTextToClub(clubId, messageText);
        if (success) successCount++;
      }

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Text shared to $successCount of ${widget.selectedClubIds.length} clubs successfully!',
              ),
              backgroundColor: const Color(0xFF16a34a),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to share text to any clubs.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }

      _navigateToClubsScreen();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share text. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _sendTextToClub(String clubId, String messageText) async {
    try {
      final messageData = {
        'content': messageText,
        'type': 'text',
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