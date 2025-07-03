import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'providers/user_provider.dart';
import 'providers/club_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ClubProvider()),
      ],
      child: MaterialApp(
        title: 'Duggy',
        theme: AppTheme.cricketTheme,
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
