// lib/config/app_config.dart
import 'package:flutter/foundation.dart';

class AppConfig {
  // ——— Environment ———
  static bool get isProduction {
    const dartDefineProduction = bool.fromEnvironment(
      'PRODUCTION',
      defaultValue: false,
    );
    if (dartDefineProduction) return true;
    return kReleaseMode;
  }

  // Toggle this to route the MOBILE APP to an IPv4-only alias when needed.
  // Create api4.duggy.app in Cloudflare DNS, keep it proxied (orange cloud),
  // and DON’T add AAAA at your origin. Browsers can still use dual-stack on duggy.app.
  static const bool useIPv4OnlyApiForMobile = true;

  // Toggle this to true when building for TestFlight (App Store Connect).
  // This forces the app to use production backend even in debug builds.
  // This is useful to test the app with TestFlight distribution before release.
  static const bool useTestFlightMode = true;

  // ——— API Base Hosts (no paths) ———
  static const String _prodHostDual = 'duggy.app'; // dual stack (web)
  static const String _prodHostV4 = 'api4.duggy.app'; // IPv4-only alias for app
  static const String _devLanHost = '192.168.1.56'; // your LAN backend
  static const int _devPort = 3000;

  // ——— API Base URLs (final) ———
  static String get _productionBaseUrl {
    final host = useIPv4OnlyApiForMobile ? _prodHostV4 : _prodHostDual;
    return 'https://$host/api';
  }

  static String get _developmentBaseUrl {
    // Choose one depending on where you run:
    // return 'http://$_androidEmuHost:$_devPort/api'; // Android Emulator
    // return 'http://$_iosSimHost:$_devPort/api';     // iOS Simulator
    return 'http://$_devLanHost:$_devPort/api'; // Real devices on same Wi-Fi
  }

  static String get apiBaseUrl => isProduction || useTestFlightMode
      ? _productionBaseUrl
      : _developmentBaseUrl;

  // Fallback production URLs for better connectivity
  static List<String> get productionFallbackUrls => [
    'https://$_prodHostV4/api', // IPv4-only first
    'https://$_prodHostDual/api', // Dual-stack fallback
  ];

  // ——— Logging ———
  static bool get enableLogging => !isProduction;
  static bool get enableDebugPrints => !isProduction;

  // ——— Network tuning (keep these aligned with ApiService) ———
  // TCP connect timeout: fail fast on bad path (IPv6 stalls etc.)
  static const Duration connectionTimeout = Duration(seconds: 3);
  // Total read timeout per request
  static const Duration requestTimeout = Duration(seconds: 30);
  // Reasonable idle keep-alive time for mobile radios
  static const Duration idleConnectionKeepAlive = Duration(seconds: 15);
  // Package-http retry policy from your ApiService (idempotent reads)
  static const int maxRetriesIdempotent = 2;
  static const int maxRetriesMutating = 0;

  // Network connectivity and fallback settings
  static const Duration fallbackTimeout = Duration(seconds: 5);
  static const int maxFallbackAttempts = 2;
  static const Duration connectivityCheckInterval = Duration(minutes: 1);
  static const Duration networkStatusCacheTime = Duration(seconds: 30);

  // ——— Image cache ———
  static const int maxImageCacheSize = 100;
  static const int maxImageCacheSizeBytes = 50 * 1024 * 1024; // 50MB

  // ——— App info ———
  static const String appName = 'Duggy';
  static const String appVersion = '1.0.0';

  // ——— Utilities ———
  static void logConfig() {
    if (!enableDebugPrints) return;
    debugPrint('🔧 App Configuration:');
    debugPrint(
      '   Environment: ${isProduction ? "Production" : "Development"}',
    );
    debugPrint('   API Base URL: $apiBaseUrl');
    debugPrint('   IPv4-only API for app: $useIPv4OnlyApiForMobile');
    debugPrint('   Connect timeout: ${connectionTimeout.inSeconds}s');
    debugPrint('   Request timeout: ${requestTimeout.inSeconds}s');
    debugPrint('   Idle keep-alive: ${idleConnectionKeepAlive.inSeconds}s');
    debugPrint(
      '   Retries (GET): $maxRetriesIdempotent, (mutations): $maxRetriesMutating',
    );
  }
}
