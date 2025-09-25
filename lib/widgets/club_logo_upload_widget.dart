import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';

/// A reusable widget for club logo upload that provides the same UI as club settings
/// This widget handles image picking, cropping, and displays a club logo in a consistent way
class ClubLogoUploadWidget extends StatefulWidget {
  final String? currentLogoUrl;
  final File? currentLogoFile;
  final String clubName;
  final double size;
  final bool isUploading;
  final VoidCallback? onTap;
  final Function(File)? onImageSelected;
  final bool showCameraIcon;
  final String? fallbackText;

  const ClubLogoUploadWidget({
    Key? key,
    this.currentLogoUrl,
    this.currentLogoFile,
    required this.clubName,
    this.size = 120.0,
    this.isUploading = false,
    this.onTap,
    this.onImageSelected,
    this.showCameraIcon = true,
    this.fallbackText,
  }) : super(key: key);

  @override
  State<ClubLogoUploadWidget> createState() => _ClubLogoUploadWidgetState();
}

class _ClubLogoUploadWidgetState extends State<ClubLogoUploadWidget> {
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.currentLogoFile;
  }

  /// Generate initials from club name for fallback display
  String _generateClubInitials(String text) {
    if (text.isEmpty) return 'C';

    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0].length >= 2
          ? words[0].substring(0, 2).toUpperCase()
          : words[0].substring(0, 1).toUpperCase();
    } else {
      return (words[0].substring(0, 1) + words[1].substring(0, 1))
          .toUpperCase();
    }
  }

  /// Build the club logo content based on current state
  Widget _buildClubLogoContent() {
    // If we have a selected local file, show that first
    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: widget.size,
          height: widget.size,
        ),
      );
    }

    // If we have a network URL, display that
    if (widget.currentLogoUrl != null && widget.currentLogoUrl!.isNotEmpty) {
      if (widget.currentLogoUrl!.toLowerCase().contains('.svg') ||
          widget.currentLogoUrl!.toLowerCase().contains('svg?')) {
        return ClipOval(
          child: SvgPicture.network(
            widget.currentLogoUrl!,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            placeholderBuilder: (context) => _buildDefaultClubLogo(),
          ),
        );
      } else {
        return ClipOval(
          child: Image.network(
            widget.currentLogoUrl!,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultClubLogo();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildDefaultClubLogo();
            },
          ),
        );
      }
    }

    // Default fallback logo
    return _buildDefaultClubLogo();
  }

  /// Build default logo with club initials or fallback icon
  Widget _buildDefaultClubLogo() {
    final displayText = widget.fallbackText ?? widget.clubName;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: Center(
        child: displayText.isNotEmpty
            ? Text(
                _generateClubInitials(displayText),
                style: TextStyle(
                  fontSize: widget.size * 0.3,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              )
            : Icon(
                Icons.groups,
                size: widget.size * 0.4,
                color: Theme.of(context).primaryColor,
              ),
      ),
    );
  }

  /// Show the image picker dialog with camera and gallery options
  Future<void> _showImagePickerDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).dialogBackgroundColor
          : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[600]
                    : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Update Club Logo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageOption(
                    icon: Icons.camera_alt,
                    title: 'Camera',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImageFromCamera();
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildImageOption(
                    icon: Icons.photo_library,
                    title: 'Gallery',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImage();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Build individual image picker option button
  Widget _buildImageOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isDarkMode
                ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                : Colors.transparent,
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _cropImage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _cropImage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Crop the selected image to square aspect ratio
  Future<void> _cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Club Logo',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            activeControlsWidgetColor: Theme.of(context).primaryColor,
            cropFrameColor: Theme.of(context).primaryColor,
            cropGridColor: Theme.of(context).primaryColor.withOpacity(0.3),
            dimmedLayerColor: Colors.black.withOpacity(0.5),
            cropFrameStrokeWidth: 2,
            cropGridStrokeWidth: 1,
            showCropGrid: true,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Club Logo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() {
          _selectedImage = File(croppedFile.path);
        });

        // Notify parent widget about the new image
        if (widget.onImageSelected != null) {
          widget.onImageSelected!(_selectedImage!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to crop image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isUploading
          ? null
          : (widget.onTap ?? _showImagePickerDialog),
      child: Stack(
        children: [
          // Main logo container
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: _buildClubLogoContent(),
          ),

          // Camera icon overlay (if enabled)
          if (widget.showCameraIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: widget.isUploading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}
