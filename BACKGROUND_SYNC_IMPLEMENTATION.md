# Background Sync Service Implementation (Updated)

## Overview
The Background Sync Service provides real-time message updates for the Duggy Flutter app using intelligent timestamp-based synchronization. This implementation includes enhanced support for message reactions, RSVP updates, poll votes, and other interactive content updates.

## Key Improvements

### 🕒 **Timestamp-Based Sync (updatedAt)**
- Uses `updatedAt` timestamps instead of just `createdAt` for more accurate syncing
- Captures message changes from reactions, RSVP updates, poll votes, pins, and edits
- Reduces unnecessary data transfer by fetching only truly updated content

## Key Features

### 🔄 **Smart Incremental Sync**
- Syncs every 30 seconds when app is backgrounded
- Syncs every 10 seconds when app is active  
- Uses `lastUpdatedAt` timestamp for precise change detection
- Automatically handles message reactions, RSVP changes, and poll vote updates

### 📊 **Enhanced Message Type Support**
- **Reactions**: Real-time emoji reaction updates with automatic message refresh
- **RSVP Updates**: Match participation changes trigger message sync
- **Poll Votes**: Vote changes update related messages immediately  
- **Pinned Messages**: Pin/unpin actions sync across devices
- **Message Edits**: Content changes properly update timestamps

### 🏗️ **Database Schema Improvements**
- Added `updatedAt` column to Message table with automatic updates
- Added `pollId` and `matchId` foreign key references for efficient querying
- Proper indexes for optimized sync performance
- Backward compatible with existing message structure

## Implementation Details

### Enhanced Backend API
```typescript
// Updated API endpoint supports lastUpdatedAt parameter
GET /api/conversations/:clubId/messages?lastUpdatedAt=2024-01-01T10:00:00Z

// Automatic message timestamp updates on:
// - Reaction changes: message.updatedAt = now when reactions added/removed
// - RSVP updates: message.updatedAt = now when match RSVPs change
// - Poll votes: message.updatedAt = now when poll votes change
// - Pin actions: message.updatedAt = now when messages pinned/unpinned
```

### Flutter Service Architecture
```dart
// Enhanced sync with timestamp tracking
await BackgroundSyncService.initialize();
BackgroundSyncService.setClubProvider(clubProvider);

// Automatic updatedAt tracking per club
_lastUpdatedAtTimes[clubId] = latestUpdatedAt;
```

### Enhanced Chat Screen Integration
```dart
// Improved callback system handles all message types
BackgroundSyncService.setClubMessageCallback(clubId, (data) {
  // Handles: reactions, RSVPs, votes, pins, edits
  _handleRealtimeMessage(data);
});

// Enhanced message processing with updatedAt support
void _handleRealtimeMessage(Map<String, dynamic> data) {
  final isUpdate = data['isUpdate'] == true;
  final messageId = data['messageId'] as String?;
  
  if (isUpdate && messageId != null) {
    // Handle real-time updates for reactions, RSVPs, votes
    _updateSpecificMessage(messageId, data);
  } else {
    // Handle new messages
    _loadMessages(forceSync: true);
  }
}
```

### App Lifecycle Management
```dart
// In main app state
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.resumed:
      BackgroundSyncService.setAppActiveState(true);
      BackgroundSyncService.triggerSync(); // Immediate sync
      break;
      
    case AppLifecycleState.paused:
      BackgroundSyncService.setAppActiveState(false);
      break;
      
    case AppLifecycleState.detached:
      BackgroundSyncService.stop();
      break;
  }
}
```

## Benefits Over Push Notifications

### 1. **Reliability**
- No dependency on Firebase Cloud Messaging
- Works even when push notifications fail
- Consistent behavior across all devices and platforms

### 2. **Message Type Support**
- Better handling of complex message types (RSVP, votes, matches)
- Proper support for message reactions and pins
- Consistent updates for all message interactions

### 3. **Network Efficiency**
- Uses incremental sync to fetch only new messages
- Configurable sync intervals based on app state
- Minimizes unnecessary network requests

### 4. **User Experience**
- More reliable real-time updates
- No notification permission requirements
- Seamless message synchronization

## Configuration Options

### Sync Intervals
```dart
static const Duration _syncInterval = Duration(seconds: 30); // Background
static const Duration _activeSyncInterval = Duration(seconds: 10); // Active
```

### Message Types Handled
- `club_message` - Regular chat messages
- `match` - Match details and updates
- `practice` - Practice session information
- `poll` - Poll questions and votes
- `rsvp_update` - RSVP status changes
- Message reactions, pins, and edits

## Migration Notes

### For Existing Code
- Background sync works alongside existing push notifications
- No breaking changes to existing callback systems
- Can gradually replace push notification dependencies

### Future Improvements
- WebSocket support for even faster updates
- Smart batching of multiple message updates
- Offline queue for failed sync attempts
- Analytics for sync performance monitoring

## Usage Examples

### Manual Sync Trigger
```dart
// Trigger immediate sync (useful for pull-to-refresh)
await BackgroundSyncService.triggerSync();
```

### Debug Information
```dart
// Get current sync status
final status = BackgroundSyncService.getSyncStatus();
print('Sync status: $status');
```

### Service Management
```dart
// Stop service (e.g., on logout)
BackgroundSyncService.stop();

// Restart service (e.g., on login)
await BackgroundSyncService.initialize();
```

This implementation ensures reliable real-time message updates without the complexity and potential failures of push notification systems, while maintaining backward compatibility with existing code.