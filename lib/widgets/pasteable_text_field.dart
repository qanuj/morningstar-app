import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'mentionable_text_field.dart';
import '../models/mention.dart';

/// A text field that supports pasting images from clipboard
/// Extends MentionableTextField to maintain mention functionality
class PasteableTextField extends StatefulWidget {
  final MentionableTextFieldController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int maxLines;
  final int minLines;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final bool autofocus;

  // Mention-related properties
  final List<Mention> mentionSuggestions;
  final bool showMentionOverlay;
  final Function(String)? onMentionTriggered;
  final VoidCallback? onMentionCancelled;

  // Image paste callback
  final Function(List<String>)? onImagesPasted;

  // Format callback
  final Function(FormatType)? onFormatApplied;

  const PasteableTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.maxLines = 4,
    this.minLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction = TextInputAction.newline,
    this.onTap,
    this.onChanged,
    this.autofocus = false,
    this.mentionSuggestions = const [],
    this.showMentionOverlay = false,
    this.onMentionTriggered,
    this.onMentionCancelled,
    this.onImagesPasted,
    this.onFormatApplied,
  });

  @override
  State<PasteableTextField> createState() => _PasteableTextFieldState();
}

class _PasteableTextFieldState extends State<PasteableTextField> {
  static const MethodChannel _channel = MethodChannel('app.duggy/clipboard');
  bool _hasClipboardContent = false;
  Timer? _clipboardCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkClipboardContent();

    // Listen to focus changes to refresh clipboard content
    if (widget.focusNode != null) {
      widget.focusNode!.addListener(_onFocusChange);
    }

