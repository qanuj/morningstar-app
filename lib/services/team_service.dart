import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/team.dart';
import '../config/app_config.dart';

class TeamService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Search all teams with optional filters
  static Future<List<Team>> searchTeams({
    String? query,
    int limit = 20,
    String? excludeTeamId,
    bool includeUserTeams = false,
    bool onlyUserTeams = false,
    String? sport,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('$baseUrl/teams/search').replace(queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        'limit': limit.toString(),
        if (excludeTeamId != null) 'excludeTeamId': excludeTeamId,
        'includeUserTeams': includeUserTeams.toString(),
        'onlyUserTeams': onlyUserTeams.toString(),
        if (sport != null) 'sport': sport,
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> teamsJson = jsonDecode(response.body);
        return teamsJson.map((team) => Team.fromJson(team)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access');
      } else {
        throw Exception('Failed to search teams: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching teams: $e');
      throw Exception('Failed to search teams: $e');
    }
  }

  /// Get user's teams
  static Future<List<Team>> getUserTeams() async {
    return await searchTeams(onlyUserTeams: true);
  }

  /// Get opponent teams (teams from clubs user is not a member of)
  static Future<List<Team>> getOpponentTeams({String? excludeTeamId}) async {
    return await searchTeams(
      includeUserTeams: false,
      excludeTeamId: excludeTeamId,
    );
  }

  /// Get teams for a specific club
  static Future<List<Team>> getClubTeams({
    required String clubId,
    String? search,
    String? provider,
    int limit = 50,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('$baseUrl/clubs/$clubId/teams').replace(queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (provider != null) 'provider': provider,
        'limit': limit.toString(),
      });

      print('🚀 Making request to: $uri');
      print('🔑 Token available: ${token != null}');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final List<dynamic> teamsJson = responseBody['teams'] ?? [];
        print('📊 Teams count: ${teamsJson.length}');
        return teamsJson.map((team) => Team.fromJson(team)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden - you may not have permission to manage this club');
      } else {
        try {
          final Map<String, dynamic>? errorBody = jsonDecode(response.body);
          final errorMessage = errorBody?['error'] ?? 'Failed to get club teams';
          throw Exception('$errorMessage (${response.statusCode})');
        } catch (jsonError) {
          throw Exception('Failed to get club teams: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ Error getting club teams: $e');
      rethrow;
    }
  }

  /// Create a new team for a club
  static Future<Team> createTeam({
    required String clubId,
    required String name,
    String? logo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final requestBody = {
        'name': name,
        'sport': 'cricket', // Default sport for the app
        'provider': 'DUGGY', // Default provider as per backend validation
        'providerId': DateTime.now().millisecondsSinceEpoch.toString(), // Generate unique ID
        if (logo != null && logo.isNotEmpty) 'logo': logo,
      };

      print('🚀 Creating team with data: ${jsonEncode(requestBody)}');
      print('🔗 URL: $baseUrl/clubs/$clubId/teams');

      final response = await http.post(
        Uri.parse('$baseUrl/clubs/$clubId/teams'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Create team response status: ${response.statusCode}');
      print('📡 Create team response body: ${response.body}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        return Team.fromJson(responseBody['team']);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access');
      } else if (response.statusCode == 400) {
        try {
          final Map<String, dynamic> errorBody = jsonDecode(response.body);
          String errorMessage = errorBody['error'] ?? 'Invalid team data';

          // If there are validation details, include them
          if (errorBody['details'] != null && errorBody['details'] is List) {
            final List details = errorBody['details'];
            if (details.isNotEmpty) {
              final validationErrors = details
                  .map((detail) => detail['message'] ?? detail.toString())
                  .join(', ');
              errorMessage = '$errorMessage: $validationErrors';
            }
          }

          throw Exception(errorMessage);
        } catch (jsonError) {
          print('Error parsing error response: $jsonError');
          throw Exception('Invalid team data - server returned 400');
        }
      } else {
        throw Exception('Failed to create team: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creating team: $e');
      rethrow;
    }
  }

  /// Update an existing team
  static Future<Team> updateTeam({
    required String teamId,
    required String clubId,
    String? name,
    String? logo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (logo != null) updateData['logo'] = logo.isEmpty ? null : logo;

      final response = await http.put(
        Uri.parse('$baseUrl/clubs/$clubId/teams/$teamId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        return Team.fromJson(responseBody['team']);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access');
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Invalid team data');
      } else {
        throw Exception('Failed to update team: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating team: $e');
      throw Exception('Failed to update team: $e');
    }
  }

  /// Delete a team
  static Future<void> deleteTeam({
    required String teamId,
    required String clubId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/clubs/$clubId/teams/$teamId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access');
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Cannot delete team');
      } else {
        throw Exception('Failed to delete team: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting team: $e');
      throw Exception('Failed to delete team: $e');
    }
  }
}