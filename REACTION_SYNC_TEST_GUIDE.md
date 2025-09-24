# Testing Reaction Sync

## Quick Test Steps

1. **Open 3 devices** with the same club chat
2. **Add debugging** by calling this in your Flutter console:
   ```dart
   import 'package:duggy/services/background_sync_service.dart';
   BackgroundSyncService.debugReactionSync();
   ```

3. **Add a reaction** on Device 1 to any message
4. **Watch the logs** on all devices for these debug messages:
   - `😀 Processing message with reactions: [messageId]`
   - `📞 Triggering reaction callback for club: [clubId]`
   - `🔄 Handling message update for: [messageId]`
   - `🔄 Triggering focused refresh for reaction update...`

## Expected Flow

When you add a reaction on Device 1:

1. **Backend** updates the message's `updatedAt` timestamp
2. **Device 2 & 3** background sync detects the updated message
3. **Background sync** identifies it as a reaction update
4. **Chat screen** receives the update callback
5. **UI refreshes** showing the new reaction

## Debug Output to Look For

```
😀 Processing message with reactions: msg_123
😀 Reaction count: 2
😀 Reactions: 👍:1, ❤️:1
📞 Triggering reaction callback for club: club_456
🔄 Handling message update for: msg_123
📝 Update type: reaction for message: msg_123
🔄 Triggering focused refresh for reaction update...
```

## Troubleshooting

If reactions don't sync:

1. **Check if callbacks are registered**:
   ```dart
   BackgroundSyncService.debugReactionSync();
   // Look for activeCallbacks in the output
   ```

2. **Verify sync is running**:
   ```dart
   final status = BackgroundSyncService.getSyncStatus();
   print('Sync status: $status');
   ```

3. **Force manual sync**:
   ```dart
   await BackgroundSyncService.triggerSync();
   ```

4. **Check server response**: Look for `lastUpdatedAt` in API responses

## Quick Fix Commands

If sync isn't working, try these in Flutter console:

```dart
// Restart background sync
BackgroundSyncService.stop();
await BackgroundSyncService.initialize();

// Force immediate sync
await BackgroundSyncService.triggerSync();

// Check status
BackgroundSyncService.debugReactionSync();
```