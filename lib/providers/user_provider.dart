import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  
  // Session cache for club memberships
  List<ClubMembership>? _cachedMemberships;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  User? get user => _user;
  bool get isLoading => _isLoading;
  
  /// Get cached memberships if available and not expired
  List<ClubMembership>? get cachedMemberships => _isCacheValid ? _cachedMemberships : null;
  
  /// Check if the cache is still valid
  bool get _isCacheValid {
    return _cachedMemberships != null && 
           _cacheTimestamp != null && 
           DateTime.now().difference(_cacheTimestamp!) < _cacheValidDuration;
  }

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await AuthService.getCurrentUser();
      
      // Handle different response formats
      if (userData.containsKey('data') && userData['data'] != null) {
        _user = User.fromJson(userData['data']);
      } else if (userData.containsKey('user') && userData['user'] != null) {
        _user = User.fromJson(userData['user']);
      } else {
        // Assume the response itself is the user data
        _user = User.fromJson(userData);
      }
    } catch (e) {
      print('Error loading user: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await ApiService.put('/profile', data);
      _user = User.fromJson(response);
      notifyListeners();
    } catch (e) {
      throw e;
    }
  }

  void logout() {
    _user = null;
    _clearCache();
    notifyListeners();
  }
  
  /// Clear the membership cache
  void _clearCache() {
    _cachedMemberships = null;
    _cacheTimestamp = null;
  }
  
  /// Manually clear the membership cache (useful for forced refresh)
  void clearMembershipCache() {
    _clearCache();
    notifyListeners();
  }
  
  /// Load and cache club memberships
  Future<List<ClubMembership>> _loadAndCacheMemberships() async {
    try {
      final response = await ApiService.get('/my/clubs');
      List<dynamic> clubsData = [];
      
      // Handle different response formats
      final data = response['data'];
      if (data is List) {
        clubsData = data;
      } else if (data is Map) {
        clubsData = [data];
      }
      
      // Parse memberships
      final memberships = clubsData.map((clubData) => ClubMembership.fromJson(clubData)).toList();
      
      // Cache the results
      _cachedMemberships = memberships;
      _cacheTimestamp = DateTime.now();
      
      return memberships;
    } catch (e) {
      print('Error loading memberships: $e');
      rethrow;
    }
  }

  /// Get the user's role for a specific club
  /// Returns the role string (e.g., 'OWNER', 'ADMIN', 'MEMBER') or null if not found
  /// 
  /// This method uses session caching to improve performance
  Future<String?> getRoleForClub(String clubId) async {
    try {
      // Use cached data if available and valid
      List<ClubMembership> memberships;
      if (_isCacheValid) {
        memberships = _cachedMemberships!;
      } else {
        memberships = await _loadAndCacheMemberships();
      }
      
      // Find the specific club membership
      try {
        final membership = memberships.firstWhere(
          (membership) => membership.club.id == clubId,
        );
        return membership.role;
      } catch (e) {
        return null; // Club not found or user not a member
      }
    } catch (e) {
      print('Error getting role for club $clubId: $e');
      return null;
    }
  }

  /// Get the user's role for a specific club from a provided list of memberships
  /// This is more efficient when you already have the club memberships loaded
  String? getRoleForClubFromMemberships(String clubId, List<ClubMembership> memberships) {
    try {
      final membership = memberships.firstWhere(
        (membership) => membership.club.id == clubId,
      );
      return membership.role;
    } catch (e) {
      // firstWhere throws StateError if not found
      return null;
    }
  }

  /// Check if the user has a specific role in a club
  /// Useful for permission checking (e.g., canPin = hasRoleInClub(clubId, ['OWNER', 'ADMIN']))
  /// This method uses session caching to improve performance
  Future<bool> hasRoleInClub(String clubId, List<String> allowedRoles) async {
    final userRole = await getRoleForClub(clubId);
    return userRole != null && allowedRoles.contains(userRole.toUpperCase());
  }

  /// Check if the user has a specific role in a club from provided memberships
  /// More efficient when memberships are already loaded
  bool hasRoleInClubFromMemberships(String clubId, List<String> allowedRoles, List<ClubMembership> memberships) {
    final userRole = getRoleForClubFromMemberships(clubId, memberships);
    return userRole != null && allowedRoles.contains(userRole.toUpperCase());
  }

  /// Check if the user is the owner of a specific club
  Future<bool> isOwnerOfClub(String clubId) async {
    return await hasRoleInClub(clubId, ['OWNER']);
  }

  /// Check if the user is an admin or owner of a specific club
  Future<bool> isAdminOrOwnerOfClub(String clubId) async {
    return await hasRoleInClub(clubId, ['OWNER', 'ADMIN']);
  }

  /// Check if the user can perform administrative actions in a club
  Future<bool> canAdministerClub(String clubId) async {
    return await hasRoleInClub(clubId, ['OWNER', 'ADMIN', 'CAPTAIN']);
  }

  /// Get all cached memberships, loading them if necessary
  /// This is useful when you need access to all club memberships
  Future<List<ClubMembership>> getMemberships({bool forceRefresh = false}) async {
    if (forceRefresh || !_isCacheValid) {
      return await _loadAndCacheMemberships();
    }
    return _cachedMemberships!;
  }

  /// Check if cache exists and is valid
  bool get hasCachedMemberships => _isCacheValid;

  /// Get cache age in minutes (useful for debugging or UI display)
  int? get cacheAgeInMinutes {
    if (_cacheTimestamp == null) return null;
    return DateTime.now().difference(_cacheTimestamp!).inMinutes;
  }

  /// Preload memberships into cache (useful for app initialization)
  Future<void> preloadMemberships() async {
    if (!_isCacheValid) {
      await _loadAndCacheMemberships();
    }
  }
}