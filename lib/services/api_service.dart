// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'network_timing_service.dart';

class ApiException implements Exception {
  final String message;
  final String rawResponse;

  ApiException(this.message, this.rawResponse);

  @override
  String toString() => message;
}

class ApiService {
  // Get base URL from app configuration
  static String get baseUrl => AppConfig.apiBaseUrl;
  static String? _token;
  static Map<String, dynamic>? _userData;
  static List<Map<String, dynamic>>? _clubsData;

  // HTTP client with optimized settings for mobile networks and precise timing
  static late http.Client _httpClient;
  static late TimedHttpClient _timedHttpClient;

  // Timeout configurations optimized for mobile networks
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const Duration _sendTimeout = Duration(seconds: 15);

  static void _initializeHttpClient() {
    _httpClient = http.Client();
    _timedHttpClient = TimedHttpClient(_httpClient);
  }

  static Future<void> init() async {
    // Initialize HTTP client
    _initializeHttpClient();

    // Enable network timing by default in debug mode
    if (AppConfig.enableDebugPrints) {
      enableNetworkTiming();
    }

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    // Load cached user and clubs data
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      try {
        _userData = json.decode(userDataString);
      } catch (e) {
        debugPrint('Error loading cached user data: $e');
      }
    }

    final clubsDataString = prefs.getString('clubsData');
    if (clubsDataString != null) {
      try {
        final decoded = json.decode(clubsDataString);
        _clubsData = List<Map<String, dynamic>>.from(decoded);
      } catch (e) {
        debugPrint('Error loading cached clubs data: $e');
      }
    }
  }

  static Future<void> setToken(
    String token, {
    Map<String, dynamic>? userData,
    List<Map<String, dynamic>>? clubsData,
  }) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);

    // Store user data if provided
    if (userData != null) {
      _userData = userData;
      await prefs.setString('userData', json.encode(userData));
    }

    // Store clubs data if provided
    if (clubsData != null) {
      _clubsData = clubsData;
      await prefs.setString('clubsData', json.encode(clubsData));
    }
  }

  static Future<void> clearToken() async {
    _token = null;
    _userData = null;
    _clubsData = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userData');
    await prefs.remove('clubsData');
    await prefs.remove('clubId');
  }

  static Future<void> clearClubsCache() async {
    _clubsData = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('clubsData');
  }

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Map<String, String> get fileHeaders => {
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Conservative retry logic for mobile network reliability
  static Future<T> _retryRequest<T>(
    Future<T> Function() request, {
    int maxRetries = 2, // Reduced from 3 to 2
    Duration delay = const Duration(seconds: 1), // Reduced from 2 to 1
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await request().timeout(_receiveTimeout);
      } catch (e) {
        if (attempt == maxRetries) rethrow;

        // Only retry on clear network connection failures
        if (e is SocketException &&
            (e.toString().contains('Failed host lookup') ||
             e.toString().contains('Network is unreachable') ||
             e.toString().contains('Connection refused'))) {

          if (AppConfig.enableDebugPrints) {
            debugPrint('🔄 Network error (attempt $attempt/$maxRetries): $e');
            debugPrint('⏳ Retrying in ${delay.inSeconds}s...');
          }

          await Future.delayed(delay);
          continue;
        }

        rethrow; // Don't retry on anything else
      }
    }

    throw Exception('Max retries exceeded');
  }

  // Getters for cached data
  static Map<String, dynamic>? get cachedUserData => _userData;
  static List<Map<String, dynamic>>? get cachedClubsData => _clubsData;
  static bool get hasUserData => _userData != null;
  static bool get hasClubsData => _clubsData != null;

  // Network timing controls
  static void enableNetworkTiming() {
    NetworkTimingService.setEnabled(true);
    if (AppConfig.enableDebugPrints) {
      debugPrint('🔍 Network timing enabled - DNS/TLS/connection delays will be logged');
    }
  }

  static void disableNetworkTiming() {
    NetworkTimingService.setEnabled(false);
    if (AppConfig.enableDebugPrints) {
      debugPrint('🔍 Network timing disabled');
    }
  }

  static void printNetworkPerformanceSummary() {
    NetworkTimingService.printPerformanceSummary();
  }

  static void clearNetworkTimings() {
    NetworkTimingService.clearTimings();
    if (AppConfig.enableDebugPrints) {
      debugPrint('🔍 Network timing data cleared');
    }
  }

  static List<NetworkTiming> getSlowRequests({int thresholdMs = 2000}) {
    return NetworkTimingService.getSlowRequests(thresholdMs: thresholdMs);
  }

  static List<NetworkTiming> getDnsIssues({int thresholdMs = 1000}) {
    return NetworkTimingService.getDnsIssues(thresholdMs: thresholdMs);
  }

  static List<NetworkTiming> getTlsIssues({int thresholdMs = 2000}) {
    return NetworkTimingService.getTlsIssues(thresholdMs: thresholdMs);
  }

  static Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) async {
    return await _retryRequest(() async {
      String url = '$baseUrl$endpoint';
      if (queryParams != null && queryParams.isNotEmpty) {
        final query = queryParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url += '?$query';
      }

      if (AppConfig.enableDebugPrints) {
        debugPrint('🔵 Making GET request to: $url');
      }

      final response = await _timedHttpClient.get(
        Uri.parse(url),
        headers: headers,
      );
      return _handleResponse(response);
    });
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    return await _retryRequest(() async {
      if (AppConfig.enableDebugPrints) {
        print('🔵 Making POST request to: $baseUrl$endpoint');
        print('🔵 Request data: $data');
        print('🔵 Request headers: $headers');
      }

      final response = await _timedHttpClient.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );

      if (AppConfig.enableDebugPrints) {
        print('🔵 Response status: ${response.statusCode}');
        print('🔵 Response body: ${response.body}');
      }

      return _handleResponse(response);
    });
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    return await _retryRequest(() async {
      final response = await _timedHttpClient.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );
      return _handleResponse(response);
    });
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    return await _retryRequest(() async {
      final response = await _timedHttpClient.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(data),
      );
      return _handleResponse(response);
    });
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, [
    dynamic data,
  ]) async {
    return await _retryRequest(() async {
      final response = await _timedHttpClient.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: data != null ? json.encode(data) : null,
      );
      return _handleResponse(response);
    });
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (AppConfig.enableDebugPrints) {
      print('🔵 Handling response with status: ${response.statusCode}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (AppConfig.enableDebugPrints) {
        print('✅ Success Response Body Length: ${response.body.length}');
        print('✅ Response Headers: ${response.headers}');
      }

      // Handle empty response
      if (response.body.isEmpty) {
        return {'success': true};
      }

      try {
        final decoded = json.decode(response.body);
        if (AppConfig.enableDebugPrints) {
          print('🔵 Decoded response type: ${decoded.runtimeType}');
        }

        // Handle both Map and List responses
        if (decoded is List) {
          return {'data': decoded};
        }
        return decoded as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ Error decoding JSON: $e');
        debugPrint('❌ Response body (first 200 chars): ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');

        // Return raw response if JSON parsing fails
        return {
          'success': false,
          'error': 'JSON parsing failed',
          'raw_response': response.body,
          'status_code': response.statusCode,
        };
      }
    } else {
      debugPrint('❌ Error Response Body: ${response.body}');

      try {
        final error = json.decode(response.body);
        final errorMessage =
            error['error'] ??
            error['message'] ??
            'API Error (${response.statusCode})';
        debugPrint('❌ Parsed error: $errorMessage');
        throw ApiException(errorMessage, response.body);
      } catch (e) {
        if (e is ApiException) {
          rethrow;
        }
        debugPrint('❌ Error parsing error response: $e');
        throw Exception('API Error (${response.statusCode}): ${response.body}');
      }
    }
  }

  /// Get user profile data
  static Future<Map<String, dynamic>> getProfile() async {
    if (AppConfig.enableDebugPrints) {
      debugPrint('🔵 Fetching user profile from /profile');
    }
    final response = await get('/profile');

    // Update cached user data if successful
    if (response['user'] != null) {
      _userData = response['user'];
      print('🔵 User profile fetched: $_userData');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', json.encode(_userData));
    }

    return response;
  }

  /// Upload a file and return the URL
  static Future<String?> uploadFile(PlatformFile file) async {
    try {
      // Get original file bytes
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

      request.headers.addAll(fileHeaders);

      // Determine content type based on file extension
      String? contentType;
      final extension = file.extension?.toLowerCase();
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        case 'pdf':
          contentType = 'application/pdf';
          break;
        case 'txt':
          contentType = 'text/plain';
          break;
        case 'm4a':
          contentType = 'audio/mp4';
          break;
        case 'mp4':
          contentType = 'video/mp4';
          break;
        case 'mp3':
          contentType = 'audio/mpeg';
          break;
        case 'wav':
          contentType = 'audio/wav';
          break;
        case 'aac':
          contentType = 'audio/aac';
          break;
        default:
          contentType = 'application/octet-stream';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
          contentType: MediaType.parse(contentType),
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        if (jsonResponse['success'] == true && jsonResponse['url'] != null) {
          return jsonResponse['url'];
        }
      }

      debugPrint('❌ File upload failed: $responseData');
      return null;
    } catch (e) {
      debugPrint('❌ Error uploading file: $e');
      return null;
    }
  }
}
