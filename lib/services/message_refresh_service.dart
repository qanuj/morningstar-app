// lib/services/message_refresh_service.dart

import 'dart:async';

class MessageRefreshService {
  static final MessageRefreshService _instance =
      MessageRefreshService._internal();
  factory MessageRefreshService() => _instance;
  MessageRefreshService._internal();

  final StreamController<String> _refreshController =
      StreamController<String>.broadcast();

  /// Stream to listen for club message refresh events
  Stream<String> get refreshStream => _refreshController.stream;

  /// Trigger a refresh for a specific club's messages
  void triggerRefresh(String clubId) {
    if (!_refreshController.isClosed) {
      _refreshController.add(clubId);
      print('🔄 MessageRefreshService: Triggered refresh for club $clubId');
    }
  }

  /// Trigger refresh for multiple clubs
  void triggerRefreshForClubs(List<String> clubIds) {
    for (final clubId in clubIds) {
      triggerRefresh(clubId);
    }
  }

  /// Dispose the service
  void dispose() {
    if (!_refreshController.isClosed) {
      _refreshController.close();
    }
  }
}
