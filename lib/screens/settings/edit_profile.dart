import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedState;
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  File? _selectedImage;
  
  // Indian states for dropdown
  final List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Delhi', 'Puducherry', 'Chandigarh', 'Dadra and Nagar Haveli',
    'Daman and Diu', 'Lakshadweep', 'Ladakh', 'Jammu and Kashmir'
  ];

  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _loadLatestUserData();
  }

  Future<void> _loadLatestUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Force refresh user data from /api/profile
      await userProvider.loadUser(forceRefresh: true);
      
      // Populate form with latest data
      final user = userProvider.user;
      if (user != null && mounted) {
        setState(() {
          _nameController.text = user.name;
          _emailController.text = user.email ?? '';
          _cityController.text = user.city ?? '';
          _selectedState = user.state;
          _emergencyContactController.text = user.emergencyContact ?? '';
          _bioController.text = user.bio ?? '';
          _selectedGender = user.gender;
          _selectedDateOfBirth = user.dateOfBirth;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile data: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
              'Update Profile Picture',
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
            toolbarTitle: 'Crop Profile Picture',
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
            title: 'Crop Profile Picture',
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

  Future<void> _selectDate() async {
    if (Platform.isIOS) {
      await _showCupertinoDatePicker();
    } else {
      await _showMaterialDatePicker();
    }
  }

  Future<void> _showCupertinoDatePicker() async {
    DateTime? selectedDate = _selectedDateOfBirth ?? DateTime(2000);
    
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
                  'Select Date of Birth',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateOfBirth = selectedDate;
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
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                minimumDate: DateTime(1950),
                maximumDate: DateTime.now(),
                onDateTimeChanged: (date) {
                  selectedDate = date;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMaterialDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDateOfBirth = date;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Handle profile picture upload first if there's a new image
      if (_selectedImage != null) {
        await _uploadProfilePicture(userProvider);
      }
      
      // Prepare profile data with correct field names
      final data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'country': 'India', // Fixed to India as per requirements
        'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        'state': _selectedState,
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        'dob': _selectedDateOfBirth?.toIso8601String(),
        'gender': _selectedGender?.toLowerCase(), // API expects lowercase
        'emergencyContact': _emergencyContactController.text.trim().isEmpty ? null : _emergencyContactController.text.trim(),
      };

      await userProvider.updateProfile(data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        
        Navigator.of(context).pop(true); // Return true to indicate successful update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _uploadProfilePicture(UserProvider userProvider) async {
    if (_selectedImage == null) return;

    try {
      // Convert File to PlatformFile for upload
      final bytes = await _selectedImage!.readAsBytes();
      final platformFile = PlatformFile(
        name: 'profile_picture.jpg',
        size: bytes.length,
        bytes: bytes,
        path: _selectedImage!.path,
      );

      // Upload image to /upload endpoint
      final imageUrl = await ApiService.uploadFile(platformFile);
      if (imageUrl != null) {
        // Update profile picture using /profile/picture endpoint
        await userProvider.updateProfilePicture(imageUrl);
      } else {
        throw Exception('Failed to upload profile picture');
      }
    } catch (e) {
      throw Exception('Profile picture upload failed: $e');
    }
  }

  Future<void> _showNativeStatePicker() async {
    if (Platform.isIOS) {
      await _showCupertinoStatePicker();
    } else {
      await _showMaterialStatePicker();
    }
  }

  Future<void> _showCupertinoStatePicker() async {
    String? selectedState = _selectedState;
    
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
                  'Select State',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedState = selectedState;
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
                  initialItem: _selectedState != null 
                      ? _indianStates.indexOf(_selectedState!)
                      : 0,
                ),
                onSelectedItemChanged: (index) {
                  selectedState = _indianStates[index];
                },
                children: _indianStates.map((state) => Center(
                  child: Text(
                    state,
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

  Future<void> _showMaterialStatePicker() async {
    final selectedState = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select State'),
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: _indianStates.map((state) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, state),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              state,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
          ),
        )).toList(),
      ),
    );

    if (selectedState != null) {
      setState(() {
        _selectedState = selectedState;
      });
    }
  }

  Future<void> _showNativeGenderPicker() async {
    if (Platform.isIOS) {
      await _showCupertinoGenderPicker();
    } else {
      await _showMaterialGenderPicker();
    }
  }

  Future<void> _showCupertinoGenderPicker() async {
    String? selectedGender = _selectedGender;
    
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
                  'Select Gender',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedGender = selectedGender;
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
                  initialItem: _selectedGender != null 
                      ? _genderOptions.indexOf(_selectedGender!)
                      : 0,
                ),
                onSelectedItemChanged: (index) {
                  selectedGender = _genderOptions[index];
                },
                children: _genderOptions.map((gender) => Center(
                  child: Text(
                    gender,
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

  Future<void> _showMaterialGenderPicker() async {
    final selectedGender = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Gender'),
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: _genderOptions.map((gender) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, gender),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              gender,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
          ),
        )).toList(),
      ),
    );

    if (selectedGender != null) {
      setState(() {
        _selectedGender = selectedGender;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Edit Profile',
        customActions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              // Profile Picture Section
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
                      Stack(
                        children: [
                          Container(
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
                                    radius: 50,
                                    backgroundImage: FileImage(_selectedImage!),
                                  )
                                : SVGAvatar(
                                    imageUrl: user?.profilePicture,
                                    size: 100,
                                    backgroundColor: AppTheme.primaryBlue,
                                    child: user?.profilePicture == null
                                        ? Text(
                                            user?.name.isNotEmpty == true
                                                ? user!.name[0].toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _showImagePickerDialog,
                                icon: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        user?.phoneNumber ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Phone number cannot be changed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
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
                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name',
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Enter your email',
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

                      // Emergency Contact Field
                      _buildTextField(
                        controller: _emergencyContactController,
                        label: 'Emergency Contact',
                        hint: 'Enter emergency contact number',
                        keyboardType: TextInputType.phone,
                        icon: Icons.phone,
                      ),

                      SizedBox(height: 16),
                      
                      Text(
                        'This contact will be notified in case of emergencies during matches or events',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),

                      SizedBox(height: 16),

                      // Bio Field
                      _buildTextField(
                        controller: _bioController,
                        label: 'Bio',
                        hint: 'Tell us about yourself',
                        maxLines: 3,
                      ),

                      SizedBox(height: 16),

                      // City Field
                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        hint: 'Enter your city',
                      ),

                      SizedBox(height: 16),

                      // State Field
                      _buildNativeTapField(
                        value: _selectedState,
                        label: 'State',
                        hint: 'Select state',
                        onTap: _showNativeStatePicker,
                      ),

                      SizedBox(height: 16),

                      // Date of Birth Field
                      _buildNativeTapField(
                        value: _selectedDateOfBirth != null 
                            ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                            : null,
                        label: 'Date of Birth',
                        hint: 'Select your date of birth',
                        onTap: _selectDate,
                      ),

                      SizedBox(height: 16),

                      // Gender Field
                      _buildNativeTapField(
                        value: _selectedGender,
                        label: 'Gender',
                        hint: 'Select gender',
                        onTap: _showNativeGenderPicker,
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
  }) {
    // Determine icon based on label if not provided
    IconData icon;
    if (leadingIcon != null) {
      icon = leadingIcon;
    } else if (label.toLowerCase().contains('date') || label.toLowerCase().contains('birth')) {
      icon = Platform.isIOS ? CupertinoIcons.calendar : Icons.calendar_month;
    } else {
      icon = Platform.isIOS ? CupertinoIcons.chevron_down : Icons.keyboard_arrow_down;
    }
    
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
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor
                  : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (label.toLowerCase().contains('date') || label.toLowerCase().contains('birth')) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).hintColor,
                  ),
                  SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 16,
                      color: value != null 
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
                if (!label.toLowerCase().contains('date') && !label.toLowerCase().contains('birth'))
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
    _emailController.dispose();
    _emergencyContactController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}