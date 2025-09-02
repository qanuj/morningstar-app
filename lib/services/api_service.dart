// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://duggy.app/api';
  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('clubId');
  }

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Map<String, String> get fileHeaders => {
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> get(String endpoint) async {
    debugPrint('🔵 Making GET request to: $baseUrl$endpoint');
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    print('🔵 Making POST request to: $baseUrl$endpoint');

    //print('🔵 Request data: $data');
    //print('🔵 Request headers: $headers');

    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );

    //print('🔵 Response status: ${response.statusCode}');
    //print('🔵 Response body: ${response.body}');

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, [
    dynamic data,
  ]) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: data != null ? json.encode(data) : null,
    );
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    //print('🔵 Handling response with status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      //print('✅ Success Response Body: ${response.body}');

      try {
        final decoded = json.decode(response.body);
        //print('🔵 Decoded response: $decoded');

        // Handle both Map and List responses
        if (decoded is List) {
          return {'data': decoded};
        }
        return decoded as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ Error decoding JSON: $e');
        throw Exception('Invalid JSON response: ${response.body}');
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
        throw Exception(errorMessage);
      } catch (e) {
        debugPrint('❌ Error parsing error response: $e');
        throw Exception('API Error (${response.statusCode}): ${response.body}');
      }
    }
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