    // Start periodic clipboard checking when widget is focused
    _startPeriodicClipboardCheck();
  }

  @override
  void dispose() {
    if (widget.focusNode != null) {
      widget.focusNode!.removeListener(_onFocusChange);
    }
    _clipboardCheckTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicClipboardCheck() {
    _clipboardCheckTimer?.cancel();
    _clipboardCheckTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (mounted && (widget.focusNode?.hasFocus ?? false)) {
        _checkClipboardContent();
      }
    });
  }

  void _onFocusChange() {
    if (widget.focusNode!.hasFocus) {
      _checkClipboardContent();
      _startPeriodicClipboardCheck();
    } else {
      _clipboardCheckTimer?.cancel();
    }
  }

  Future<void> _checkClipboardContent() async {
    try {
      // Check for text content
      final clipboardData = await Clipboard.getData('text/plain');
      bool hasText =
          clipboardData?.text != null && clipboardData!.text!.isNotEmpty;

      // Check for image content
      final imageData = await _getClipboardImageData();
      bool hasImage = imageData != null && imageData.isNotEmpty;

      final hasContent = hasText || hasImage;

      if (mounted) {
        setState(() {
          _hasClipboardContent = hasContent;
        });
      }
    } catch (e) {
      print('❌ Error checking clipboard content: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Paste shortcuts
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV):
            _PasteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
            _PasteIntent(),

        // Format shortcuts
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyB):
            _FormatIntent(type: FormatType.bold),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB):
            _FormatIntent(type: FormatType.bold),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyI):
            _FormatIntent(type: FormatType.italic),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI):
            _FormatIntent(type: FormatType.italic),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyX,
        ): _FormatIntent(
          type: FormatType.strikethrough,
        ),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyX,
        ): _FormatIntent(
          type: FormatType.strikethrough,
        ),
      },
      child: Actions(
        actions: {
          _PasteIntent: CallbackAction<_PasteIntent>(
            onInvoke: (_) => _handlePaste(),
          ),
          _FormatIntent: CallbackAction<_FormatIntent>(
            onInvoke: (intent) => _handleFormat(intent.type),
          ),
        },
        child: _buildTextFieldWithContextMenu(),
      ),
    );
  }

  Future<void> _handlePaste() async {
    try {
      print('📋 Paste action triggered');

      // First check for regular text
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
        print('📋 Found text in clipboard, using default paste');
        _pasteText(clipboardData.text!);
        return;
      }

      // Try to get image data from clipboard
      print('📋 No text found, checking for image data');
      final imageData = await _getClipboardImageData();

      if (imageData != null && imageData.isNotEmpty) {
        print(
          '📋 Found image data in clipboard, size: ${imageData.length} bytes',
        );
        await _handleImagePaste(imageData);
      } else {
        print('📋 No image data found in clipboard');
      }
    } catch (e) {
      print('❌ Error during paste operation: $e');
    }
  }

  void _pasteText(String text) {
    final controller = widget.controller;
    final currentText = controller.text;
    final selection = controller.selection;

    if (selection.isValid) {
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + text.length,
        ),
      );
    } else {
      controller.text = currentText + text;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  Future<Uint8List?> _getClipboardImageData() async {
    try {
      // Use platform channel to get image data from clipboard
      final result = await _channel.invokeMethod<Uint8List>(
        'getClipboardImage',
      );
      return result;
    } catch (e) {
      print('❌ Error getting clipboard image data: $e');

      // If it's a MissingPluginException, the native implementation isn't available
      if (e.toString().contains('MissingPluginException')) {
        print(
          '⚠️ Platform channel not implemented. Native clipboard image access unavailable.',
        );
        print(
          '💡 Make sure to rebuild the app after adding platform channel code.',
        );
      }

      return null;
    }
  }

  Future<void> _handleImagePaste(Uint8List imageData) async {
    try {
      // Save the image to temp directory
      final imagePath = await _saveImageToTemp(imageData);

      if (imagePath != null) {
        print('📋 Image saved to: $imagePath');
        // Notify parent about pasted images
        widget.onImagesPasted?.call([imagePath]);
      } else {
        print('❌ Failed to save clipboard image');
      }
    } catch (e) {
      print('❌ Error handling image paste: $e');
    }
  }

  Future<String?> _saveImageToTemp(Uint8List imageData) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final imagePath = '${tempDir.path}/$fileName';

      // Decode and validate image
      final image = img.decodeImage(imageData);
      if (image == null) {
        print('❌ Invalid image data');
        return null;
      }

      // Save as PNG
      final pngBytes = img.encodePng(image);
      final file = File(imagePath);
      await file.writeAsBytes(pngBytes);

      return imagePath;
    } catch (e) {
      print('❌ Error saving image to temp: $e');
      return null;
    }
  }

  Future<void> _handleFormat(FormatType type) async {
    print('📝 Format action triggered: ${type.name}');

    final controller = widget.controller;
    final selection = controller.selection;

    if (!selection.isValid) {
      print('📝 No valid text selection for formatting');
      return;
    }

    final selectedText = controller.text.substring(
      selection.start,
      selection.end,
    );
    if (selectedText.isEmpty) {
      print('📝 No text selected for formatting');
      return;
    }

    String formattedText;
    switch (type) {
      case FormatType.bold:
        formattedText = '*$selectedText*';
        break;
      case FormatType.italic:
        formattedText = '_${selectedText}_';
        break;
      case FormatType.strikethrough:
        formattedText = '~$selectedText~';
        break;
      case FormatType.code:
        formattedText = '`$selectedText`';
        break;
      case FormatType.monospace:
        formattedText = '```$selectedText```';
        break;
    }

    // Replace selected text with formatted text
    final newText = controller.text.replaceRange(
      selection.start,
      selection.end,
      formattedText,
    );

    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + formattedText.length,
      ),
    );
  }



  Widget _buildTextFieldWithContextMenu() {
    return Stack(
      children: [
        MentionableTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: widget.decoration,
          style: widget.style,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          onTap: () {
            // Check clipboard when text field is tapped
            _checkClipboardContent();
            widget.onTap?.call();
          },
          onChanged: widget.onChanged,
          autofocus: widget.autofocus,
          mentionSuggestions: widget.mentionSuggestions,
          showMentionOverlay: widget.showMentionOverlay,
          onMentionTriggered: widget.onMentionTriggered,
          onMentionCancelled: widget.onMentionCancelled,
        ),
        // Show paste hint when clipboard has content
        if (_hasClipboardContent)
          Positioned(
            right: 4,
            top: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handlePaste,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_paste, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom intent for paste action
class _PasteIntent extends Intent {
  const _PasteIntent();
}

/// Custom intent for format actions
class _FormatIntent extends Intent {
  final FormatType type;
  const _FormatIntent({required this.type});
}

/// Format types for text formatting
enum FormatType { bold, italic, strikethrough, code, monospace }
