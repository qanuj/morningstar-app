import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/club.dart';
import '../../models/team.dart';
import '../../services/team_service.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import '../../utils/theme.dart';

class CreateTeamScreen extends StatefulWidget {
  final Club club;
  final Team? teamToEdit;
  final VoidCallback onTeamSaved;

  const CreateTeamScreen({
    super.key,
    required this.club,
    this.teamToEdit,
    required this.onTeamSaved,
  });

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isUploading = false;
  File? _selectedImage;
  String? _logoUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.teamToEdit != null) {
      _nameController.text = widget.teamToEdit!.name;
      _logoUrl = widget.teamToEdit!.logo;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showImagePickerDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Update Team Logo',
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

  Widget _buildImageOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
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
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

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
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  Future<void> _cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Team Logo',
            toolbarColor: AppTheme.primaryBlue,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            activeControlsWidgetColor: AppTheme.primaryBlue,
            cropFrameColor: AppTheme.primaryBlue,
            cropGridColor: AppTheme.primaryBlue.withOpacity(0.3),
            dimmedLayerColor: Colors.black.withOpacity(0.5),
            cropFrameStrokeWidth: 2,
            cropGridStrokeWidth: 1,
            showCropGrid: true,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Team Logo',
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop image: $e')),
        );
      }
    }
  }

  Future<void> _deleteTeam() async {
    if (widget.teamToEdit == null) return;

    // Show native confirmation dialog
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Team'),
        content: Text('Are you sure you want to delete "${widget.teamToEdit!.name}"?\n\nThis action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            isDestructiveAction: true,
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await TeamService.deleteTeam(
        teamId: widget.teamToEdit!.id,
        clubId: widget.club.id,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onTeamSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to delete team: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTeam() async {
    // Clear previous error messages
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that a logo is provided for new teams
    if (widget.teamToEdit == null && _selectedImage == null && (_logoUrl == null || _logoUrl!.isEmpty)) {
      setState(() => _errorMessage = 'Please upload a team logo before saving');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? logoUrl = _logoUrl;

      // Upload image if a new one was selected
      if (_selectedImage != null) {
        setState(() => _isUploading = true);

        try {
          // Convert File to PlatformFile for upload
          final platformFile = PlatformFile(
            name: 'team_logo.jpg',
            size: await _selectedImage!.length(),
            path: _selectedImage!.path,
            bytes: await _selectedImage!.readAsBytes(),
          );

          logoUrl = await ApiService.uploadFile(platformFile);
          if (logoUrl == null || logoUrl.isEmpty) {
            throw Exception('Failed to upload logo to server - no URL returned');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _errorMessage = 'Failed to upload team logo: ${e.toString()}');
          }
          return;
        } finally {
          setState(() => _isUploading = false);
        }
      }

      // For editing, ensure we have a logo URL after potential upload
      if (logoUrl == null || logoUrl.isEmpty) {
        setState(() => _errorMessage = 'Team logo is required');
        return;
      }

      // Save team data
      if (widget.teamToEdit == null) {
        // Create new team
        await TeamService.createTeam(
          clubId: widget.club.id,
          name: _nameController.text.trim(),
          logo: logoUrl,
        );
      } else {
        // Update existing team
        await TeamService.updateTeam(
          teamId: widget.teamToEdit!.id,
          clubId: widget.club.id,
          name: _nameController.text.trim(),
          logo: logoUrl,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onTeamSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to ${widget.teamToEdit == null ? 'create' : 'update'} team: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Widget _buildLogoSection() {
    return Center(
      child: GestureDetector(
        onTap: _showImagePickerDialog,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: _selectedImage != null
              ? ClipOval(
                  child: Image.file(
                    _selectedImage!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                )
              : _logoUrl != null && _logoUrl!.isNotEmpty
                  ? SVGAvatar(
                      imageUrl: _logoUrl,
                      size: 120,
                      backgroundColor: Colors.transparent,
                      fallbackIcon: Icons.sports_cricket,
                      iconSize: 40,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add Logo',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ClubAppBar(
        clubName: widget.club.name,
        clubLogo: widget.club.logo,
        subtitle: widget.teamToEdit == null ? 'Create Team' : 'Edit Team',
        actions: [
          IconButton(
            onPressed: (_isLoading || _isUploading) ? null :
              (widget.teamToEdit == null && _selectedImage == null && (_logoUrl == null || _logoUrl!.isEmpty)) ? null :
              _saveTeam,
            icon: Icon(_isLoading || _isUploading ? Icons.hourglass_empty : Icons.check),
            tooltip: widget.teamToEdit == null ? 'Create Team' : 'Update Team',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Section
              _buildLogoSection(),
              SizedBox(height: 32),

              // Team Name Field
              TextFormField(
                controller: _nameController,
                onChanged: (value) {
                  // Clear error when user starts typing
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Team Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Team name is required';
                  }
                  return null;
                },
              ),

              // Error message display
              if (_errorMessage != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 24),

              // Info text
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.teamToEdit == null
                          ? 'A team logo is required. Upload a logo and enter the team name to create your team.'
                          : 'Upload a team logo and enter the team name to update your team.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.teamToEdit != null && !widget.teamToEdit!.isPrimary
          ? FloatingActionButton(
              onPressed: (_isLoading || _isUploading) ? null : _deleteTeam,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.red,
              elevation: 0,
              mini: true,
              tooltip: 'Delete Team',
              child: Icon(Icons.delete, size: 20),
            )
          : null,
    );
  }
}