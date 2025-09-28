import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'providers/club_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/conversation_provider.dart';
import 'screens/auth/splash.dart';
import 'screens/shared/share_target_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';
import 'services/share_handler_service.dart';
import 'services/api_service.dart';
import 'utils/theme.dart';
import 'config/app_config.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize API Service with optimized settings
    await ApiService.init();
    print('✅ ApiService initialized successfully');

    // Configure image caching for mobile networks
    await _configureImageCache();
    print('✅ Image cache configured successfully');

    // Initialize Firebase with options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    // Initialize Push Notifications
    await NotificationService.initialize();
    print('✅ NotificationService initialized successfully');

    // Initialize Background Sync Service for real-time updates
    try {
      await BackgroundSyncService.initialize();
      print('✅ BackgroundSyncService initialized successfully');
    } catch (e) {
      print(
        '⚠️ BackgroundSyncService initialization failed (will retry when authenticated): $e',
      );
      // This is not critical for app startup, sync will be retried when user is authenticated
    }

    // Initialize Share Handler Service
    ShareHandlerService().initialize();
    print('✅ ShareHandlerService initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize services: $e');
  }

  // Log current configuration
  AppConfig.logConfig();

  runApp(MyApp());
}

// Configure optimized image caching for mobile networks
Future<void> _configureImageCache() async {
  // Configure CachedNetworkImage for mobile optimization
  await CachedNetworkImage.evictFromCache('dummy'); // Initialize cache manager

  // Set global image cache configuration
  PaintingBinding.instance.imageCache.maximumSize =
      100; // Reduce from default 1000
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      50 << 20; // 50MB instead of 100MB
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late ThemeProvider _themeProvider;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _sharedContentSubscription;

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider();
    _themeProvider.init();
    _setupSharedContentListener();

    // Add lifecycle observer for background sync
    WidgetsBinding.instance.addObserver(this);
  }

  void _setupSharedContentListener() {
    _sharedContentSubscription = ShareHandlerService().sharedContentStream
        .listen(
          (sharedContent) {
            print('📤 === SHARED CONTENT RECEIVED ===');
            print('📤 Type: ${sharedContent.type.name}');
            print('📤 Text: ${sharedContent.text}');
            print('📤 Image Paths: ${sharedContent.imagePaths}');
            print('📤 Display Text: ${sharedContent.displayText}');
            print('📤 Is Valid: ${sharedContent.isValid}');
            print('📤 Has Images: ${sharedContent.hasImages}');
            print('📤 ==============================');

            // Validate shared content before navigation
            if (!sharedContent.isValid) {
              print('❌ Invalid shared content received, skipping navigation');
              return;
            }

            // Navigate to ShareTargetScreen when content is shared
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                final navigator = _navigatorKey.currentState;
                if (navigator == null) {
                  print('❌ Navigator not available for shared content');
                  return;
                }

                // Navigate to ShareTargetScreen for shared content
                print('📤 Navigating to ShareTargetScreen');
                navigator
                    .push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ShareTargetScreen(sharedContent: sharedContent),
                        settings: const RouteSettings(name: '/share_target'),
                      ),
                    )
                    .catchError((e) {
                      print('❌ Navigation error to ShareTargetScreen: $e');
                      // Handle navigation errors gracefully
                    });
              } catch (e) {
                print('❌ Error navigating to ShareTargetScreen: $e');
                // Try alternative navigation method
                try {
                  Navigator.of(_navigatorKey.currentContext!).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ShareTargetScreen(sharedContent: sharedContent),
                    ),
                  );
                } catch (e2) {
                  print('❌ Fallback navigation also failed: $e2');
                }
              }
            });
          },
          onError: (error) {
            print('❌ Error in shared content stream: $error');
          },
        );
  }

  @override
  void dispose() {
    _sharedContentSubscription?.cancel();
    ShareHandlerService().dispose();
    WidgetsBinding.instance.removeObserver(this);
    BackgroundSyncService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App is active - use faster sync interval
        BackgroundSyncService.setAppActiveState(true);
        // Trigger immediate sync when app becomes active
        BackgroundSyncService.triggerSync();
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is backgrounded - use slower sync interval
        BackgroundSyncService.setAppActiveState(false);
        break;

      case AppLifecycleState.detached:
        // App is being terminated - stop sync service
        BackgroundSyncService.stop();
        break;

      case AppLifecycleState.hidden:
        // App is hidden but still running - use slower sync
        BackgroundSyncService.setAppActiveState(false);
        break;
    }
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
          // Set club provider reference for notifications and background sync after context is available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              final clubProvider = Provider.of<ClubProvider>(
                context,
                listen: false,
              );
              NotificationService.setClubProvider(clubProvider);
              BackgroundSyncService.setClubProvider(clubProvider);
            } catch (e) {
              print('⚠️ Failed to set club provider reference: $e');
            }
          });

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
