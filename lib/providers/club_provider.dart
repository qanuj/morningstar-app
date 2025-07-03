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
      final response = await ApiService.get('/clubs');
      _clubs = (response as List).map((club) => ClubMembership.fromJson(club)).toList();
      
      // Set current club if exists
      final currentClubId = await AuthService.getCurrentClubId();
      if (currentClubId != null) {
        _currentClub = _clubs.firstWhere(
          (club) => club.club.id == currentClubId,
          orElse: () => _clubs.isNotEmpty ? _clubs.first : throw Exception('No clubs found'),
        );
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