// Test file for background sync with updatedAt functionality
// Run this in your Flutter app console to test the new functionality

import 'dart:async';
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

// Test reaction sync debugging
void testReactionSync() {
  print('\n=== REACTION SYNC DEBUG TEST ===');
  BackgroundSyncService.debugReactionSync();

  // Get sync status
  final status = BackgroundSyncService.getSyncStatus();
  print('\n🔄 Current sync status: $status');

  // Trigger manual sync
  BackgroundSyncService.triggerSync()
      .then((_) {
        print('✅ Manual sync triggered');
      })
      .catchError((error) {
        print('❌ Manual sync failed: $error');
      });

  print('\n📱 Now add a reaction on another device and watch for updates...');
  print('================================\n');
}

// Test reaction sync with specific club
void testReactionSyncForClub(String clubId) {
  print('\n=== REACTION SYNC TEST FOR CLUB: $clubId ===');
  BackgroundSyncService.debugReactionSync();

  // Force sync for specific club
  BackgroundSyncService.triggerSync().then((_) {
    print('✅ Sync triggered for club: $clubId');
    print('� Add a reaction now and watch console for updates...');
  });

  // Set up a timer to check for updates
  Timer.periodic(Duration(seconds: 2), (timer) {
    print('⏰ Checking for reaction updates... (${timer.tick})');
    if (timer.tick >= 30) {
      // Stop after 1 minute
      timer.cancel();
      print('⏹️ Stopped monitoring reaction updates');
    }
  });

  print('================================\n');
}

// Usage: Call these functions in your Flutter app
// testBackgroundSyncWithUpdatedAt();
// testReactionSync();
