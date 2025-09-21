import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _userDataKey = 'userData';
  static const String _clubsDataKey = 'clubsData';
  static const String _clubIdKey = 'clubId';
  static const String _tokenKey = 'token';

  // Generic cache methods
  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> setJson(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
  }

  static Future<Map<String, dynamic>?> getJson(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        return json.decode(jsonString) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error decoding JSON for key $key: $e');
    }
    return null;
  }

  static Future<void> setJsonList(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
  }

  static Future<List<Map<String, dynamic>>?> getJsonList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final decoded = json.decode(jsonString);
        return List<Map<String, dynamic>>.from(decoded);
      }
    } catch (e) {
      debugPrint('Error decoding JSON list for key $key: $e');
    }
    return null;
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Specific cache methods for common data
  static Future<void> cacheUserData(Map<String, dynamic> userData) async {
    await setJson(_userDataKey, userData);
  }

  static Future<Map<String, dynamic>?> getCachedUserData() async {
    return await getJson(_userDataKey);
  }

  static Future<void> cacheClubsData(List<Map<String, dynamic>> clubsData) async {
    await setJsonList(_clubsDataKey, clubsData);
  }

  static Future<List<Map<String, dynamic>>?> getCachedClubsData() async {
    return await getJsonList(_clubsDataKey);
  }

  static Future<void> cacheToken(String token) async {
    await setString(_tokenKey, token);
  }

  static Future<String?> getCachedToken() async {
    return await getString(_tokenKey);
  }

  static Future<void> cacheClubId(String clubId) async {
    await setString(_clubIdKey, clubId);
  }

  static Future<String?> getCachedClubId() async {
    return await getString(_clubIdKey);
  }

  // Clear specific data
  static Future<void> clearUserData() async {
    await remove(_userDataKey);
  }

  static Future<void> clearClubsData() async {
    await remove(_clubsDataKey);
  }

  static Future<void> clearToken() async {
    await remove(_tokenKey);
  }

  static Future<void> clearClubId() async {
    await remove(_clubIdKey);
  }

  // Clear all auth-related data
  static Future<void> clearAuthData() async {
    await Future.wait([
      clearToken(),
      clearUserData(),
      clearClubsData(),
      clearClubId(),
    ]);
  }
}