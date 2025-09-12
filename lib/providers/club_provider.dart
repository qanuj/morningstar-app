import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      List<dynamic> clubsData = [];
      
      // First try to load from cached data in ApiService
      if (ApiService.hasClubsData) {
        clubsData = ApiService.cachedClubsData!;
      } else {
        // Fallback to API call if no cached data
        final Map<String, dynamic> response = await ApiService.get('/my/clubs');
        
        // Handle different response formats
        final data = response['data'];
        if (data is List) {
          clubsData = data;
        } else if (data is Map) {
          clubsData = [data]; // Single club wrapped in data
        }
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

  Future<void> refreshClubs() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Force refresh from API by calling the API directly
      final Map<String, dynamic> response = await ApiService.get('/my/clubs');
      
      // Handle different response formats
      final data = response['data'];
      List<dynamic> clubsData = [];
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
      
      // Update current club if exists
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

      // Update the cache with fresh data
      if (clubsData.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('clubsData', json.encode(clubsData));
      }
    } catch (e) {
      print('Error refreshing clubs: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update latest message for a specific club from push notification data
  void updateClubLatestMessage({
    required String clubId,
    required String messageId,
    required String messageContent,
    required String senderName,
    required String senderId,
    required DateTime createdAt,
    bool isRead = false, // New messages from notifications are unread by default
  }) {
    final clubIndex = _clubs.indexWhere((membership) => membership.club.id == clubId);
    if (clubIndex != -1) {
      final currentMembership = _clubs[clubIndex];
      
      // Create new latest message with read status
      final newLatestMessage = LatestMessage(
        id: messageId,
        content: MessageContent(body: messageContent, type: 'text'),
        createdAt: createdAt,
        senderName: senderName,
        senderId: senderId,
        isRead: isRead,
      );

      // Update club with new latest message
      final updatedClub = currentMembership.club.copyWith(
        latestMessage: newLatestMessage,
      );

      final updatedMembership = currentMembership.copyWith(
        club: updatedClub,
      );

      _clubs[clubIndex] = updatedMembership;
      notifyListeners();

      print('✅ Updated latest message for club $clubId (isRead: $isRead)');
    } else {
      print('❌ Club $clubId not found in provider');
    }
  }

  /// Mark a club as read (clear unread indicator)
  void markClubAsRead(String clubId) {
    final clubIndex = _clubs.indexWhere((membership) => membership.club.id == clubId);
    if (clubIndex != -1) {
      final currentMembership = _clubs[clubIndex];
      
      // Only update if there's a latest message that's unread
      if (currentMembership.hasUnreadMessage && currentMembership.club.latestMessage != null) {
        final currentLatestMessage = currentMembership.club.latestMessage!;
        
        // Update the latest message to mark it as read
        final updatedLatestMessage = currentLatestMessage.copyWith(isRead: true);
        
        final updatedClub = currentMembership.club.copyWith(
          latestMessage: updatedLatestMessage,
        );

        final updatedMembership = currentMembership.copyWith(
          club: updatedClub,
        );

        _clubs[clubIndex] = updatedMembership;
        notifyListeners();

        print('✅ Marked club $clubId as read');
      }
    }
  }

  /// Get unread clubs count
  int get unreadClubsCount {
    return _clubs.where((membership) => membership.hasUnreadMessage).length;
  }
}