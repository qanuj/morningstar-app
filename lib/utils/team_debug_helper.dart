// lib/utils/team_debug_helper.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class TeamDebugHelper {
  static Future<void> debugTeamLoading() async {
    print('🔍 === TEAM LOADING DEBUGGING ===');

    // 1. Check app configuration
    print('🌐 Base URL: ${AppConfig.apiBaseUrl}');
    print('🏭 Is Production: ${AppConfig.isProduction}');

    // 2. Check authentication
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('🔑 Token exists: ${token != null}');
    if (token != null) {
      print('🔑 Token preview: ${token.substring(0, 20)}...');
    }

    // 3. Test basic API connectivity
    await _testApiConnectivity();

    // 4. Test teams endpoint specifically
    if (token != null) {
      await _testTeamsEndpoint(token);
    }
  }

  static Future<void> _testApiConnectivity() async {
    try {
      print('📡 Testing basic API connectivity...');
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 10));

      print('📡 Health check status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ API is reachable');
      } else {
        print('❌ API returned error: ${response.body}');
      }
    } catch (e) {
      print('❌ API connectivity failed: $e');
    }
  }

  static Future<void> _testTeamsEndpoint(String token) async {
    try {
      print('📡 Testing teams endpoint...');

      // Test user teams
      final userTeamsUri = Uri.parse(
        '${AppConfig.apiBaseUrl}/teams/search',
      ).replace(queryParameters: {'onlyUserTeams': 'true', 'limit': '10'});

      print('📞 Calling: $userTeamsUri');

      final response = await http
          .get(
            userTeamsUri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      print('📡 Teams endpoint status: ${response.statusCode}');
      print('📡 Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          print('✅ Got ${data.length} teams');
          if (data.isNotEmpty) {
            print('📊 First team example: ${data[0]}');
          }
        } else {
          print('⚠️ Unexpected response format: $data');
        }
      } else {
        print('❌ Teams endpoint error: ${response.body}');
      }

      // Also test opponent teams
      final opponentTeamsUri = Uri.parse(
        '${AppConfig.apiBaseUrl}/teams/search',
      ).replace(queryParameters: {'includeUserTeams': 'false', 'limit': '10'});

      print('📞 Calling opponent teams: $opponentTeamsUri');

      final opponentResponse = await http
          .get(
            opponentTeamsUri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      print('📡 Opponent teams status: ${opponentResponse.statusCode}');
      if (opponentResponse.statusCode == 200) {
        final opponentData = jsonDecode(opponentResponse.body);
        if (opponentData is List) {
          print('✅ Got ${opponentData.length} opponent teams');
        }
      }
    } catch (e) {
      print('❌ Teams endpoint test failed: $e');
    }
  }
}
