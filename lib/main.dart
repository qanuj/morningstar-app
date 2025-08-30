import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'providers/user_provider.dart';
import 'providers/club_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/conversation_provider.dart';
import 'screens/splash.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider();
    _themeProvider.init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ClubProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider.value(value: _themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Duggy',
            theme: AppTheme.duggyTheme,
            darkTheme: AppTheme.duggyDarkTheme,
            themeMode: themeProvider.materialThemeMode,
            home: SplashScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
