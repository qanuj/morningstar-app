import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_app_bar.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  int currentStep = 0;
  final PageController _pageController = PageController();

  // Form controllers
  final TextEditingController _clubNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String? selectedCity;
  String selectedCurrency = 'Indian Rupee (₹)';
  String? selectedPlan;
  
  // Plan data
  final List<Map<String, dynamic>> plans = [
    {
      'name': 'Club Starter',
      'price': 2999,
      'duration': 'year',
      'members': 30,
      'features': [
        'Match scheduling & RSVP',
        'Member management',
        'Payment tracking',
        '+3 more features'
      ]
    },
    {
      'name': 'Team Captain',
      'price': 4499,
      'duration': 'year',
      'members': 100,
      'features': [
        'Match scheduling & RSVP',
        'Member management',
        'Payment tracking',
        '+3 more features'
      ],
      'recommended': true
    },
    {
      'name': 'League Master',
      'price': 5999,
      'duration': 'year',
      'members': 500,
      'features': [
        'Match scheduling & RSVP',
        'Member management',
        'Payment tracking',
        '+8 more features'
      ],
      'badge': 'Enterprise'
    },
  ];

  final List<String> cities = [
    'Bangalore (Karnataka)',
    'Delhi (Delhi)',
    'Mumbai (Maharashtra)',
    'Nashik (Maharashtra)',
    'Palghar (Maharashtra)',
    'Pune (Maharashtra)',
    'Thanke (Maharashtra)',
    'Valsad (Gujarat)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Create Your Cricket Club',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Header and Progress indicator
          Container(
            padding: EdgeInsets.all(16),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get started with just the essentials - you can add more details later in club settings',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 16),
                _buildProgressIndicator(),
              ],
            ),
          ),
          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  currentStep = index;
                });
              },
              children: [
                _buildClubInformationStep(),
                _buildPlanSelectionStep(),
                _buildReviewPaymentStep(),
              ],
            ),
          ),
          // Bottom navigation
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: i <= currentStep ? Color(0xFF003f9b) : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  color: i <= currentStep ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2,
                color: i < currentStep ? Color(0xFF003f9b) : Colors.grey[300],
                margin: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildClubInformationStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 0),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Club Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Just the essentials to get your club started',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            
            // Club Name
            _buildTextField(
              controller: _clubNameController,
              label: 'Club Name *',
              hint: 'e.g., Mumbai Warriors CC',
            ),
            SizedBox(height: 16),
            
            // Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Description *',
              hint: 'Briefly describe your cricket club...',
              maxLines: 3,
            ),
            SizedBox(height: 16),
            
            // City and State
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'City *',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCity,
                            hint: Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Select city'),
                              ],
                            ),
                            isExpanded: true,
                            items: cities.map((city) {
                              return DropdownMenuItem(
                                value: city,
                                child: Text(city),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCity = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _stateController,
                    label: 'State *',
                    hint: 'e.g., Maharashtra',
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Contact Email
            _buildTextField(
              controller: _emailController,
              label: 'Contact Email *',
              hint: 'club@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 8),
            Text(
              'This email will be used for club communications and important updates',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            
            // Currency
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currency *',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.currency_rupee, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(selectedCurrency),
                      Spacer(),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
              fontSize: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelectionStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Select the plan that best fits your club\'s needs',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            
            // Plans
            for (int i = 0; i < plans.length; i++) ...[
              _buildPlanCard(plans[i], i),
              if (i < plans.length - 1) SizedBox(height: 16),
            ],
            
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_offer, color: Colors.amber[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Have a coupon code? You can apply it during checkout on the payment page.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index) {
    final isSelected = selectedPlan == plan['name'];
    final isRecommended = plan['recommended'] ?? false;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlan = plan['name'];
        });
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Color(0xFF003f9b) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  plan['name'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                if (isRecommended)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF003f9b),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Recommended',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (plan['badge'] != null && !isRecommended)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      plan['badge'],
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '₹${plan['price']}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' /${plan['duration']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.people, size: 20, color: Color(0xFF003f9b)),
                SizedBox(width: 8),
                Text('Up to ${plan['members']} members'),
              ],
            ),
            SizedBox(height: 12),
            for (String feature in plan['features'])
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(feature),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewPaymentStep() {
    final selectedPlanData = plans.firstWhere(
      (plan) => plan['name'] == selectedPlan,
      orElse: () => plans[1], // Default to Team Captain
    );
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: Color(0xFF003f9b)),
                SizedBox(width: 8),
                Text(
                  'Review & Payment',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Review your club details and complete payment',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            
            // Club Summary
            Text(
              'Club Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name:', style: TextStyle(color: Colors.grey[600])),
                      Text(
                        _clubNameController.text.isNotEmpty ? _clubNameController.text : 'Morningstar',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 12),
                      Text('Email:', style: TextStyle(color: Colors.grey[600])),
                      Text(
                        _emailController.text.isNotEmpty ? _emailController.text : 'aomeo@ie10.com',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location:', style: TextStyle(color: Colors.grey[600])),
                      Text(
                        selectedCity != null ? selectedCity! : 'Delhi, Delhi',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 12),
                      Text('Currency:', style: TextStyle(color: Colors.grey[600])),
                      Text(
                        selectedCurrency,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Selected Plan
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedPlan ?? 'Team Captain',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Annual subscription',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${selectedPlanData['price']}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'per year',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            // Payment Note
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: You will be redirected to Stripe for secure payment processing. You can enter coupon codes on the checkout page if you have any. Your club will be created immediately after successful payment.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: Text('Back'),
              ),
            ),
          if (currentStep > 0) SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _canProceed() ? () {
                if (currentStep < 2) {
                  _pageController.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _handlePayment();
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF003f9b),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                currentStep == 0 ? 'Next: Choose Plan' :
                currentStep == 1 ? 'Next: Review & Pay' :
                'Pay ₹${plans.firstWhere((p) => p['name'] == selectedPlan, orElse: () => plans[1])['price']} & Create Club',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (currentStep) {
      case 0:
        return _clubNameController.text.isNotEmpty &&
               _descriptionController.text.isNotEmpty &&
               selectedCity != null &&
               _stateController.text.isNotEmpty &&
               _emailController.text.isNotEmpty;
      case 1:
        return selectedPlan != null;
      case 2:
        return true;
      default:
        return false;
    }
  }

  void _handlePayment() {
    // TODO: Implement in-app purchase integration
    // This should integrate with the app store billing APIs
    print('Processing payment for plan: $selectedPlan');
    
    // For now, show a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment Processing'),
        content: Text('This will integrate with in-app purchases to process the payment.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close create club screen
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clubNameController.dispose();
    _descriptionController.dispose();
    _stateController.dispose();
    _emailController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}