import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/keyboard_avoiding_wrapper.dart';
import '../../widgets/duggy_logo.dart';
import 'otp.dart';
import '../../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isLoading = false;
  int _remainingTime = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto-focus the phone input field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset loading state when user returns to this screen
    if (_isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    setState(() {
      _remainingTime = seconds;
    });

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      }

      if (_remainingTime <= 0) {
        setState(() {
          _remainingTime = 0;
        });
        timer.cancel();
        _timer = null;
      }
    });
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
      await ApiService.put('/auth/sms', {'phoneNumber': phone});
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => OTPScreen(phoneNumber: phone)));
    } catch (e) {
      if (e is ApiException) {
        // Try to parse rate limiting information from raw response
        try {
          final responseData = json.decode(e.rawResponse);
          if (responseData['remainingTime'] != null) {
            final remainingTime = responseData['remainingTime'] as int;
            // Start countdown instead of showing error message
            _startCountdown(remainingTime);
            return; // Don't show error message, just disable button
          }
        } catch (_) {
          // Continue to show normal error message
        }

        // Show error message for non-rate-limiting errors
        String errorMessage = e is ApiException ? e.message : e.toString();

        // Remove "Exception: " prefix if present
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        setState(() => _isLoading = false);
      }

      // Show error message for non-rate-limiting errors
      String errorMessage = e is ApiException ? e.message : e.toString();

      // Remove "Exception: " prefix if present
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(flex: 2),

              // Bigger logo - theme aware
              Center(
                child: DuggyLogoVariant.large(
                  color: theme.colorScheme.primary,
                  showText: false,
                ),
              ),

              SizedBox(height: 48),

              // Phone Input with right arrow suffix - theme aware
              TextField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                onSubmitted: (_) => _sendOTP(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter 10-digit number',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 16,
                  ),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: isDark ? Color(0xFF2a2a2a) : Colors.white,
                  prefixIcon: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  suffixIcon: _isLoading
                      ? Container(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _remainingTime > 0
                      ? Container(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            '$_remainingTime',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _sendOTP,
                          icon: Icon(
                            Icons.arrow_forward,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? Color(0xFF444444).withOpacity(0.5)
                          : theme.dividerColor,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? Color(0xFF444444).withOpacity(0.5)
                          : theme.dividerColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),

              // Helper text for rate limiting
              if (_remainingTime > 0) ...[
                SizedBox(height: 8),
                Center(
                  child: Text(
                    'Please wait $_remainingTime seconds before requesting a new OTP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
