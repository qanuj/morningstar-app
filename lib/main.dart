import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'providers/club_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/conversation_provider.dart';
import 'screens/auth/splash.dart';
import 'screens/shared/share_target_screen.dart';
import 'services/notification_service.dart';
import 'services/share_handler_service.dart';
import 'utils/theme.dart';
import 'config/app_config.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase with options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Initialize Push Notifications
    await NotificationService.initialize();
    print('✅ NotificationService initialized successfully');
    
    // Initialize Share Handler Service
    ShareHandlerService().initialize();
    print('✅ ShareHandlerService initialized successfully');
    
  } catch (e) {
    print('❌ Failed to initialize Firebase or NotificationService: $e');
  }

  // Log current configuration
  AppConfig.logConfig();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late ThemeProvider _themeProvider;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _sharedContentSubscription;

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider();
    _themeProvider.init();
    _setupSharedContentListener();
  }

  void _setupSharedContentListener() {
    _sharedContentSubscription = ShareHandlerService().sharedContentStream.listen(
      (sharedContent) {
        print('📤 Received shared content: ${sharedContent.type.name}');
        
        // Navigate to ShareTargetScreen when content is shared
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = _navigatorKey.currentState;
          if (navigator != null) {
            // Check if ShareTargetScreen is already on top
            bool isShareTargetVisible = false;
            navigator.popUntil((route) {
              if (route.settings.name == '/share_target' || 
                  route.toString().contains('ShareTargetScreen')) {
                isShareTargetVisible = true;
              }
              return true;
            });
            
            // Only navigate if ShareTargetScreen is not already visible
            if (!isShareTargetVisible) {
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => ShareTargetScreen(
                    sharedContent: sharedContent,
                  ),
                  settings: const RouteSettings(name: '/share_target'),
                ),
              );
            }
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _sharedContentSubscription?.cancel();
    ShareHandlerService().dispose();
    super.dispose();
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
            navigatorKey: _navigatorKey,
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
