import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null;
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    return await ApiService.get('/auth/me');
  }

  static Future<void> logout() async {
    await ApiService.clearToken();
  }

  static Future<String?> getCurrentClubId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('clubId');
  }

  static Future<void> setCurrentClubId(String clubId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clubId', clubId);
  }
}