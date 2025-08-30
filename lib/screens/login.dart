import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/keyboard_avoiding_wrapper.dart';
import '../widgets/duggy_logo.dart';
import 'otp.dart';
import '../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the phone input field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.post('/auth/send-otp', {'phoneNumber': phone});
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OTPScreen(phoneNumber: phone),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardAvoidingWrapper(
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(flex: 2),
              
              // Duggy Logo and Branding
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: DuggyLogoVariant.medium(color: Theme.of(context).colorScheme.onPrimary),
              ),
              
              SizedBox(height: 24),
              
              // App Title
              Text(
                'Welcome to Duggy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 8),
              
              // Subtitle
              Text(
                'Your Cricket Club Companion',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 48),
              
              // Login Form Container - More Compact
              Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Form Header
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Phone Input
                    TextField(
                      controller: _phoneController,
                      focusNode: _phoneFocusNode,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter 10-digit mobile number',
                        prefixIcon: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          child: Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).textTheme.titleLarge?.color,
                            ),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Send OTP Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: _isLoading
                            ? Container(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Send OTP',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Help Text
              Text(
                'We\'ll send you a verification code',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              
              Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}