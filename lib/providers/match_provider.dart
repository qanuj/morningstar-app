import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/match_details.dart';
import '../services/api_service.dart';

class MatchProvider with ChangeNotifier {
  List<MatchListItem> _matches = [];
  Match? _currentMatch;
  MatchRSVPResponse? _matchDetails;
  bool _isLoading = false;
  String _selectedTab = 'upcoming';

  List<MatchListItem> get matches => _matches;
  Match? get currentMatch => _currentMatch;
  MatchRSVPResponse? get matchDetails => _matchDetails;
  bool get isLoading => _isLoading;
  String get selectedTab => _selectedTab;

  List<MatchListItem> get upcomingMatches {
    final now = DateTime.now();
    return _matches.where((match) => match.matchDate.isAfter(now)).toList()
      ..sort((a, b) => a.matchDate.compareTo(b.matchDate));
  }

  List<MatchListItem> get pastMatches {
    final now = DateTime.now();
    return _matches.where((match) => match.matchDate.isBefore(now)).toList()
      ..sort((a, b) => b.matchDate.compareTo(a.matchDate));
  }

  void setSelectedTab(String tab) {
    _selectedTab = tab;
    notifyListeners();
  }

  Future<void> loadMatches() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.get('/rsvp');
      _matches = (response['data'] as List).map((match) => MatchListItem.fromJson(match)).toList();
    } catch (e) {
      print('Error loading matches: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMatchDetails(String matchId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.get('/matches/$matchId');
      final match = Match.fromJson(response);
      _matchDetails = MatchRSVPResponse(
        match: match,
        rsvps: RSVPCounts(
          confirmed: [],
          waitlisted: [],
          declined: [],
          maybe: [],
          pending: [],
        ),
        userRsvp: match.userRsvp,
        counts: RSVPCounts(
          confirmed: [],
          waitlisted: [],
          declined: [],
          maybe: [],
          pending: [],
        ),
      );
    } catch (e) {
      print('Error loading match details: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> submitRSVP(String matchId, String status, String selectedRole, String notes) async {
    try {
      final data = {
        'matchId': matchId,
        'status': status,
        'selectedRole': selectedRole,
        'notes': notes,
      };

      await ApiService.post('/rsvp', data);
      
      // Reload match details after RSVP
      await loadMatchDetails(matchId);
      
      // Also reload matches list to update status
      await loadMatches();
    } catch (e) {
      print('Error submitting RSVP: $e');
      throw e;
    }
  }

  void clearMatchDetails() {
    _matchDetails = null;
    notifyListeners();
  }
}