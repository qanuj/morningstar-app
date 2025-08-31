import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ImageCaptionDialog extends StatefulWidget {
  final String? imageUrl;
  final PlatformFile? imageFile;
  final String? initialCaption;
  final Function(String caption, String? croppedImagePath) onSend;
  final String title;

  const ImageCaptionDialog({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.initialCaption,
    required this.onSend,
    this.title = 'Send Image',
  }) : assert(imageUrl != null || imageFile != null, 'Either imageUrl or imageFile must be provided');

  @override
  State<ImageCaptionDialog> createState() => _ImageCaptionDialogState();
}

class _ImageCaptionDialogState extends State<ImageCaptionDialog> {
  late TextEditingController _captionController;
  final FocusNode _focusNode = FocusNode();
  String? _currentImagePath;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption ?? '');
    _loadImage();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      if (widget.imageFile != null) {
        // Handle local file
        final file = widget.imageFile!;
        if (file.bytes != null) {
          _imageBytes = file.bytes;
        } else if (file.path != null) {
          _currentImagePath = file.path;
          _imageBytes = await File(file.path!).readAsBytes();
        }
      } else if (widget.imageUrl != null) {
        // Handle network URL - download first
        final response = await http.get(Uri.parse(widget.imageUrl!));
        if (response.statusCode == 200) {
          _imageBytes = response.bodyBytes;
        }
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cropImage() async {
    if (_currentImagePath == null && _imageBytes == null) return;
    
    setState(() => _isCropping = true);
    
    try {
      String? imagePath = _currentImagePath;
      
      // If we have bytes but no path, create a temporary file
      if (imagePath == null && _imageBytes != null) {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(_imageBytes!);
        imagePath = tempFile.path;
      }
      
      if (imagePath != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: imagePath,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Edit Image',
              toolbarColor: Color(0xFF003f9b),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Edit Image',
              minimumAspectRatio: 0.1,
              aspectRatioLockEnabled: false,
            ),
          ],
        );
        
        if (croppedFile != null && mounted) {
          _currentImagePath = croppedFile.path;
          _imageBytes = await File(croppedFile.path).readAsBytes();
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  void _sendImage() {
    final caption = _captionController.text.trim();
    Navigator.of(context).pop();
    widget.onSend(caption, _currentImagePath);
  }

  Widget _buildImagePreview() {
    if (_isLoading) {
      return Container(
        height: 300,
        color: Color(0xFF0f0f0f),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06aeef)),
          ),
        ),
      );
    }
    
    if (_imageBytes != null) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Color(0xFF0f0f0f),
        child: Image.memory(
          _imageBytes!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        ),
      );
    }
    
    return _buildErrorWidget();
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 300,
      color: Color(0xFF0f0f0f),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white38, size: 48),
          SizedBox(height: 8),
          Text('Failed to load image', style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0f0f0f),
      appBar: AppBar(
        backgroundColor: Color(0xFF0f0f0f),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isCropping 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06aeef)),
                    ),
                  )
                : Icon(Icons.crop, color: Colors.white),
            onPressed: _isCropping ? null : _cropImage,
            tooltip: 'Edit Image',
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview Section
          Expanded(
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImagePreview(),
              ),
            ),
          ),

          // Caption Input Section
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(
              color: Color(0xFF1a1a1a),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // URL Info (if applicable)
                if (widget.imageUrl != null && widget.imageUrl!.startsWith('http')) ...[
                  Text(
                    'Image URL:',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2a2a2a),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.imageUrl!,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 12),
                ],

                // Caption Input with Send Button inline
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        focusNode: _focusNode,
                        maxLines: 3,
                        minLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a caption...',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: 16,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Color(0xFF2a2a2a),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendImage(),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Send Button - Icon only, inline with input
                    GestureDetector(
                      onTap: _sendImage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(0xFF003f9b),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF003f9b).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}