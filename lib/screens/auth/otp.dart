import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/club_provider.dart';
import '../../widgets/duggy_logo.dart';
import '../shared/home.dart';
import 'collect_name_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;

  OTPScreen({required this.phoneNumber});

  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  bool _isLoading = false;
  int _remainingTime = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto-focus the OTP input field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNode.requestFocus();
    });

    // Listen to text changes and auto-verify when 6 digits are entered
    _otpController.addListener(() {
      if (_otpController.text.length == 6 && !_isLoading) {
        _verifyOTP();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
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

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);

    try {
      await ApiService.put('/auth/sms', {'phoneNumber': widget.phoneNumber});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (e is ApiException) {
        // Try to parse rate limiting information from raw response
        try {
          final responseData = json.decode(e.rawResponse);
          if (responseData['remainingTime'] != null) {
            final remainingTime = responseData['remainingTime'] as int;
            // Start countdown instead of showing error message
            _startCountdown(remainingTime);
            setState(() => _isLoading = false);
            return; // Don't show error message, just disable button
          }
        } catch (_) {
          // Continue to show normal error message
        }
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
    }

    setState(() => _isLoading = false);
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post('/auth/sms', {
        'phoneNumber': widget.phoneNumber,
        'otp': otp,
      });

      // Set token first so we can make authenticated API calls
      await ApiService.setToken(response['token']);

      // Get user and clubs data from the API after successful login
      Map<String, dynamic>? userData;
      List<Map<String, dynamic>>? clubsData;
      bool isNewUser = false;

      try {
        // Fetch user data from /auth/me
        final userResponse = await ApiService.get('/auth/me');
        if (userResponse.containsKey('data') && userResponse['data'] != null) {
          userData = userResponse['data'];
        } else if (userResponse.containsKey('user') &&
            userResponse['user'] != null) {
          userData = userResponse['user'];
        } else {
          userData = userResponse;
        }

        // Check if user has a name - if not, they're a new user
        if (userData != null &&
            (userData['name'] == null ||
             userData['name'].toString().trim().isEmpty)) {
          isNewUser = true;
        }

        if (!isNewUser) {
          // Fetch clubs data from /my/clubs for existing users
          final clubsResponse = await ApiService.get('/my/clubs');
          final data = clubsResponse['data'];
          if (data is List) {
            clubsData = List<Map<String, dynamic>>.from(data);
          } else if (data is Map) {
            clubsData = [Map<String, dynamic>.from(data)];
          }

          // Update ApiService with the fetched data
          await ApiService.setToken(
            response['token'],
            userData: userData,
            clubsData: clubsData,
          );
        }
      } catch (e) {
        debugPrint('Error fetching user/clubs data: $e');
        // Continue with login even if additional data fetch fails
      }

      if (isNewUser) {
        // Navigate to name collection screen for new users
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => CollectNameScreen(
              phoneNumber: widget.phoneNumber,
              token: response['token'],
            ),
          ),
          (route) => false,
        );
      } else {
        // Load data from cached sources in providers for existing users
        await Provider.of<UserProvider>(context, listen: false).loadUser();
        await Provider.of<ClubProvider>(context, listen: false).loadClubs();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      String errorMessage;
      Duration snackBarDuration = Duration(seconds: 4);

      if (e is ApiException) {
        // Try to parse rate limiting information from raw response
        try {
          final responseData = json.decode(e.rawResponse);
          if (responseData['remainingTime'] != null) {
            final remainingTime = responseData['remainingTime'] as int;
            errorMessage =
                'Please wait $remainingTime seconds before trying again';
            snackBarDuration = Duration(
              seconds: remainingTime > 8 ? 8 : remainingTime + 2,
            );
          } else {
            errorMessage = e.message;
            // Use generic message if error is unclear
            if (errorMessage.isEmpty || errorMessage.contains('API Error')) {
              errorMessage = 'Invalid OTP. Please try again.';
            }
          }
        } catch (_) {
          errorMessage = e.message;
          if (errorMessage.isEmpty || errorMessage.contains('API Error')) {
            errorMessage = 'Invalid OTP. Please try again.';
          }
        }
      } else {
        errorMessage = e.toString();

        // Remove "Exception: " prefix if present
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        // Use the parsed error message or fallback to generic message
        if (errorMessage.isEmpty || errorMessage.contains('API Error')) {
          errorMessage = 'Invalid OTP. Please try again.';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: snackBarDuration,
        ),
      );
      // Clear the OTP field on error so user can re-enter
      _otpController.clear();
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height:
                MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                AppBar().preferredSize.height,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(flex: 1, child: SizedBox()),

                  // Logo - smaller on smaller screens
                  Center(
                    child: DuggyLogoVariant.medium(
                      color: theme.colorScheme.primary,
                      showText: false,
                    ),
                  ),

                  SizedBox(height: 24),

                  // Phone number info
                  Text(
                    'Verify +91 ${widget.phoneNumber}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Enter the 6-digit code sent to your phone',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),

                  SizedBox(height: 32),

                  // OTP Input Field - compact like login
                  TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 8,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      labelText: '6-digit code',
                      hintText: '000000',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16,
                      ),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      filled: true,
                      fillColor: isDark ? Color(0xFF2a2a2a) : Colors.white,
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
                          : _otpController.text.length == 6
                          ? Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            )
                          : null,
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
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red, width: 1),
                      ),
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Resend OTP option
                  Center(
                    child: _remainingTime > 0
                        ? Column(
                            children: [
                              Text(
                                'Resend OTP in $_remainingTime seconds',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              LinearProgressIndicator(
                                value:
                                    _remainingTime /
                                    60, // Assuming max 60 seconds
                                backgroundColor: Colors.orange.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.orange,
                                ),
                              ),
                            ],
                          )
                        : TextButton(
                            onPressed: _isLoading ? null : _resendOTP,
                            child: _isLoading
                                ? SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                : Text(
                                    'Didn\'t receive code? Resend',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                  ),

                  Flexible(flex: 2, child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
