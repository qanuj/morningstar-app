// Test file for background sync with updatedAt functionality
// Run this in your Flutter app console to test the new functionality

import 'package:duggy/services/background_sync_service.dart';
import 'package:duggy/services/chat_api_service.dart';

void testBackgroundSyncWithUpdatedAt() async {
  print('🧪 Testing Background Sync with updatedAt support');

  // Test 1: Initialize service
  try {
    await BackgroundSyncService.initialize();
    print('✅ Background sync service initialized');
  } catch (e) {
    print('❌ Failed to initialize background sync: $e');
    return;
  }

  // Test 2: Verify sync status
  final status = BackgroundSyncService.getSyncStatus();
  print('📊 Sync Status: $status');

  // Test 3: Test manual sync trigger
  try {
    await BackgroundSyncService.triggerSync();
    print('✅ Manual sync completed');
  } catch (e) {
    print('❌ Manual sync failed: $e');
  }

  // Test 4: Test ChatApiService with lastUpdatedAt
  try {
    final testClubId = 'your-test-club-id';
    final testUpdatedAt = DateTime.now()
        .subtract(Duration(hours: 1))
        .toIso8601String();

    final response = await ChatApiService.getMessagesEfficient(
      testClubId,
      lastUpdatedAt: testUpdatedAt,
      forceFullSync: false,
      limit: 10,
    );

    if (response != null) {
      print('✅ ChatApiService working with lastUpdatedAt parameter');
      print('📊 Response syncInfo: ${response['data']?['syncInfo']}');
    } else {
      print('⚠️ ChatApiService returned null response');
    }
  } catch (e) {
    print('❌ ChatApiService test failed: $e');
  }

  print('🏁 Background sync test completed');
}

// Usage: Call this function in your Flutter app
// testBackgroundSyncWithUpdatedAt();
