import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

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
  List<ClubMembership>? get cachedMemberships =>
      _isCacheValid ? _cachedMemberships : null;

  /// Check if the cache is still valid
  bool get _isCacheValid {
    return _cachedMemberships != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheValidDuration;
  }

  Future<void> loadUser({bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (forceRefresh || !ApiService.hasUserData) {
        // Make fresh API call to /api/profile
        final profileResponse = await ApiService.getProfile();
        _user = User.fromApiResponse(profileResponse);
      } else {
        // Use cached data from ApiService
        final cachedUserData = ApiService.cachedUserData!;
        _user = User.fromJson(cachedUserData);
      }

      // Register FCM token after successful user authentication
      if (_user != null) {
        NotificationService.registerTokenAfterAuth(userData: {'id': _user!.id});
      }
    } catch (e) {
      print('Error loading user profile: $e');
      // Try fallback to cached data if API call fails
      if (!forceRefresh && ApiService.hasUserData) {
        try {
          final cachedUserData = ApiService.cachedUserData!;
          _user = User.fromJson(cachedUserData);

          // Register FCM token after successful cached user load
          if (_user != null) {
            NotificationService.registerTokenAfterAuth(
              userData: {'id': _user!.id},
            );
          }
        } catch (cacheError) {
          print('Error loading cached user data: $cacheError');
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      // Filter data to only include allowed fields
      final allowedFields = {
        'name',
        'email',
        'country',
        'city',
        'state',
        'bio',
        'dob',
        'gender',
        'emergencyContact',
      };

      final filteredData = <String, dynamic>{};
      for (final entry in data.entries) {
        if (allowedFields.contains(entry.key)) {
          filteredData[entry.key] = entry.value;
        }
      }

      final response = await ApiService.put('/profile', filteredData);
      _user = User.fromApiResponse(response);
      notifyListeners();

      // Update cached data in ApiService
      if (response['user'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', json.encode(response['user']));
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update profile picture separately
  Future<void> updateProfilePicture(String profilePictureUrl) async {
    try {
      final response = await ApiService.put('/profile/picture', {
        'profilePicture': profilePictureUrl,
      });
      _user = User.fromApiResponse(response);
      notifyListeners();

      // Update cached data in ApiService
      if (response['user'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', json.encode(response['user']));
      }
    } catch (e) {
      rethrow;
    }
  }

  void logout() {
    // Unsubscribe from push notifications before logout
    unsubscribeFromAllNotifications();

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
      List<dynamic> clubsData = [];

      // First try to load from cached data in ApiService
      if (ApiService.hasClubsData) {
        clubsData = ApiService.cachedClubsData!;
      } else {
        // Fallback to API call if no cached data
        final response = await ApiService.get('/my/clubs');

        // Handle different response formats
        final data = response['data'];
        if (data is List) {
          clubsData = data;
        } else if (data is Map) {
          clubsData = [data];
        }
      }

      // Parse memberships
      final memberships = clubsData
          .map((clubData) => ClubMembership.fromJson(clubData))
          .toList();

      // Cache the results
      _cachedMemberships = memberships;
      _cacheTimestamp = DateTime.now();

      // Subscribe to notification topics for each club
      _subscribeToClubNotifications(memberships);

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
  String? getRoleForClubFromMemberships(
    String clubId,
    List<ClubMembership> memberships,
  ) {
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
  bool hasRoleInClubFromMemberships(
    String clubId,
    List<String> allowedRoles,
    List<ClubMembership> memberships,
  ) {
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
  Future<List<ClubMembership>> getMemberships({
    bool forceRefresh = false,
  }) async {
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

  /// Subscribe to push notification topics for user's clubs
  Future<void> _subscribeToClubNotifications(
    List<ClubMembership> memberships,
  ) async {
    try {
      for (final membership in memberships) {
        await NotificationService.subscribeToClubTopics(membership.club.id);
        print(
          '📢 Subscribed to notifications for club: ${membership.club.name}',
        );
      }
    } catch (e) {
      print('❌ Failed to subscribe to club notifications: $e');
    }
  }

  /// Unsubscribe from notification topics (called during logout)
  Future<void> unsubscribeFromAllNotifications() async {
    try {
      if (_cachedMemberships != null) {
        for (final membership in _cachedMemberships!) {
          await NotificationService.unsubscribeFromClubTopics(
            membership.club.id,
          );
          print(
            '📢 Unsubscribed from notifications for club: ${membership.club.name}',
          );
        }
      }
    } catch (e) {
      print('❌ Failed to unsubscribe from notifications: $e');
    }
  }
}
