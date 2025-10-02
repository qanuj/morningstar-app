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
    try {
      print('📤 Setting up shared content listener...');

      _sharedContentSubscription = ShareHandlerService().sharedContentStream
          .listen(
            (sharedContent) {
              try {
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
                print('📤 Attempting to schedule navigation to ShareTargetScreen...');
                print('📤 Navigator key current state: ${_navigatorKey.currentState}');
                print('📤 Navigator key current context: ${_navigatorKey.currentContext}');

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  print('📤 PostFrameCallback executing for navigation...');
                  try {
                    final navigator = _navigatorKey.currentState;
                    if (navigator == null) {
                      print('❌ Navigator not available for shared content');
                      print('❌ Navigator key: $_navigatorKey');
                      return;
                    }

                    final context = _navigatorKey.currentContext;
                    if (context == null) {
                      print('❌ Context not available for shared content');
                      print('❌ Navigator state: $navigator');
                      return;
                    }

                    // Navigate to ShareTargetScreen for shared content
                    print('📤 ✅ Navigator and context available, navigating to ShareTargetScreen');
                    print('📤 Shared content: ${sharedContent.displayText}');
                    navigator
                        .push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ShareTargetScreen(sharedContent: sharedContent),
                            settings: const RouteSettings(name: '/share_target'),
                          ),
                        )
                        .then((_) {
                          print('📤 ✅ Navigation to ShareTargetScreen completed');
                        })
                        .catchError((e) {
                          print('❌ Navigation error to ShareTargetScreen: $e');
                          // Handle navigation errors gracefully
                        });
                  } catch (e) {
                    print('❌ Error navigating to ShareTargetScreen: $e');
                    // Don't crash the app on navigation errors
                  }
                });
              } catch (e, stackTrace) {
                print('❌ Error in shared content listener: $e');
                print('❌ Stack trace: $stackTrace');
                // Don't rethrow to prevent app crash
              }
            },
            onError: (error, stackTrace) {
              print('❌ Error in shared content stream: $error');
              print('❌ Stack trace: $stackTrace');
              // Don't crash on stream errors
            },
          );

      print('✅ Shared content listener set up successfully');
    } catch (e, stackTrace) {
      print('❌ Error setting up shared content listener: $e');
      print('❌ Stack trace: $stackTrace');
      // Don't crash during setup
    }
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

        // Check for shared content from ShareExtension
        print('📤 App resumed - checking for shared content from ShareExtension');
        ShareHandlerService().checkForSharedContent();
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
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<ClubProvider>(create: (_) => ClubProvider()),
        ChangeNotifierProvider<ConversationProvider>(create: (_) => ConversationProvider()),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
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
