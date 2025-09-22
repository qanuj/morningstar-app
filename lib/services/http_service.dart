import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final String rawResponse;
  ApiException(this.message, this.rawResponse);
  @override
  String toString() => message;
}

class HttpService {
  static late http.Client _client;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    final ioClient = HttpClient()
      ..connectionTimeout = AppConfig.connectionTimeout
      ..idleTimeout = AppConfig.idleConnectionKeepAlive
      ..autoUncompress = true;

    _client = IOClient(ioClient);
    _initialized = true;
  }

  static void dispose() {
    if (_initialized) {
      _client.close();
      _initialized = false;
    }
  }

  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (AuthService.hasToken) 'Authorization': 'Bearer ${AuthService.token}',
  };

  static Map<String, String> get _baseHeaders => {
    'Accept': 'application/json',
    if (AuthService.hasToken) 'Authorization': 'Bearer ${AuthService.token}',
  };

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    await init();

    final uri = _buildUri(endpoint, queryParams);

    if (AppConfig.enableDebugPrints) {
      debugPrint('🔵 GET: $uri');
    }

    try {
      final response = await _client
          .get(uri, headers: _baseHeaders)
          .timeout(AppConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (AppConfig.enableDebugPrints) {
        debugPrint('❌ GET failed: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await init();

    final uri = _buildUri(endpoint);

    if (AppConfig.enableDebugPrints) {
      debugPrint('🔵 POST: $uri');
    }

    try {
      final response = await _client
          .post(uri, headers: _headers, body: json.encode(data))
          .timeout(AppConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (AppConfig.enableDebugPrints) {
        debugPrint('❌ POST failed: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> postRaw(
    String endpoint,
    dynamic data,
  ) async {
    await init();

    final uri = _buildUri(endpoint);

    if (AppConfig.enableDebugPrints) {
      debugPrint('🔵 POST: $uri');
    }

    try {
      final response = await _client
          .post(uri, headers: _headers, body: json.encode(data))
          .timeout(AppConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (AppConfig.enableDebugPrints) {
        debugPrint('❌ POST failed: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await init();

    final uri = _buildUri(endpoint);

    try {
      final response = await _client
          .put(uri, headers: _headers, body: json.encode(data))
          .timeout(AppConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await init();

    final uri = _buildUri(endpoint);

    try {
      final response = await _client
          .patch(uri, headers: _headers, body: json.encode(data))
          .timeout(AppConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await init();

    final uri = _buildUri(endpoint);

    try {
      final response = await _client
          .delete(uri, headers: _baseHeaders, body: json.encode(data))
          .timeout(AppConfig.requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  static Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    final baseUrl = AppConfig.apiBaseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    return Uri.parse(
      '$baseUrl$cleanEndpoint',
    ).replace(queryParameters: queryParams);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (AppConfig.enableDebugPrints) {
      debugPrint('🔵 Response: ${response.statusCode}');
    }

    // Success 2xx
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {'success': true};

      try {
        final decoded = json.decode(response.body);
        if (decoded is List) return {'data': decoded};
        return decoded as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ JSON decode failed: $e');
        return {
          'success': false,
          'error': 'JSON parsing failed',
          'raw_response': response.body,
          'status_code': response.statusCode,
        };
      }
    }

    // Error path
    try {
      final error = json.decode(response.body);
      final msg = (error is Map)
          ? (error['error'] ??
                error['message'] ??
                'API Error (${response.statusCode})')
          : 'API Error (${response.statusCode})';
      throw ApiException(msg.toString(), response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw Exception('API Error (${response.statusCode}): ${response.body}');
    }
  }
}
