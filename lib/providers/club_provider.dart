import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ClubProvider with ChangeNotifier {
  List<ClubMembership> _clubs = [];
  ClubMembership? _currentClub;
  bool _isLoading = false;

  List<ClubMembership> get clubs => _clubs;
  ClubMembership? get currentClub => _currentClub;
  bool get isLoading => _isLoading;

  Future<void> loadClubs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> response = await ApiService.get('/my/clubs');
      List<dynamic> clubsData = [];
      
      // Handle different response formats
      final data = response['data'];
      if (data is List) {
        clubsData = data;
      } else if (data is Map) {
        clubsData = [data]; // Single club wrapped in data
      }
      
      _clubs = clubsData.map((club) {
        try {
          return ClubMembership.fromJson(club);
        } catch (e) {
          print('Error parsing club: $e');
          print('Club data: $club');
          rethrow;
        }
      }).toList();
      
      // Set current club if exists
      final currentClubId = await AuthService.getCurrentClubId();
      if (currentClubId != null && _clubs.isNotEmpty) {
        try {
          _currentClub = _clubs.firstWhere(
            (club) => club.club.id == currentClubId,
          );
        } catch (e) {
          // Club not found, set to first available
          _currentClub = _clubs.first;
          await AuthService.setCurrentClubId(_currentClub!.club.id);
        }
      } else if (_clubs.isNotEmpty) {
        _currentClub = _clubs.first;
        await AuthService.setCurrentClubId(_currentClub!.club.id);
      }
    } catch (e) {
      print('Error loading clubs: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrentClub(ClubMembership club) async {
    _currentClub = club;
    await AuthService.setCurrentClubId(club.club.id);
    notifyListeners();
  }
}