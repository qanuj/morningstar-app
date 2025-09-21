import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String? _token;
  static Map<String, dynamic>? _userData;
  static List<Map<String, dynamic>>? _clubsData;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    // Load cached user data
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      try {
        _userData = json.decode(userDataString);
      } catch (e) {
        debugPrint('Error loading cached user data: $e');
      }
    }

    // Load cached clubs data
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

    if (userData != null) {
      _userData = userData;
      await prefs.setString('userData', json.encode(userData));
    }

    if (clubsData != null) {
      _clubsData = clubsData;
      await prefs.setString('clubsData', json.encode(clubsData));
    }
  }

  static Future<void> updateUserData(Map<String, dynamic> userData) async {
    _userData = userData;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', json.encode(userData));
  }

  static Future<void> updateClubsData(List<Map<String, dynamic>> clubsData) async {
    _clubsData = clubsData;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clubsData', json.encode(clubsData));
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

  // Getters
  static String? get token => _token;
  static bool get hasToken => _token != null;
  static bool get isLoggedIn => _token != null;

  static Map<String, dynamic>? get userData => _userData;
  static List<Map<String, dynamic>>? get clubsData => _clubsData;
  static bool get hasUserData => _userData != null;
  static bool get hasClubsData => _clubsData != null;

  // Helper methods
  static String? get userId => _userData?['id']?.toString();
  static String? get userEmail => _userData?['email'];
  static String? get userName => _userData?['name'];
  static String? get userPhone => _userData?['phone'];
  static String? get userRole => _userData?['role'];
  static bool get isClubOwner => userRole == 'owner' || userRole == 'admin';

  // Club management
  static Future<String?> getCurrentClubId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('clubId');
  }

  static Future<void> setCurrentClubId(String clubId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clubId', clubId);
  }

  // Backward compatibility methods
  static Future<void> logout() => clearToken();

  // Placeholder - will be replaced by HttpService call
  static Future<Map<String, dynamic>> getCurrentUser() async {
    throw UnimplementedError('Use ApiService.getCurrentUser() instead');
  }
}