# iOS Project Setup & Configuration

## Overview
Complete guide for setting up the Xcode project for the Duggy Cricket Club Management app with proper dependencies, configuration, and project structure.

## 🎯 Setup Tasks

### Project Creation
- [ ] Create new iOS project in Xcode 14+
- [ ] Configure project settings and deployment target
- [ ] Set up proper folder structure
- [ ] Configure build schemes and configurations
- [ ] Set up code signing and provisioning profiles
- [ ] Configure App Store Connect app record

### Dependencies & Package Manager
- [ ] Add Swift Package Manager dependencies
- [ ] Configure CocoaPods (if needed)
- [ ] Set up Firebase SDK and configuration
- [ ] Add third-party libraries for networking and UI
- [ ] Configure build phases and scripts
- [ ] Set up linting and code quality tools

### Configuration Files
- [ ] Create environment-specific configuration files
- [ ] Set up Info.plist with required permissions
- [ ] Configure URL schemes and deep linking
- [ ] Set up push notification entitlements
- [ ] Configure privacy usage descriptions
- [ ] Set up background modes and capabilities

## Project Configuration

### Basic Project Settings
```swift
// Project Name: Duggy
// Bundle Identifier: com.duggy.cricketclub
// Deployment Target: iOS 15.0
// Swift Version: 5.9
// Xcode Version: 14.0+
```

### Build Configurations
```swift
// Debug Configuration
DEBUG = 1
API_BASE_URL = "https://api-staging.duggy.com"
ENABLE_LOGGING = true

// Release Configuration
DEBUG = 0
API_BASE_URL = "https://api.duggy.com"
ENABLE_LOGGING = false
```

## Dependencies

### Swift Package Manager Dependencies
```swift
// In Package.swift or Xcode Package Manager
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.18.0"),
    .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
    .package(url: "https://github.com/onevcat/Kingfisher", from: "7.9.1"),
    .package(url: "https://github.com/stripe/stripe-ios", from: "23.18.0"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
    .package(url: "https://github.com/SwiftKickMobile/SwiftMessages", from: "9.0.6"),
    .package(url: "https://github.com/realm/SwiftLint", from: "0.54.0")
]
```

### Firebase Configuration
```swift
// GoogleService-Info.plist setup
// 1. Download from Firebase Console
// 2. Add to Xcode project
// 3. Ensure it's included in app bundle
// 4. Configure for different environments if needed

// Firebase modules needed:
// - Firebase/Core
// - Firebase/Messaging
// - Firebase/Analytics
// - Firebase/Crashlytics
```

## Project Structure

### Folder Organization
```
Duggy/
├── App/
│   ├── DuggyApp.swift
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Core/
│   ├── Extensions/
│   ├── Utilities/
│   ├── Constants/
│   └── Helpers/
├── Data/
│   ├── Models/
│   ├── Services/
│   ├── Repositories/
│   └── Storage/
├── Domain/
│   ├── Entities/
│   ├── UseCases/
│   └── Protocols/
├── Presentation/
│   ├── Views/
│   ├── ViewModels/
│   ├── Components/
│   └── Navigation/
├── Resources/
│   ├── Assets/
│   ├── Fonts/
│   ├── Colors/
│   └── Localizable/
└── Configuration/
    ├── Environment/
    ├── Firebase/
    └── Info.plist
```

## Info.plist Configuration

### Required Permissions
```xml
<!-- Camera and Photo Library -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos for profiles and content</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images</string>

<!-- Location Services -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to find nearby venues and clubs</string>

<!-- Contacts -->
<key>NSContactsUsageDescription</key>
<string>This app needs contacts access to invite members to your club</string>

<!-- Push Notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>

<!-- URL Schemes -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.duggy.cricketclub</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>duggy</string>
        </array>
    </dict>
</array>

<!-- App Transport Security -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.duggy.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSTemporaryExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
        </dict>
    </dict>
</dict>
```

## App Delegate Configuration

### AppDelegate.swift
```swift
import UIKit
import Firebase
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure Firebase
        FirebaseApp.configure()

        // Configure push notifications
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Request notification permissions
        requestNotificationPermissions()

        // Configure appearance
        configureAppAppearance()

        return true
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    private func configureAppAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "PrimaryBlue")
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        NotificationCenter.default.post(name: .notificationTapped, object: response.notification.request.content.userInfo)
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "FCMToken")
            // Send token to server
            NotificationCenter.default.post(name: .fcmTokenRefreshed, object: token)
        }
    }
}

// MARK: - Remote Notifications
extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}
```

## Environment Configuration

### Environment.swift
```swift
import Foundation

enum Environment {
    case development
    case staging
    case production

    static var current: Environment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }

    var apiBaseURL: String {
        switch self {
        case .development:
            return "https://api-dev.duggy.com"
        case .staging:
            return "https://api-staging.duggy.com"
        case .production:
            return "https://api.duggy.com"
        }
    }

    var enableLogging: Bool {
        return self != .production
    }

    var firebaseConfigFile: String {
        switch self {
        case .development, .staging:
            return "GoogleService-Info-Dev"
        case .production:
            return "GoogleService-Info"
        }
    }
}
```

## Build Scripts

### SwiftLint Build Phase
```bash
# Add as Build Phase > New Run Script Phase
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

### Firebase Crashlytics
```bash
# Add after SwiftLint
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

## SwiftLint Configuration

### .swiftlint.yml
```yaml
disabled_rules:
  - trailing_whitespace
  - line_length
  - identifier_name

opt_in_rules:
  - empty_count
  - empty_string
  - force_unwrapping
  - implicitly_unwrapped_optional
  - overridden_super_call
  - private_outlet
  - redundant_nil_coalescing

included:
  - Duggy

excluded:
  - Carthage
  - Pods
  - Build
  - DuggyTests

line_length:
  warning: 120
  error: 200

function_body_length:
  warning: 50
  error: 100

type_body_length:
  warning: 200
  error: 350

file_length:
  warning: 500
  error: 1200

cyclomatic_complexity:
  warning: 10
  error: 20
```

## Build Configuration Tasks

### Xcode Project Settings
- [ ] Set minimum deployment target to iOS 15.0
- [ ] Configure code signing for development and distribution
- [ ] Set up automatic provisioning profiles
- [ ] Configure bundle identifier and version numbers
- [ ] Set up build configurations for different environments
- [ ] Configure compiler flags and optimization settings

### Capabilities & Entitlements
- [ ] Enable Push Notifications capability
- [ ] Add Background Modes for remote notifications
- [ ] Configure App Groups if needed for extensions
- [ ] Set up Associated Domains for universal links
- [ ] Configure HealthKit if fitness features are added
- [ ] Add payment processing capability for in-app purchases

### Asset Catalog Setup
- [ ] Create app icons for all required sizes
- [ ] Add launch screen assets and configuration
- [ ] Set up color sets for dynamic colors
- [ ] Create image sets for different screen densities
- [ ] Configure dark mode assets if supported
- [ ] Add vector assets for SF Symbols usage

### Localization Setup
- [ ] Configure base localization settings
- [ ] Create Localizable.strings files
- [ ] Set up InfoPlist.strings for localized metadata
- [ ] Configure region-specific settings
- [ ] Test localization with different languages
- [ ] Set up pseudo-localization for testing

This completes the foundational project setup. All subsequent development should build upon this configuration.