// lib/config/app_config.dart
import 'package:flutter/material.dart';

class AppConfig {
  // Environment configuration
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  // API Configuration
  static const String _developmentBaseUrl = 'http://192.168.1.43:3000/api';
  static const String _productionBaseUrl = 'https://duggy.app/api';

  static String get apiBaseUrl =>
      isProduction ? _productionBaseUrl : _developmentBaseUrl;

  // Other environment-specific configurations
  static const bool enableLogging = !isProduction;
  static const bool enableDebugPrints = !isProduction;

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
