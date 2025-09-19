import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/club_provider.dart';
import '../../widgets/duggy_logo.dart';
import '../shared/home.dart';

class CollectNameScreen extends StatefulWidget {
  final String phoneNumber;
  final String token;

  const CollectNameScreen({
    super.key,
    required this.phoneNumber,
    required this.token,
  });

  @override
  State<CollectNameScreen> createState() => _CollectNameScreenState();
}

class _CollectNameScreenState extends State<CollectNameScreen> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the name input field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _updateNameAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Name must be at least 2 characters long')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Set token first so we can make authenticated API calls
      await ApiService.setToken(widget.token);

      // Update user's name
      await ApiService.put('/auth/me', {
        'name': name,
      });

      // Get user and clubs data from the API after successful update
      Map<String, dynamic>? userData;
      List<Map<String, dynamic>>? clubsData;

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

        // Fetch clubs data from /my/clubs
        final clubsResponse = await ApiService.get('/my/clubs');
        final data = clubsResponse['data'];
        if (data is List) {
          clubsData = List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          clubsData = [Map<String, dynamic>.from(data)];
        }

        // Update ApiService with the fetched data
        await ApiService.setToken(
          widget.token,
          userData: userData,
          clubsData: clubsData,
        );
      } catch (e) {
        debugPrint('Error fetching user/clubs data: $e');
        // Continue with login even if additional data fetch fails
      }

      // Load data from cached sources in providers
      await Provider.of<UserProvider>(context, listen: false).loadUser();
      await Provider.of<ClubProvider>(context, listen: false).loadClubs();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen()),
        (route) => false,
      );
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(flex: 2),

              // Logo
              Center(
                child: DuggyLogoVariant.large(
                  color: theme.colorScheme.primary,
                  showText: false,
                ),
              ),

              SizedBox(height: 48),

              // Welcome text
              Text(
                'Welcome to Duggy!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),

              SizedBox(height: 8),

              Text(
                'Please tell us your name to get started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),

              SizedBox(height: 32),

              // Name Input Field
              TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _updateNameAndContinue(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'Enter your full name',
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
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: theme.colorScheme.primary,
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
                      : _nameController.text.trim().length >= 2
                      ? IconButton(
                          onPressed: _updateNameAndContinue,
                          icon: Icon(
                            Icons.arrow_forward,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Continue Button
              ElevatedButton(
                onPressed: _isLoading ? null : _updateNameAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}