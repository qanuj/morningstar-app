// lib/config/app_config.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConfig {
  // Environment configuration
  static bool get isProduction {
    // First try dart-define
    const dartDefineProduction = bool.fromEnvironment(
      'PRODUCTION',
      defaultValue: false,
    );
    if (dartDefineProduction) return true;

    // For iOS release builds, use kReleaseMode as fallback
    // This ensures Xcode archive builds use production
    return kReleaseMode;
  }

  // API Configuration
  static const String _developmentBaseUrl = 'http://192.168.1.56:3000/api';
  static const String _productionBaseUrl = 'https://duggy.app/api';

  static String get apiBaseUrl =>
      isProduction ? _productionBaseUrl : _developmentBaseUrl;

  // Other environment-specific configurations
  static bool get enableLogging => !isProduction;
  static bool get enableDebugPrints => !isProduction;

  // App information
  static const String appName = 'Duggy';
  static const String appVersion = '1.0.0';

  // Development helpers
  static void logConfig() {
    if (enableDebugPrints) {
      debugPrint('🔧 App Configuration:');
      debugPrint(
        '   Environment: ${isProduction ? "Production" : "Development"}',
      );
      debugPrint('   API Base URL: $apiBaseUrl');
      debugPrint('   Logging Enabled: $enableLogging');
      debugPrint('   Debug Prints: $enableDebugPrints');
    }
  }
}
