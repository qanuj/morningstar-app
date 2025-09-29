import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/club_provider.dart';
import '../../widgets/duggy_logo.dart';
import '../../utils/theme.dart';
import 'login.dart';
import '../shared/home.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await ApiService.init();

    final isLoggedIn = AuthService.isLoggedIn;

    await Future.delayed(Duration(seconds: 2)); // Show splash for 2 seconds

    if (isLoggedIn) {
      try {
        await Provider.of<UserProvider>(context, listen: false).loadUser();
        await Provider.of<ClubProvider>(context, listen: false).loadClubs();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } catch (e) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
      }
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryBlue, AppTheme.darkBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Duggy Logo
                DuggyLogoVariant.splash(context),

                SizedBox(height: 40),

                // Subtitle
                Text(
                  'Your Cricket Club Companion',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.9),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),

                SizedBox(height: 60),

                // Loading Indicator
                Container(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.2),
                  ),
                ),

                SizedBox(height: 20),

                // Loading Text
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
