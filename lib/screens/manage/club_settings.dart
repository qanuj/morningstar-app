import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../models/club.dart';
import '../../services/api_service.dart';
import '../../providers/club_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_app_bar.dart';

class ClubSettingsScreen extends StatefulWidget {
  final Club club;
  
  const ClubSettingsScreen({
    super.key,
    required this.club,
  });
  
  @override
  ClubSettingsScreenState createState() => ClubSettingsScreenState();
}

class ClubSettingsScreenState extends State<ClubSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _membershipFeeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isUploading = false;
  String? _selectedCurrency;
  File? _selectedImage;
  
  // Currency options
  final List<String> _currencyOptions = [
    'INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD', 'SGD', 'AED'
  ];

  @override
  void initState() {
    super.initState();
    _loadClubData();
  }

  void _loadClubData() {
    // Populate form with existing club data
    _nameController.text = widget.club.name;
    _descriptionController.text = widget.club.description ?? '';
    _locationController.text = '${widget.club.city ?? ''}${widget.club.city != null && widget.club.state != null ? ', ' : ''}${widget.club.state ?? ''}';
    _websiteController.text = widget.club.website ?? '';
    _phoneController.text = widget.club.contactPhone ?? '';
    _emailController.text = widget.club.contactEmail ?? '';
    _membershipFeeController.text = widget.club.membershipFee.toString();
    _selectedCurrency = widget.club.membershipFeeCurrency;
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
            toolbarTitle: 'Crop Club Logo',
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop image: $e')),
        );
      }
    }
  }

  Future<void> _showNativeCurrencyPicker() async {
    if (Platform.isIOS) {
      await _showCupertinoCurrencyPicker();
    } else {
      await _showMaterialCurrencyPicker();
    }
  }

  Future<void> _showCupertinoCurrencyPicker() async {
    String? selectedCurrency = _selectedCurrency;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
                Text(
                  'Select Currency',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCurrency = selectedCurrency;
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: _selectedCurrency != null 
                      ? _currencyOptions.indexOf(_selectedCurrency!)
                      : 0,
                ),
                onSelectedItemChanged: (index) {
                  selectedCurrency = _currencyOptions[index];
                },
                children: _currencyOptions.map((currency) => Center(
                  child: Text(
                    currency,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMaterialCurrencyPicker() async {
    final selectedCurrency = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Currency'),
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: _currencyOptions.map((currency) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, currency),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              currency,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
          ),
        )).toList(),
      ),
    );

    if (selectedCurrency != null) {
      setState(() {
        _selectedCurrency = selectedCurrency;
      });
    }
  }

  Future<void> _updateClubSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Handle club logo upload first if there's a new image
      String? logoUrl = widget.club.logo;
      if (_selectedImage != null) {
        logoUrl = await _uploadClubLogo();
      }
      
      // Prepare club data matching the Club model structure
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'website': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        'contactPhone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'contactEmail': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'membershipFee': _membershipFeeController.text.trim().isEmpty ? 0.0 : double.tryParse(_membershipFeeController.text.trim()) ?? 0.0,
        'membershipFeeCurrency': _selectedCurrency,
        'logo': logoUrl,
        // TODO: Parse location into city/state when implementing location functionality
        // For now, store the combined location in city field
        'city': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      };

      // Call API to update club settings
      await ApiService.put('/clubs/${widget.club.id}', data);
      debugPrint('Club settings saved successfully: $data');
      
      if (mounted) {
        // Force refresh club data from API (not cache)
        try {
          final clubProvider = Provider.of<ClubProvider>(context, listen: false);
          // Clear cached club data and force refresh from API
          await ApiService.clearClubsCache();
          await clubProvider.refreshClubs();
          debugPrint('Club data refreshed successfully');
        } catch (e) {
          debugPrint('Error refreshing club data: $e');
          // Don't show error to user as main save was successful
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Club settings updated successfully'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Return the updated data to trigger refresh in parent screens
        Navigator.of(context).pop(true); // Return true to indicate successful update
      }
    } catch (e) {
      debugPrint('Error updating club settings: $e');
      if (mounted) {
        String errorMessage = 'Failed to update club settings';
        
        // Handle specific error types
        if (e.toString().contains('Network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('401')) {
          errorMessage = 'You are not authorized to update these settings.';
        } else if (e.toString().contains('400')) {
          errorMessage = 'Invalid data provided. Please check your inputs.';
        } else if (e.toString().contains('500')) {
          errorMessage = 'Server error. Please try again later.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorRed,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<String?> _uploadClubLogo() async {
    try {
      if (_selectedImage == null) return null;

      // Show upload loading state
      if (mounted) {
        setState(() {
          _isUploading = true;
        });
      }

      // Convert File to bytes for upload
      final bytes = await _selectedImage!.readAsBytes();
      
      // Create PlatformFile
      final platformFile = PlatformFile(
        name: 'club_logo.jpg',
        size: bytes.length,
        bytes: bytes,
        path: null,
      );

      // Upload file to /upload endpoint
      final logoUrl = await ApiService.uploadFile(platformFile);

      if (logoUrl != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Club logo uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Clear selected image after successful upload
          setState(() {
            _selectedImage = null;
          });
        }
        return logoUrl;
      } else {
        throw Exception('Failed to upload logo to server - no URL returned');
      }
    } catch (e) {
      debugPrint('Error uploading club logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload club logo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildClubLogo() {
    // Check if the URL is an SVG
    if (widget.club.logo != null && widget.club.logo!.isNotEmpty) {
      if (widget.club.logo!.toLowerCase().contains('.svg') || 
          widget.club.logo!.toLowerCase().contains('svg?')) {
        return SvgPicture.network(
          widget.club.logo!,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => _buildDefaultClubLogo(),
        );
      } else {
        // Regular image (PNG, JPG, etc.)
        return Image.network(
          widget.club.logo!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultClubLogo();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildDefaultClubLogo();
          },
        );
      }
    }
    return _buildDefaultClubLogo();
  }

  Widget _buildDefaultClubLogo() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.club.name.isNotEmpty
              ? widget.club.name.substring(0, 1).toUpperCase()
              : 'C',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryBlue,
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
        subtitle: 'Settings',
        actions: [
          (_isLoading || _isUploading)
              ? Container(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _updateClubSettings,
                  icon: Icon(Icons.check),
                  tooltip: 'Save Settings',
                ),
        ],
      ),
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.grey[200],
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Club Logo Section
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Club Logo
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _isUploading ? null : _showImagePickerDialog,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: _selectedImage != null
                                  ? CircleAvatar(
                                      radius: 40,
                                      backgroundImage: FileImage(_selectedImage!),
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(40),
                                        child: _buildClubLogo(),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: -12,
                            right: -12,
                            child: IconButton(
                              onPressed: _isUploading ? null : _showImagePickerDialog,
                              icon: _isUploading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : AppTheme.primaryBlue,
                                      ),
                                    )
                                  : Icon(
                                      Icons.camera_alt,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : AppTheme.primaryBlue,
                                      size: 24,
                                    ),
                              constraints: BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(width: 20),
                      
                      // Club Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.club.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Club ID: ${widget.club.id}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Update your club logo and information',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Form Fields
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.06),
                      blurRadius: 16,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Club Name Field
                      _buildTextField(
                        controller: _nameController,
                        label: 'Club Name',
                        icon: Icons.sports_cricket,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Club name is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      // Description Field
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Club Description',
                        hint: 'Tell us about your club',
                        icon: Icons.description,
                        maxLines: 3,
                      ),

                      SizedBox(height: 16),

                      // Location Field
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location',
                        hint: 'Enter club location',
                        icon: Icons.location_on,
                      ),

                      SizedBox(height: 16),

                      // Phone Number Field
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: 'Enter club phone number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),

                      SizedBox(height: 16),

                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'Enter club email address',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value?.trim().isNotEmpty == true) {
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                              return 'Please enter a valid email';
                            }
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      // Website Field
                      _buildTextField(
                        controller: _websiteController,
                        label: 'Website',
                        hint: 'Enter club website URL',
                        icon: Icons.web,
                        keyboardType: TextInputType.url,
                      ),

                      SizedBox(height: 16),

                      // Membership Fee Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _membershipFeeController,
                              label: 'Membership Fee',
                              hint: '0.00',
                              icon: Icons.payments,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildNativeTapField(
                              value: _selectedCurrency,
                              label: 'Currency',
                              hint: 'INR',
                              onTap: _showNativeCurrencyPicker,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallClubLogo() {
    // Check if the URL is an SVG
    if (widget.club.logo!.toLowerCase().contains('.svg') || 
        widget.club.logo!.toLowerCase().contains('svg?')) {
      return SvgPicture.network(
        widget.club.logo!,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildSmallDefaultClubLogo(),
      );
    } else {
      // Regular image (PNG, JPG, etc.)
      return Image.network(
        widget.club.logo!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildSmallDefaultClubLogo();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildSmallDefaultClubLogo();
        },
      );
    }
  }

  Widget _buildSmallDefaultClubLogo() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.club.name.isNotEmpty
              ? widget.club.name.substring(0, 1).toUpperCase()
              : 'C',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 14,
            ),
            prefixIcon: icon != null ? Icon(
              icon, 
              size: 20,
              color: Theme.of(context).hintColor,
            ) : null,
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).cardColor
                : Theme.of(context).scaffoldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.primaryBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNativeTapField({
    required String? value,
    required String label,
    required String hint,
    required VoidCallback onTap,
    IconData? leadingIcon,
    bool readOnly = false,
  }) {
    IconData icon = leadingIcon ?? (Platform.isIOS ? CupertinoIcons.chevron_down : Icons.keyboard_arrow_down);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: readOnly ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: readOnly 
                  ? Theme.of(context).disabledColor.withOpacity(0.1)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).cardColor
                      : Theme.of(context).scaffoldBackgroundColor),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 16,
                      color: readOnly 
                          ? Theme.of(context).disabledColor
                          : (value != null 
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).hintColor),
                    ),
                  ),
                ),
                if (!readOnly)
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).hintColor,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _membershipFeeController.dispose();
    super.dispose();
  }
}