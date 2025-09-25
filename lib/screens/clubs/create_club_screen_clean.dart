import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../widgets/custom_app_bar.dart';
import '../../services/subscription_service.dart';
import '../../services/api_service.dart';
import '../../providers/club_provider.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

enum CreateClubStep { clubName, logo, planSelection, confirmation, processing }

class _CreateClubScreenState extends State<CreateClubScreen> {
  CreateClubStep _currentStep = CreateClubStep.clubName;
  final PageController _pageController = PageController();

  // Form data
  final TextEditingController _clubNameController = TextEditingController();
  File? _clubLogoFile;
  String? _selectedPlanId;
  Map<String, dynamic>? _selectedPlan;
  bool _isProcessing = false;

  // Subscription plans data
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'club_starter_annual',
      'name': 'Club Starter',
      'price': 3999,
      'maxMembers': 30,
      'isRecommended': false,
    },
    {
      'id': 'team_captain_annual',
      'name': 'Team Captain',
      'price': 7999,
      'maxMembers': 100,
      'isRecommended': true,
    },
    {
      'id': 'league_master_annual',
      'name': 'League Master',
      'price': 14999,
      'maxMembers': 500,
      'isRecommended': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Set recommended plan as default
    final recommendedPlan = _plans.firstWhere(
      (plan) => plan['isRecommended'] == true,
    );
    _selectedPlanId = recommendedPlan['id'];
    _selectedPlan = recommendedPlan;
  }

  @override
  void dispose() {
    _clubNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _isClubNameValid() {
    final name = _clubNameController.text.trim();
    return name.length >= 3 && name.length <= 50;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DuggyAppBar(subtitle: 'Create Club'),
      body: _buildStepContent(),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case CreateClubStep.clubName:
        return _buildClubNameStep();
      case CreateClubStep.logo:
        return _buildLogoStep();
      case CreateClubStep.planSelection:
        return _buildPlanSelectionStep();
      case CreateClubStep.confirmation:
        return _buildConfirmationStep();
      case CreateClubStep.processing:
        return _buildProcessingStep();
    }
  }

  Widget _buildClubNameStep() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Text(
            'What\'s your club name?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Choose a name that represents your cricket club',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 40),
          TextFormField(
            controller: _clubNameController,
            maxLength: 50,
            textInputAction: TextInputAction.done,
            style: TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Enter club name',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: GestureDetector(
                onTap: _isClubNameValid() ? () => _nextStep() : null,
                child: Container(
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isClubNameValid()
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: _isClubNameValid() ? Colors.white : Colors.grey[500],
                  ),
                ),
              ),
            ),
            onChanged: (value) => setState(() {}),
            onFieldSubmitted: (_) {
              if (_isClubNameValid()) _nextStep();
            },
          ),
          SizedBox(height: 16),
          Text(
            'Name must be between 3-50 characters',
            style: TextStyle(
              fontSize: 14,
              color: _isClubNameValid()
                  ? Colors.green
                  : Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoStep() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => _previousStep(),
              ),
              SizedBox(width: 8),
              Text(
                'Add a club logo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: 56),
            child: Text(
              'Upload a logo to make your club stand out (optional)',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(height: 40),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: _clubLogoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(58),
                        child: Image.file(_clubLogoFile!, fit: BoxFit.cover),
                      )
                    : Icon(
                        Icons.add_a_photo,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: Text(
              _clubLogoFile != null ? 'Tap to change' : 'Tap to add logo',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _nextStep(),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Skip', style: TextStyle(fontSize: 16)),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _nextStep(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPlanSelectionStep() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => _previousStep(),
              ),
              SizedBox(width: 8),
              Text(
                'Choose your plan',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 40),
          Expanded(
            child: PageView.builder(
              controller: PageController(
                viewportFraction: 0.85,
                initialPage: _plans.indexWhere(
                  (plan) => plan['isRecommended'] == true,
                ),
              ),
              itemCount: _plans.length,
              onPageChanged: (index) {
                setState(() {
                  _selectedPlanId = _plans[index]['id'];
                  _selectedPlan = _plans[index];
                });
              },
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final isSelected = _selectedPlanId == plan['id'];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  child: _buildPlanCard(plan, isSelected),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _nextStep(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue with ${_selectedPlan?['name']}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: _isProcessing ? null : () => _previousStep(),
              ),
              SizedBox(width: 8),
              Text(
                'Confirm your club',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 40),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: _clubLogoFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Image.file(
                                  _clubLogoFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.groups,
                                color: Theme.of(context).primaryColor,
                                size: 30,
                              ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _clubNameController.text.trim(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Cricket Club',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 16),
                  Text(
                    'Subscription Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedPlan?['name'] ?? '',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '₹${_selectedPlan?['price']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Up to ${_selectedPlan?['maxMembers']} members • Annual subscription',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Spacer(),
          if (_isProcessing)
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 16),
                  Text('Creating your club...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _processSubscriptionAndCreateClub(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirm & Subscribe',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProcessingStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Theme.of(context).primaryColor),
          SizedBox(height: 24),
          Text(
            'Creating your club...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, bool isSelected) {
    return Card(
      elevation: isSelected ? 8 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (plan['isRecommended'])
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (plan['isRecommended']) SizedBox(height: 16),
            Text(
              plan['name'],
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '₹${plan['price']}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            Text(
              'per year',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Up to ${plan['maxMembers']} members',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    switch (_currentStep) {
      case CreateClubStep.clubName:
        if (_isClubNameValid()) {
          setState(() => _currentStep = CreateClubStep.logo);
        }
        break;
      case CreateClubStep.logo:
        setState(() => _currentStep = CreateClubStep.planSelection);
        break;
      case CreateClubStep.planSelection:
        setState(() => _currentStep = CreateClubStep.confirmation);
        break;
      case CreateClubStep.confirmation:
        _processSubscriptionAndCreateClub();
        break;
      case CreateClubStep.processing:
        break;
    }
  }

  void _previousStep() {
    switch (_currentStep) {
      case CreateClubStep.logo:
        setState(() => _currentStep = CreateClubStep.clubName);
        break;
      case CreateClubStep.planSelection:
        setState(() => _currentStep = CreateClubStep.logo);
        break;
      case CreateClubStep.confirmation:
        setState(() => _currentStep = CreateClubStep.planSelection);
        break;
      case CreateClubStep.clubName:
      case CreateClubStep.processing:
        break;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _clubLogoFile = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processSubscriptionAndCreateClub() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _currentStep = CreateClubStep.processing;
    });

    try {
      // TODO: Implement iOS/Android subscription verification

      // Simulate processing delay
      await Future.delayed(Duration(seconds: 2));

      // Prepare club data
      final clubData = {
        'name': _clubNameController.text.trim(),
        'planId': _selectedPlanId,
      };

      // Create club via API
      final response = await ApiService.post('/clubs', clubData);

      if (response != null) {
        // Refresh clubs cache
        final clubProvider = Provider.of<ClubProvider>(context, listen: false);
        await clubProvider.refreshClubs();

        // Show success and go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Club created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to create club');
      }
    } catch (e) {
      print('Error creating club: $e');
      setState(() {
        _isProcessing = false;
        _currentStep = CreateClubStep.confirmation;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create club. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
