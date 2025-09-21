import 'package:file_picker/file_picker.dart';

import '../config/app_config.dart';
import 'auth_service.dart';
import 'file_upload_service.dart';
import 'http_service.dart';

// Export ApiException for backward compatibility
export 'http_service.dart' show ApiException;

// Facade for the old ApiService - delegates to focused services
class ApiService {
  // Initialize all services
  static Future<void> init() async {
    await HttpService.init();
    await AuthService.init();
  }

  static void dispose() {
    HttpService.dispose();
  }

  // HTTP methods - delegate to HttpService
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) =>
      HttpService.get(endpoint, queryParams: queryParams);

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool retry = false,
  }) =>
      HttpService.post(endpoint, data);

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool retry = false,
  }) =>
      HttpService.put(endpoint, data);

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> data, {
    bool retry = false,
  }) =>
      HttpService.patch(endpoint, data);

  static Future<Map<String, dynamic>> delete(String endpoint, [dynamic data]) =>
      HttpService.delete(endpoint, data ?? {});

  // Auth methods - delegate to AuthService
  static Future<void> setToken(
    String token, {
    Map<String, dynamic>? userData,
    List<Map<String, dynamic>>? clubsData,
  }) =>
      AuthService.setToken(token, userData: userData, clubsData: clubsData);

  static Future<void> clearToken() => AuthService.clearToken();

  static Future<void> clearClubsCache() => AuthService.clearClubsCache();

  // Getters for backward compatibility
  static Map<String, dynamic>? get cachedUserData => AuthService.userData;
  static List<Map<String, dynamic>>? get cachedClubsData => AuthService.clubsData;
  static bool get hasUserData => AuthService.hasUserData;
  static bool get hasClubsData => AuthService.hasClubsData;

  // File upload methods - delegate to FileUploadService
  static Future<String?> uploadFile(PlatformFile file) =>
      FileUploadService.uploadFile(file);

  static Future<List<String>> uploadMultipleFiles(List<PlatformFile> files) =>
      FileUploadService.uploadMultipleFiles(files);

  // Domain-specific endpoints
  static Future<Map<String, dynamic>> getProfile() async {
    final response = await get('/profile');

    if (response['user'] != null) {
      await AuthService.updateUserData(response['user']);
    }
    return response;
  }

  // Backward compatibility getters and methods
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth compatibility methods
  static Future<bool> isLoggedIn() async => AuthService.isLoggedIn;
  static Future<Map<String, dynamic>> getCurrentUser() => getProfile();
  static Future<void> logout() => AuthService.clearToken();

  // Network timing stubs (removed complex functionality)
  static void enableNetworkTiming() {
    // Stub - complex network timing removed for simplicity
  }

  static void disableNetworkTiming() {
    // Stub - complex network timing removed for simplicity
  }

  static void clearNetworkTimings() {
    // Stub - complex network timing removed for simplicity
  }

  static List<dynamic> getSlowRequests({int thresholdMs = 2000}) {
    // Stub - return empty list
    return [];
  }

  static List<dynamic> getDnsIssues({int thresholdMs = 1000}) {
    // Stub - return empty list
    return [];
  }

  static List<dynamic> getTlsIssues({int thresholdMs = 2000}) {
    // Stub - return empty list
    return [];
  }
}
