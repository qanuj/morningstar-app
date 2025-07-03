import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await AuthService.getCurrentUser();
      _user = User.fromJson(userData);
    } catch (e) {
      print('Error loading user: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await ApiService.put('/auth/profile', data);
      _user = User.fromJson(response);
      notifyListeners();
    } catch (e) {
      throw e;
    }
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
