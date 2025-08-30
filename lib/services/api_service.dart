// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  static Future<Map<String, dynamic>> get(String endpoint) async {
    print('🔵 Making GET request to: $baseUrl$endpoint');
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    print('🔵 Making POST request to: $baseUrl$endpoint');
    print('🔵 Request data: $data');
    print('🔵 Request headers: $headers');
    
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    
    print('🔵 Response status: ${response.statusCode}');
    print('🔵 Response body: ${response.body}');
    
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> patch(String endpoint, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    print('🔵 Handling response with status: ${response.statusCode}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('✅ Success Response Body: ${response.body}');
      
      try {
        final decoded = json.decode(response.body);
        print('🔵 Decoded response: $decoded');
        
        // Handle both Map and List responses
        if (decoded is List) {
          return {'data': decoded};
        }
        return decoded as Map<String, dynamic>;
      } catch (e) {
        print('❌ Error decoding JSON: $e');
        throw Exception('Invalid JSON response: ${response.body}');
      }
    } else {
      print('❌ Error Response Body: ${response.body}');
      
      try {
        final error = json.decode(response.body);
        final errorMessage = error['error'] ?? error['message'] ?? 'API Error (${response.statusCode})';
        print('❌ Parsed error: $errorMessage');
        throw Exception(errorMessage);
      } catch (e) {
        print('❌ Error parsing error response: $e');
        throw Exception('API Error (${response.statusCode}): ${response.body}');
      }
    }
  }
}
