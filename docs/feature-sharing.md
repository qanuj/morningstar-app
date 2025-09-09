# Duggy App Sharing Feature - Complete Implementation Guide

## Table of Contents
1. [Overview](#overview)
2. [Current App Architecture Analysis](#current-app-architecture-analysis)
3. [Technical Requirements](#technical-requirements)
4. [Implementation Architecture](#implementation-architecture)
5. [Platform Configurations](#platform-configurations)
6. [Core Implementation](#core-implementation)
7. [UI Components](#ui-components)
8. [Integration Points](#integration-points)
9. [Deep Linking Strategy](#deep-linking-strategy)
10. [Testing Strategy](#testing-strategy)
11. [Security Considerations](#security-considerations)
12. [Performance Optimization](#performance-optimization)
13. [Future Enhancements](#future-enhancements)

## Overview

The sharing feature enables Duggy users to receive shared content (text, URLs, images) from other apps and share them to specific club channels, providing a WhatsApp-like sharing experience. This feature includes both incoming share handling and deep linking support for direct navigation to specific clubs or chats.

### Key Features
- **Incoming Share Handling**: Receive text, URLs, and images from other apps
- **Club Selection Interface**: Choose which club/channel to share content to
- **Content Preview**: Preview and edit content before sharing
- **Deep Linking**: Support custom URLs for direct navigation
- **Background Handling**: Queue shares when app is not ready
- **Multi-content Support**: Handle single or multiple items

## Current App Architecture Analysis

### Existing Infrastructure

#### 1. Navigation System
- **Primary Navigation**: Bottom tab navigation with 5 tabs (News, Clubs, Matches, Wallet, Settings)
- **Navigation Helper**: `lib/utils/navigation_helper.dart` handles page navigation
- **Home Screen**: `lib/screens/shared/home.dart` manages tab switching
- **Routing**: Uses standard MaterialApp navigation, no named routes

#### 2. Chat System
- **Club Chat**: `lib/screens/clubs/club_chat.dart` - Full-featured messaging
- **Message Types**: Text, images, audio, files, replies, reactions
- **File Handling**: Already supports image uploads via `file_picker` and media storage
- **Real-time Updates**: Uses providers for state management

#### 3. State Management
- **Provider Pattern**: Uses `provider` package for state management
- **Club Provider**: `lib/providers/club_provider.dart` manages club membership
- **User Provider**: Handles user authentication and data
- **Conversation Provider**: Manages chat conversations and unread counts

#### 4. Data Models
- **Club Model**: `lib/models/club.dart` - Basic club information
- **ClubMembership**: Relationship between user and clubs
- **ClubMessage**: Chat message structure with media support
- **Message Types**: Text, media, audio, with metadata

#### 5. API Integration
- **API Service**: Centralized API handling
- **Auth Service**: User authentication and token management
- **Chat API Service**: Specific chat-related API calls
- **Media Storage Service**: File upload and media handling

### Existing Packages
```yaml
# Relevant existing packages
share_plus: ^11.1.0          # Already included - for outgoing shares
file_picker: ^10.3.2         # File selection and handling
image_picker: ^1.0.4         # Camera and gallery access
cached_network_image: ^3.3.0 # Image caching and display
http: ^1.1.0                 # HTTP requests
provider: ^6.1.1             # State management
shared_preferences: ^2.2.2   # Local storage
flutter_secure_storage: ^9.0.0 # Secure token storage
```

### Missing Components for Sharing
1. **Share Intent Handling**: No platform configuration for receiving shares
2. **Deep Link Support**: No URL scheme handling
3. **Share Target UI**: No interface for selecting clubs
4. **Share Queue Management**: No pending share handling
5. **URL Metadata Extraction**: No link preview generation

## Technical Requirements

### Platform Support
- **Android**: API 21+ (current minSdk)
- **iOS**: iOS 11+ (Flutter requirement)
- **Share Types**: Text, URLs, Images (single/multiple)
- **Background Handling**: App launch from background state

### Performance Requirements
- **Launch Time**: < 2 seconds from share intent
- **UI Responsiveness**: < 300ms for club selection
- **Image Processing**: < 1 second for image preview
- **Memory Usage**: < 50MB additional for share handling

### Dependencies to Add
```yaml
# New packages required
receive_sharing_intent: ^1.8.0  # Primary share intent handler
app_links: ^6.3.2               # Deep linking support  
meta: ^1.12.0                   # Metadata extraction for URLs
mime: ^1.0.6                    # MIME type detection
path: ^1.9.0                    # Path manipulation
```

## Implementation Architecture

### Core Components

```
┌─────────────────────────────────────────┐
│               Share System              │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │        Platform Layer           │   ││
│  │  ┌─────────────┐ ┌─────────────┐│   ││
│  │  │   Android   │ │     iOS     ││   ││
│  │  │ Manifest    │ │ Info.plist  ││   ││
│  │  └─────────────┘ └─────────────┘│   ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │       Intent Handling Layer         ││
│  │  ┌─────────────────────────────────┐││
│  │  │    ShareHandlerService         │││
│  │  │  - Intent parsing              │││
│  │  │  - Content validation          │││
│  │  │  - Queue management            │││
│  │  └─────────────────────────────────┘││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │          UI Layer                   ││
│  │  ┌─────────────────────────────────┐││
│  │  │    ShareTargetScreen           │││
│  │  │  - Club selection              │││
│  │  │  - Content preview             │││
│  │  │  - Send confirmation           │││
│  │  └─────────────────────────────────┘││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │       Integration Layer             ││
│  │  ┌─────────────────────────────────┐││
│  │  │    DeepLinkRouter              │││
│  │  │  - URL parsing                 │││
│  │  │  - Navigation handling         │││
│  │  │  - State restoration           │││
│  │  └─────────────────────────────────┘││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

### Data Flow

```
External App Share → Platform Intent → ShareHandlerService → ShareTargetScreen → Club Chat
       ↓                ↓                     ↓                    ↓              ↓
   [User taps]      [Intent filter]    [Parse content]     [Select club]   [Send message]
   share with       matches and        validate data       preview content   update chat
   Duggy           launches app        queue if needed     confirm send      refresh UI
```

### State Management Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Share Intent   │───▶│  Share Provider │───▶│  Club Provider  │
│  - Text content │    │  - Parse data   │    │  - Club list    │
│  - Image files  │    │  - Validate     │    │  - Selection    │
│  - URLs         │    │  - Queue        │    │  - Permissions  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              ↓
                       ┌─────────────────┐
                       │  Chat Provider  │
                       │  - Send message │
                       │  - Update UI    │
                       │  - Sync state   │
                       └─────────────────┘
```

## Platform Configurations

### Android Configuration

#### AndroidManifest.xml Updates
```xml
<!-- Add to android/app/src/main/AndroidManifest.xml -->

<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    
    <!-- Existing MAIN intent filter -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    
    <!-- Share text intent -->
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="text/plain" />
    </intent-filter>
    
    <!-- Share single image intent -->
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="image/*" />
    </intent-filter>
    
    <!-- Share multiple images intent -->
    <intent-filter>
        <action android:name="android.intent.action.SEND_MULTIPLE" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="image/*" />
    </intent-filter>
    
    <!-- Deep link intent filter -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="duggy" />
    </intent-filter>
    
    <!-- HTTP deep links (optional - for web links) -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" 
              android:host="duggy.app" />
    </intent-filter>
</activity>

<!-- File provider for sharing files -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="com.duggy.app.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

#### File Provider Configuration
Create `android/app/src/main/res/xml/file_paths.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-files-path name="external_files" path="."/>
    <external-cache-path name="external_cache" path="."/>
    <cache-path name="cache" path="."/>
    <files-path name="files" path="."/>
</paths>
```

### iOS Configuration

#### Info.plist Updates
```xml
<!-- Add to ios/Runner/Info.plist -->

<!-- URL Scheme for deep linking -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.duggy.app.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>duggy</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.duggy.app.universal</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>https</string>
        </array>
    </dict>
</array>

<!-- Document types for file sharing -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Images</string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.image</string>
            <string>public.jpeg</string>
            <string>public.png</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Text</string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.plain-text</string>
            <string>public.url</string>
        </array>
    </dict>
</array>

<!-- Enable share extension support -->
<key>NSExtensionActivationSupportsText</key>
<true/>
<key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
<integer>1</integer>
<key>NSExtensionActivationSupportsImageWithMaxCount</key>
<integer>10</integer>

<!-- Associated domains for universal links (optional) -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:duggy.app</string>
</array>
```

## Core Implementation

### 1. Shared Content Model

```dart
// lib/models/shared_content.dart
enum SharedContentType {
  text,
  url,
  image,
  multipleImages,
  unknown
}

class SharedContent {
  final SharedContentType type;
  final String? text;
  final String? subject;
  final List<String>? imagePaths;
  final String? url;
  final Map<String, dynamic>? metadata;
  final DateTime receivedAt;

  SharedContent({
    required this.type,
    this.text,
    this.subject,
    this.imagePaths,
    this.url,
    this.metadata,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory SharedContent.fromText(String text) {
    // Check if text is a URL
    final urlRegex = RegExp(r'https?://[^\s]+');
    final isUrl = urlRegex.hasMatch(text);
    
    return SharedContent(
      type: isUrl ? SharedContentType.url : SharedContentType.text,
      text: text,
      url: isUrl ? text : null,
    );
  }

  factory SharedContent.fromImages(List<String> imagePaths) {
    return SharedContent(
      type: imagePaths.length > 1 
        ? SharedContentType.multipleImages 
        : SharedContentType.image,
      imagePaths: imagePaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'text': text,
      'subject': subject,
      'imagePaths': imagePaths,
      'url': url,
      'metadata': metadata,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }

  factory SharedContent.fromJson(Map<String, dynamic> json) {
    return SharedContent(
      type: SharedContentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SharedContentType.unknown,
      ),
      text: json['text'],
      subject: json['subject'],
      imagePaths: json['imagePaths']?.cast<String>(),
      url: json['url'],
      metadata: json['metadata']?.cast<String, dynamic>(),
      receivedAt: DateTime.parse(json['receivedAt']),
    );
  }

  String get displayText {
    switch (type) {
      case SharedContentType.text:
        return text ?? '';
      case SharedContentType.url:
        return url ?? text ?? '';
      case SharedContentType.image:
        return 'Image';
      case SharedContentType.multipleImages:
        return '${imagePaths?.length ?? 0} Images';
      default:
        return 'Shared content';
    }
  }

  bool get hasImages => imagePaths != null && imagePaths!.isNotEmpty;
  bool get hasText => text != null && text!.isNotEmpty;
  bool get isValid => hasImages || hasText;
}
```

### 2. Share Handler Service

```dart
// lib/services/share_handler_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shared_content.dart';
import '../models/club.dart';

class ShareHandlerService extends ChangeNotifier {
  static final ShareHandlerService _instance = ShareHandlerService._internal();
  factory ShareHandlerService() => _instance;
  ShareHandlerService._internal();

  static const String _pendingShareKey = 'pending_shares';
  static const String _sharePrefsKey = 'share_preferences';

  List<SharedContent> _pendingShares = [];
  bool _isInitialized = false;
  bool _isAppReady = false;

  List<SharedContent> get pendingShares => List.unmodifiable(_pendingShares);
  bool get hasPendingShares => _pendingShares.isNotEmpty;
  bool get isAppReady => _isAppReady;

  /// Initialize the share handler
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load any persisted pending shares
      await _loadPendingShares();

      // Listen for shared media files (images)
      ReceiveSharingIntent.getMediaStream().listen(
        (files) => _handleSharedMedia(files),
        onError: (error) => debugPrint('Share media stream error: $error'),
      );

      // Listen for shared text/URLs
      ReceiveSharingIntent.getTextStream().listen(
        (text) => _handleSharedText(text),
        onError: (error) => debugPrint('Share text stream error: $error'),
      );

      // Check for initial shared content when app starts
      await _checkInitialShares();

      _isInitialized = true;
      debugPrint('✅ ShareHandlerService initialized');
    } catch (e) {
      debugPrint('❌ ShareHandlerService initialization error: $e');
    }
  }

  /// Mark app as ready to handle shares
  void setAppReady(bool ready) {
    _isAppReady = ready;
    notifyListeners();
    
    if (ready && _pendingShares.isNotEmpty) {
      debugPrint('App ready with ${_pendingShares.length} pending shares');
    }
  }

  /// Check for shares that were received before app initialization
  Future<void> _checkInitialShares() async {
    try {
      // Check for initial media
      final initialMedia = await ReceiveSharingIntent.getInitialMedia();
      if (initialMedia.isNotEmpty) {
        await _handleSharedMedia(initialMedia);
      }

      // Check for initial text
      final initialText = await ReceiveSharingIntent.getInitialText();
      if (initialText != null && initialText.isNotEmpty) {
        await _handleSharedText(initialText);
      }
    } catch (e) {
      debugPrint('Error checking initial shares: $e');
    }
  }

  /// Handle shared media files
  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    debugPrint('Received ${files.length} shared media files');
    
    if (files.isEmpty) return;

    try {
      final imagePaths = files
          .where((file) => file.type == SharedMediaType.IMAGE)
          .map((file) => file.path)
          .toList();

      if (imagePaths.isNotEmpty) {
        final sharedContent = SharedContent.fromImages(imagePaths);
        await _addPendingShare(sharedContent);
      }
    } catch (e) {
      debugPrint('Error handling shared media: $e');
    }
  }

  /// Handle shared text/URLs
  Future<void> _handleSharedText(String text) async {
    debugPrint('Received shared text: ${text.substring(0, text.length.clamp(0, 100))}...');
    
    if (text.trim().isEmpty) return;

    try {
      final sharedContent = SharedContent.fromText(text.trim());
      await _addPendingShare(sharedContent);
    } catch (e) {
      debugPrint('Error handling shared text: $e');
    }
  }

  /// Add a share to the pending list
  Future<void> _addPendingShare(SharedContent content) async {
    if (!content.isValid) {
      debugPrint('Invalid shared content, ignoring');
      return;
    }

    _pendingShares.add(content);
    await _savePendingShares();
    notifyListeners();

    debugPrint('Added pending share: ${content.type.name}');
    debugPrint('Total pending shares: ${_pendingShares.length}');
  }

  /// Remove a specific pending share
  Future<void> removePendingShare(SharedContent content) async {
    _pendingShares.removeWhere((share) => 
      share.receivedAt == content.receivedAt && 
      share.type == content.type
    );
    await _savePendingShares();
    notifyListeners();
  }

  /// Clear all pending shares
  Future<void> clearPendingShares() async {
    _pendingShares.clear();
    await _savePendingShares();
    notifyListeners();
  }

  /// Get the most recent pending share
  SharedContent? getLatestPendingShare() {
    if (_pendingShares.isEmpty) return null;
    _pendingShares.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return _pendingShares.first;
  }

  /// Process share to specific club
  Future<bool> processShare(SharedContent content, Club club) async {
    try {
      debugPrint('Processing share to club: ${club.name}');
      
      // Remove from pending list
      await removePendingShare(content);
      
      // Here you would typically send the content to the chat
      // This will be integrated with the existing chat system
      return true;
    } catch (e) {
      debugPrint('Error processing share: $e');
      return false;
    }
  }

  /// Save pending shares to local storage
  Future<void> _savePendingShares() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sharesJson = _pendingShares.map((share) => share.toJson()).toList();
      await prefs.setString(_pendingShareKey, jsonEncode(sharesJson));
    } catch (e) {
      debugPrint('Error saving pending shares: $e');
    }
  }

  /// Load pending shares from local storage
  Future<void> _loadPendingShares() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sharesJsonString = prefs.getString(_pendingShareKey);
      
      if (sharesJsonString != null) {
        final sharesJson = jsonDecode(sharesJsonString) as List;
        _pendingShares = sharesJson
            .map((json) => SharedContent.fromJson(json))
            .where((content) => content.isValid)
            .toList();
            
        debugPrint('Loaded ${_pendingShares.length} pending shares');
      }
    } catch (e) {
      debugPrint('Error loading pending shares: $e');
      _pendingShares.clear();
    }
  }

  /// Clean up old pending shares (older than 24 hours)
  Future<void> cleanupOldShares() async {
    final now = DateTime.now();
    final oneDayAgo = now.subtract(Duration(hours: 24));
    
    _pendingShares.removeWhere((share) => share.receivedAt.isBefore(oneDayAgo));
    await _savePendingShares();
    notifyListeners();
  }

  /// Reset the service (for testing or logout)
  Future<void> reset() async {
    _pendingShares.clear();
    _isAppReady = false;
    await clearPendingShares();
    notifyListeners();
  }
}
```

### 3. Deep Link Router

```dart
// lib/utils/deep_link_router.dart
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../models/club.dart';
import '../services/share_handler_service.dart';
import '../screens/clubs/club_chat.dart';
import '../screens/share/share_target_screen.dart';

class DeepLinkRouter {
  static final DeepLinkRouter _instance = DeepLinkRouter._internal();
  factory DeepLinkRouter() => _instance;
  DeepLinkRouter._internal();

  static const String baseScheme = 'duggy';
  
  late AppLinks _appLinks;
  bool _isInitialized = false;

  /// Initialize deep link handling
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _appLinks = AppLinks();
      
      // Listen for incoming links when app is running
      _appLinks.uriLinkStream.listen(
        (uri) => _handleDeepLink(uri),
        onError: (error) => debugPrint('Deep link error: $error'),
      );

      _isInitialized = true;
      debugPrint('✅ DeepLinkRouter initialized');
    } catch (e) {
      debugPrint('❌ DeepLinkRouter initialization error: $e');
    }
  }

  /// Check for initial deep link when app starts
  Future<void> handleInitialLink(BuildContext context) async {
    try {
      final uri = await _appLinks.getInitialAppLink();
      if (uri != null) {
        await _handleDeepLink(uri, context);
      }
    } catch (e) {
      debugPrint('Error handling initial deep link: $e');
    }
  }

  /// Handle incoming deep link
  Future<void> _handleDeepLink(Uri uri, [BuildContext? context]) async {
    debugPrint('Handling deep link: $uri');

    if (context == null) {
      // If no context, we need to wait or queue the link
      debugPrint('No context available for deep link, queueing...');
      return;
    }

    try {
      switch (uri.pathSegments.first) {
        case 'share':
          await _handleShareLink(uri, context);
          break;
        case 'chat':
          await _handleChatLink(uri, context);
          break;
        case 'club':
          await _handleClubLink(uri, context);
          break;
        default:
          debugPrint('Unknown deep link path: ${uri.path}');
      }
    } catch (e) {
      debugPrint('Error processing deep link: $e');
    }
  }

  /// Handle share-specific deep links
  /// Format: duggy://share?text=hello&clubId=123
  /// Format: duggy://share/club/123?text=hello
  Future<void> _handleShareLink(Uri uri, BuildContext context) async {
    final queryParams = uri.queryParameters;
    final pathSegments = uri.pathSegments;

    String? text = queryParams['text'];
    String? clubId = queryParams['clubId'];
    
    // Check for club ID in path
    if (pathSegments.length >= 3 && pathSegments[1] == 'club') {
      clubId = pathSegments[2];
    }

    if (text != null && text.isNotEmpty) {
      // Create shared content from deep link
      final sharedContent = SharedContent.fromText(text);
      
      if (clubId != null) {
        // Direct share to specific club
        await _shareToClub(sharedContent, clubId, context);
      } else {
        // Show club selection
        await _showShareTarget(sharedContent, context);
      }
    }
  }

  /// Handle chat deep links
  /// Format: duggy://chat/clubId
  Future<void> _handleChatLink(Uri uri, BuildContext context) async {
    if (uri.pathSegments.length < 2) return;
    
    final clubId = uri.pathSegments[1];
    await _navigateToChat(clubId, context);
  }

  /// Handle general club deep links
  /// Format: duggy://club/clubId
  Future<void> _handleClubLink(Uri uri, BuildContext context) async {
    if (uri.pathSegments.length < 2) return;
    
    final clubId = uri.pathSegments[1];
    // Navigate to club details or default to chat
    await _navigateToChat(clubId, context);
  }

  /// Navigate to specific club chat
  Future<void> _navigateToChat(String clubId, BuildContext context) async {
    try {
      // You would typically get the club from ClubProvider here
      // For now, we'll create a placeholder navigation
      debugPrint('Navigating to chat for club: $clubId');
      
      // TODO: Integrate with ClubProvider to get actual club
      // final club = Provider.of<ClubProvider>(context, listen: false)
      //     .clubs.firstWhere((c) => c.club.id == clubId);
      
      // Navigator.of(context).push(
      //   MaterialPageRoute(
      //     builder: (context) => ClubChatScreen(club: club.club),
      //   ),
      // );
    } catch (e) {
      debugPrint('Error navigating to chat: $e');
    }
  }

  /// Share content directly to a specific club
  Future<void> _shareToClub(
    SharedContent content, 
    String clubId, 
    BuildContext context
  ) async {
    try {
      debugPrint('Direct share to club: $clubId');
      // TODO: Implement direct sharing to club
      // This would integrate with the chat system to send the message
    } catch (e) {
      debugPrint('Error sharing to club: $e');
    }
  }

  /// Show share target selection screen
  Future<void> _showShareTarget(
    SharedContent content, 
    BuildContext context
  ) async {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ShareTargetScreen(sharedContent: content),
        ),
      );
    } catch (e) {
      debugPrint('Error showing share target: $e');
    }
  }

  /// Generate deep link URLs
  static String generateShareUrl({
    String? text,
    String? clubId,
  }) {
    final uri = Uri(
      scheme: baseScheme,
      host: 'share',
      queryParameters: {
        if (text != null) 'text': text,
        if (clubId != null) 'clubId': clubId,
      },
    );
    return uri.toString();
  }

  static String generateChatUrl(String clubId) {
    return '$baseScheme://chat/$clubId';
  }

  static String generateClubUrl(String clubId) {
    return '$baseScheme://club/$clubId';
  }
}
```

## UI Components

### 1. Share Target Screen

```dart
// lib/screens/share/share_target_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shared_content.dart';
import '../../models/club.dart';
import '../../providers/club_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/share_preview.dart';
import '../../widgets/club_selector.dart';
import '../../services/share_handler_service.dart';

class ShareTargetScreen extends StatefulWidget {
  final SharedContent sharedContent;

  const ShareTargetScreen({
    Key? key,
    required this.sharedContent,
  }) : super(key: key);

  @override
  State<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends State<ShareTargetScreen> {
  Club? _selectedClub;
  bool _isSending = false;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill message with shared text if available
    if (widget.sharedContent.hasText) {
      _messageController.text = widget.sharedContent.text ?? '';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share to Club'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _selectedClub != null && !_isSending 
              ? _sendToClub 
              : null,
            child: _isSending
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Send',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Content Preview Section
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: SharePreview(
              sharedContent: widget.sharedContent,
              messageController: _messageController,
            ),
          ),
          
          Divider(height: 1),
          
          // Club Selection Section
          Expanded(
            child: Consumer<ClubProvider>(
              builder: (context, clubProvider, child) {
                if (clubProvider.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }

                if (clubProvider.clubs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No clubs available',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Join a club to start sharing content',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ClubSelector(
                  clubs: clubProvider.clubs.map((cm) => cm.club).toList(),
                  selectedClub: _selectedClub,
                  onClubSelected: (club) {
                    setState(() {
                      _selectedClub = club;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToClub() async {
    if (_selectedClub == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Update shared content with modified message
      final modifiedContent = SharedContent(
        type: widget.sharedContent.type,
        text: _messageController.text.trim(),
        imagePaths: widget.sharedContent.imagePaths,
        url: widget.sharedContent.url,
        subject: widget.sharedContent.subject,
        metadata: widget.sharedContent.metadata,
      );

      // Process the share
      final success = await ShareHandlerService().processShare(
        modifiedContent, 
        _selectedClub!
      );

      if (success) {
        // Navigate to the chat screen
        await _navigateToChat();
      } else {
        _showErrorDialog('Failed to share content. Please try again.');
      }
    } catch (e) {
      debugPrint('Error sending share: $e');
      _showErrorDialog('An error occurred while sharing. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _navigateToChat() async {
    if (_selectedClub == null) return;

    // Navigate to club chat and close this screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ClubChatScreen(club: _selectedClub!),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

### 2. Share Preview Widget

```dart
// lib/widgets/share_preview.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/shared_content.dart';

class SharePreview extends StatelessWidget {
  final SharedContent sharedContent;
  final TextEditingController? messageController;
  final bool showTextField;
  final int maxLines;

  const SharePreview({
    Key? key,
    required this.sharedContent,
    this.messageController,
    this.showTextField = true,
    this.maxLines = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sharing Content',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 12),
          
          // Content preview based on type
          _buildContentPreview(context),
          
          if (showTextField) ...[
            SizedBox(height: 16),
            _buildMessageTextField(context),
          ],
        ],
      ),
    );
  }

  Widget _buildContentPreview(BuildContext context) {
    switch (sharedContent.type) {
      case SharedContentType.image:
        return _buildImagePreview(context, single: true);
      
      case SharedContentType.multipleImages:
        return _buildImagePreview(context, single: false);
      
      case SharedContentType.url:
        return _buildUrlPreview(context);
      
      case SharedContentType.text:
        return _buildTextPreview(context);
      
      default:
        return _buildUnknownPreview(context);
    }
  }

  Widget _buildImagePreview(BuildContext context, {required bool single}) {
    final images = sharedContent.imagePaths ?? [];
    if (images.isEmpty) return SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(maxHeight: 200),
      child: single 
        ? _buildSingleImagePreview(images.first)
        : _buildMultipleImagePreview(images),
    );
  }

  Widget _buildSingleImagePreview(String imagePath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            color: Colors.grey[300],
            child: Icon(
              Icons.broken_image,
              size: 48,
              color: Colors.grey[600],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMultipleImagePreview(List<String> imagePaths) {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          return Container(
            width: 100,
            margin: EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(imagePaths[index]),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.broken_image,
                      size: 32,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUrlPreview(BuildContext context) {
    final url = sharedContent.url ?? sharedContent.text ?? '';
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Link',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  url,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview(BuildContext context) {
    final text = sharedContent.text ?? '';
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.text_fields,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Text',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownPreview(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            size: 24,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unknown content type',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTextField(BuildContext context) {
    return TextField(
      controller: messageController,
      maxLines: maxLines,
      minLines: 1,
      decoration: InputDecoration(
        hintText: sharedContent.hasImages 
          ? 'Add a message with your images...'
          : 'Edit your message...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
    );
  }
}
```

### 3. Club Selector Widget

```dart
// lib/widgets/club_selector.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/club.dart';

class ClubSelector extends StatefulWidget {
  final List<Club> clubs;
  final Club? selectedClub;
  final Function(Club) onClubSelected;
  final bool showSearch;
  final bool showRecentSection;

  const ClubSelector({
    Key? key,
    required this.clubs,
    required this.onClubSelected,
    this.selectedClub,
    this.showSearch = true,
    this.showRecentSection = true,
  }) : super(key: key);

  @override
  State<ClubSelector> createState() => _ClubSelectorState();
}

class _ClubSelectorState extends State<ClubSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<Club> _filteredClubs = [];
  List<Club> _recentClubs = [];

  @override
  void initState() {
    super.initState();
    _filteredClubs = widget.clubs;
    _loadRecentClubs();
    _searchController.addListener(_filterClubs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadRecentClubs() {
    // TODO: Load from shared preferences or user activity
    // For now, just take first 3 clubs
    _recentClubs = widget.clubs.take(3).toList();
  }

  void _filterClubs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredClubs = widget.clubs;
      } else {
        _filteredClubs = widget.clubs
            .where((club) => club.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showSearch) ...[
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
        
        Expanded(
          child: ListView(
            children: [
              // Recent clubs section
              if (widget.showRecentSection && 
                  _recentClubs.isNotEmpty && 
                  _searchController.text.isEmpty) ...[
                _buildSectionHeader('Recent'),
                ..._recentClubs.map((club) => _buildClubTile(club, isRecent: true)),
                SizedBox(height: 16),
              ],
              
              // All clubs section
              _buildSectionHeader(_searchController.text.isEmpty ? 'All Clubs' : 'Search Results'),
              ..._filteredClubs.map((club) => _buildClubTile(club)),
              
              if (_filteredClubs.isEmpty) ...[
                SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Theme.of(context).disabledColor,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No clubs found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Try adjusting your search',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildClubTile(Club club, {bool isRecent = false}) {
    final isSelected = widget.selectedClub?.id == club.id;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isSelected 
          ? Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            )
          : null,
      ),
      child: ListTile(
        leading: _buildClubAvatar(club),
        title: Text(
          club.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (club.description != null && club.description!.isNotEmpty) ...[
              Text(
                club.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (club.membersCount != null) ...[
              Text(
                '${club.membersCount} members',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ],
          ],
        ),
        trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : isRecent
              ? Icon(
                  Icons.history,
                  color: Theme.of(context).disabledColor,
                  size: 20,
                )
              : null,
        onTap: () => widget.onClubSelected(club),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      ),
    );
  }

  Widget _buildClubAvatar(Club club) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: club.logo != null && club.logo!.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: club.logo!,
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            placeholder: (context, url) => CircularProgressIndicator(strokeWidth: 2),
            errorWidget: (context, url, error) => _buildInitialsAvatar(club.name),
          )
        : _buildInitialsAvatar(club.name),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    final initials = name.split(' ')
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join('');
    
    return Text(
      initials,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
```

## Integration Points

### 1. Main.dart Updates

```dart
// lib/main.dart - Updates needed
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'providers/club_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/conversation_provider.dart';
import 'screens/auth/splash.dart';
import 'services/notification_service.dart';
import 'services/share_handler_service.dart'; // NEW
import 'utils/deep_link_router.dart'; // NEW
import 'utils/theme.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase with options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Initialize Push Notifications
    await NotificationService.initialize();
    print('✅ NotificationService initialized successfully');
    
    // NEW: Initialize Share Handler
    await ShareHandlerService().initialize();
    print('✅ ShareHandlerService initialized successfully');
    
    // NEW: Initialize Deep Link Router
    await DeepLinkRouter().initialize();
    print('✅ DeepLinkRouter initialized successfully');
    
  } catch (e) {
    print('❌ Failed to initialize services: $e');
  }

  // Log current configuration
  AppConfig.logConfig();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider();
    _themeProvider.init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ClubProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider.value(value: _themeProvider),
        // NEW: Add ShareHandlerService as provider
        ChangeNotifierProvider.value(value: ShareHandlerService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Duggy',
            theme: AppTheme.duggyTheme,
            darkTheme: AppTheme.duggyDarkTheme,
            themeMode: themeProvider.materialThemeMode,
            home: AppLifecycleWrapper(), // NEW: Wrap with lifecycle manager
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// NEW: App lifecycle wrapper to handle share intents and deep links
class AppLifecycleWrapper extends StatefulWidget {
  @override
  _AppLifecycleWrapperState createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Handle initial deep link after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialLink();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, mark share handler as ready
      ShareHandlerService().setAppReady(true);
    }
  }

  Future<void> _handleInitialLink() async {
    await DeepLinkRouter().handleInitialLink(context);
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen();
  }
}
```

### 2. Club Chat Integration

```dart
// Updates needed for lib/screens/clubs/club_chat.dart
// Add method to handle shared content

class ClubChatScreenState extends State<ClubChatScreen>
    with TickerProviderStateMixin {
  
  // ... existing code ...

  @override
  void initState() {
    super.initState();
    // ... existing initialization ...
    
    // NEW: Check for pending shares for this club
    _checkPendingShares();
  }

  // NEW: Check if there are pending shares for this club
  void _checkPendingShares() {
    final shareHandler = ShareHandlerService();
    final pendingShares = shareHandler.pendingShares;
    
    if (pendingShares.isNotEmpty) {
      // Show option to send pending shares
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPendingSharesDialog(pendingShares);
      });
    }
  }

  // NEW: Show dialog for pending shares
  void _showPendingSharesDialog(List<SharedContent> pendingShares) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Send Shared Content?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: pendingShares.length,
                  itemBuilder: (context, index) => Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        children: [
                          SharePreview(
                            sharedContent: pendingShares[index],
                            showTextField: false,
                            maxLines: 2,
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _dismissShare(pendingShares[index]),
                                child: Text('Dismiss'),
                              ),
                              ElevatedButton(
                                onPressed: () => _sendSharedContent(pendingShares[index]),
                                child: Text('Send'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Send shared content to this chat
  Future<void> _sendSharedContent(SharedContent sharedContent) async {
    try {
      // Close the dialog first
      Navigator.of(context).pop();

      // Send based on content type
      if (sharedContent.hasImages) {
        // Send images
        for (final imagePath in sharedContent.imagePaths!) {
          await _sendImageMessage(File(imagePath));
        }
      }

      if (sharedContent.hasText) {
        // Send text message
        await _sendTextMessage(sharedContent.text!);
      }

      // Remove from pending shares
      await ShareHandlerService().removePendingShare(sharedContent);

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shared content sent successfully'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      debugPrint('Error sending shared content: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send shared content'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: Dismiss a pending share
  Future<void> _dismissShare(SharedContent sharedContent) async {
    await ShareHandlerService().removePendingShare(sharedContent);
    Navigator.of(context).pop();
  }

  // NEW: Send text message (integrate with existing send logic)
  Future<void> _sendTextMessage(String text) async {
    // Use existing message sending logic
    _messageController.text = text;
    await _sendMessage(); // Call existing send message method
    _messageController.clear();
  }

  // NEW: Send image message (integrate with existing image logic)
  Future<void> _sendImageMessage(File imageFile) async {
    // Use existing image sending logic
    // This would integrate with your existing image upload and send system
    try {
      // Add to pending uploads or directly send
      // Implementation depends on your existing image handling
      debugPrint('Sending shared image: ${imageFile.path}');
      
      // TODO: Integrate with existing image sending logic
      // await _handleImageUpload(imageFile);
      
    } catch (e) {
      debugPrint('Error sending shared image: $e');
      rethrow;
    }
  }

  // ... rest of existing code ...
}
```

### 3. Navigation Helper Updates

```dart
// lib/utils/navigation_helper.dart - Add deep link support

import 'package:flutter/material.dart';
import '../screens/clubs/club_chat.dart';
import '../screens/share/share_target_screen.dart';
import '../models/club.dart';
import '../models/shared_content.dart';

/// Navigation helper to handle consistent navigation across the app
class NavigationHelper {
  // ... existing code ...

  /// NEW: Navigate to share target screen
  static void navigateToShareTarget(
    BuildContext context,
    SharedContent sharedContent, {
    bool replacement = false,
  }) {
    final route = MaterialPageRoute(
      builder: (context) => ShareTargetScreen(sharedContent: sharedContent),
    );

    if (replacement) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  /// NEW: Navigate directly to club chat
  static void navigateToClubChat(
    BuildContext context,
    Club club, {
    bool replacement = false,
  }) {
    final route = MaterialPageRoute(
      builder: (context) => ClubChatScreen(club: club),
    );

    if (replacement) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  /// NEW: Handle deep link navigation
  static Future<bool> handleDeepLink(
    BuildContext context,
    String deepLink,
  ) async {
    try {
      final uri = Uri.parse(deepLink);
      
      switch (uri.pathSegments.first) {
        case 'share':
          // Handle share deep link
          final text = uri.queryParameters['text'];
          if (text != null) {
            final sharedContent = SharedContent.fromText(text);
            navigateToShareTarget(context, sharedContent);
            return true;
          }
          break;
          
        case 'chat':
          // Handle chat deep link
          if (uri.pathSegments.length >= 2) {
            final clubId = uri.pathSegments[1];
            // TODO: Get club from provider and navigate
            // final club = await _getClubById(clubId);
            // if (club != null) {
            //   navigateToClubChat(context, club);
            //   return true;
            // }
          }
          break;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error handling deep link: $e');
      return false;
    }
  }

  // ... existing code ...
}
```

## Deep Linking Strategy

### URL Scheme Design

**Base Scheme**: `duggy://`

#### Share URLs
- **Basic Share**: `duggy://share?text=hello%20world`
- **Share to Club**: `duggy://share?text=hello&clubId=123`
- **Share with Path**: `duggy://share/club/123?text=hello`

#### Chat URLs  
- **Open Chat**: `duggy://chat/123`
- **Open Chat with Message**: `duggy://chat/123?message=hello`

#### Universal Links (Optional)
- **Web Share**: `https://duggy.app/share?text=hello&club=123`
- **Web Chat**: `https://duggy.app/chat/123`

### Deep Link Flow

```
1. External App → Share Intent → Duggy App Launch
2. App Receives Deep Link → Parse Parameters
3. Check Authentication State
   ├─ Not Logged In → Queue Link → Show Login
   └─ Logged In → Process Link Immediately
4. Process Link Type
   ├─ Share → Show Share Target Screen
   ├─ Chat → Navigate to Club Chat
   └─ Unknown → Show Error/Home
5. Complete Action → Navigate to Target
```

### Implementation Considerations

#### State Management
- **Pending Links**: Queue deep links when app not ready
- **Authentication**: Handle links after login completion
- **Navigation Stack**: Preserve existing navigation when processing links
- **Error Handling**: Graceful failure for invalid/expired links

#### Security
- **URL Validation**: Validate all incoming URLs
- **Permission Checks**: Verify user access to clubs
- **Data Sanitization**: Clean shared content before processing
- **Rate Limiting**: Prevent abuse of share functionality

## Testing Strategy

### Unit Tests

```dart
// test/services/share_handler_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:duggy/services/share_handler_service.dart';
import 'package:duggy/models/shared_content.dart';

void main() {
  group('ShareHandlerService', () {
    late ShareHandlerService shareHandler;

    setUp(() {
      shareHandler = ShareHandlerService();
    });

    test('should initialize correctly', () async {
      await shareHandler.initialize();
      expect(shareHandler.isInitialized, isTrue);
    });

    test('should handle text content correctly', () {
      final content = SharedContent.fromText('Hello World');
      expect(content.type, SharedContentType.text);
      expect(content.text, 'Hello World');
      expect(content.isValid, isTrue);
    });

    test('should detect URLs in text', () {
      final content = SharedContent.fromText('Check this out: https://example.com');
      expect(content.type, SharedContentType.url);
      expect(content.url, contains('https://example.com'));
    });

    test('should handle image paths correctly', () {
      final paths = ['/path/to/image1.jpg', '/path/to/image2.png'];
      final content = SharedContent.fromImages(paths);
      expect(content.type, SharedContentType.multipleImages);
      expect(content.imagePaths, paths);
      expect(content.hasImages, isTrue);
    });

    test('should manage pending shares', () async {
      final content = SharedContent.fromText('Test message');
      await shareHandler.addPendingShare(content);
      
      expect(shareHandler.hasPendingShares, isTrue);
      expect(shareHandler.pendingShares.length, 1);
      
      await shareHandler.removePendingShare(content);
      expect(shareHandler.hasPendingShares, isFalse);
    });
  });
}
```

### Widget Tests

```dart
// test/widgets/share_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duggy/widgets/share_preview.dart';
import 'package:duggy/models/shared_content.dart';

void main() {
  group('SharePreview', () {
    testWidgets('should display text content', (WidgetTester tester) async {
      final content = SharedContent.fromText('Test message');
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharePreview(sharedContent: content),
          ),
        ),
      );

      expect(find.text('Test message'), findsOneWidget);
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
    });

    testWidgets('should display URL content', (WidgetTester tester) async {
      final content = SharedContent.fromText('https://example.com');
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharePreview(sharedContent: content),
          ),
        ),
      );

      expect(find.text('https://example.com'), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('should show message text field when enabled', (WidgetTester tester) async {
      final content = SharedContent.fromText('Test');
      final controller = TextEditingController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharePreview(
              sharedContent: content,
              messageController: controller,
              showTextField: true,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      
      await tester.enterText(find.byType(TextField), 'Modified message');
      expect(controller.text, 'Modified message');
    });
  });
}
```

### Integration Tests

```dart
// integration_test/share_flow_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:duggy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Share Flow Integration', () {
    testWidgets('should handle incoming text share', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Simulate incoming share intent
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'plugins.flutter.io/receive_sharing_intent',
        StandardMethodCodec().encodeMethodCall(
          MethodCall('getInitialText', 'Shared text message'),
        ),
        (data) {},
      );

      await tester.pumpAndSettle();

      // Verify share target screen appears
      expect(find.text('Share to Club'), findsOneWidget);
      expect(find.text('Shared text message'), findsOneWidget);
    });

    testWidgets('should complete share to club flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // TODO: Complete integration test for full share flow
      // This would require setting up test data and mocking API calls
    });
  });
}
```

### Manual Testing Checklist

#### Android Testing
- [ ] Share text from Chrome to Duggy
- [ ] Share image from Gallery to Duggy  
- [ ] Share multiple images to Duggy
- [ ] Test deep links in browser
- [ ] Test app launch performance
- [ ] Test background/foreground transitions

#### iOS Testing
- [ ] Share text from Safari to Duggy
- [ ] Share photo from Photos app to Duggy
- [ ] Share URL from any app to Duggy
- [ ] Test universal links
- [ ] Test app handoff scenarios

#### Functional Testing
- [ ] Club selection works correctly
- [ ] Content preview displays properly
- [ ] Message editing functions
- [ ] Send operation completes
- [ ] Chat integration works
- [ ] Error states handle gracefully

## Security Considerations

### Input Validation
- **URL Sanitization**: Validate and sanitize all incoming URLs
- **Image Validation**: Check file types and sizes before processing
- **Text Filtering**: Remove potentially harmful content from text
- **Path Validation**: Ensure image paths are safe and accessible

### Permission Management
- **Club Access**: Verify user has permission to post in selected club
- **File Access**: Validate app has permission to access shared files
- **Network Access**: Ensure secure communication for metadata fetching
- **Storage Access**: Safely handle temporary file storage

### Data Protection
- **Temporary Storage**: Secure handling of shared content in temp storage
- **Memory Management**: Clear sensitive data from memory when done
- **Logging**: Avoid logging sensitive shared content
- **Encryption**: Encrypt stored pending shares if containing sensitive data

### Attack Prevention
- **Rate Limiting**: Prevent spam sharing attempts
- **Content Validation**: Block potentially malicious content
- **Deep Link Validation**: Prevent malicious deep link exploitation
- **File Type Restrictions**: Only allow safe file types for sharing

## Performance Optimization

### Memory Management
- **Image Optimization**: Compress and resize large shared images
- **Cache Management**: Efficient caching of club data and images  
- **Background Processing**: Handle file processing in background threads
- **Memory Cleanup**: Proper disposal of controllers and streams

### Storage Optimization
- **Temporary Files**: Clean up temporary shared files after processing
- **Cache Sizing**: Limit size of pending shares cache
- **File Compression**: Compress shared images before upload
- **Storage Monitoring**: Monitor and manage app storage usage

### Network Optimization
- **Metadata Fetching**: Efficient URL metadata extraction
- **Image Upload**: Optimized image upload with progress tracking
- **API Batching**: Batch related API calls when possible
- **Offline Handling**: Queue operations when network unavailable

### UI Performance
- **Lazy Loading**: Load club lists and images on demand
- **Smooth Animations**: Optimize transitions and animations
- **Responsive UI**: Maintain 60fps during share operations
- **Background Loading**: Load heavy operations in background

## Future Enhancements

### Phase 2 Features
- **Rich Link Previews**: Automatic URL metadata extraction and preview
- **Share Extension**: iOS share extension for better system integration
- **Batch Sharing**: Share to multiple clubs simultaneously
- **Share Templates**: Predefined templates for common shares
- **Share History**: Track and replay previous shares

### Phase 3 Features  
- **Smart Club Suggestion**: AI-powered club recommendations for sharing
- **Content Filtering**: Advanced content filtering and moderation
- **Share Analytics**: Track sharing patterns and engagement
- **Cross-Platform Sync**: Sync pending shares across devices
- **Advanced Deep Linking**: Support for complex deep link scenarios

### Advanced Integrations
- **Shortcuts Integration**: iOS Shortcuts and Android App Shortcuts
- **Widget Support**: Home screen widgets for quick sharing
- **Voice Commands**: Voice-activated sharing with Siri/Google Assistant
- **AR/VR Support**: Future support for AR/VR content sharing
- **AI Enhancement**: Smart content categorization and auto-tagging

### Enterprise Features
- **Bulk Operations**: Admin tools for managing club sharing policies
- **Compliance Tools**: Content compliance and audit trails
- **Advanced Security**: Enterprise-grade security features
- **Integration APIs**: APIs for third-party integrations
- **Custom Workflows**: Configurable sharing workflows for organizations

---

This comprehensive documentation provides a complete roadmap for implementing the sharing feature in Duggy. The modular approach ensures maintainable code while the phased implementation allows for iterative development and testing.