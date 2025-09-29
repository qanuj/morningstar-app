# Splash Screen Implementation

## Overview
Implementation guide for the app launch screen with brand animation, initialization tasks, and seamless transition to authentication or main app.

## 🎯 Splash Screen Tasks

### UI Implementation
- [ ] Create splash screen layout with logo animation
- [ ] Implement brand colors and theming
- [ ] Add smooth fade-in and scale animations
- [ ] Create loading indicator for initialization
- [ ] Implement progress tracking for long operations
- [ ] Add error handling for initialization failures

### App Initialization
- [ ] Set up Firebase SDK initialization
- [ ] Configure push notification registration
- [ ] Load user authentication state
- [ ] Initialize local database and caching
- [ ] Check for app updates and compatibility
- [ ] Perform network connectivity checks

### Navigation Logic
- [ ] Implement authentication state routing
- [ ] Add deep link handling during splash
- [ ] Create smooth transitions to next screen
- [ ] Handle first-time user onboarding flow
- [ ] Implement maintenance mode detection
- [ ] Add offline mode initialization

## UI Implementation

### Splash View
```swift
struct SplashView: View {
    @StateObject private var viewModel = SplashViewModel()
    @EnvironmentObject var authenticationStore: AuthenticationStore
    @EnvironmentObject var navigationStore: NavigationStore

    var body: some View {
        ZStack {
            // Background
            Color.primaryBlue
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo Animation
                LogoView(animationPhase: viewModel.animationPhase)

                // App Name
                Text("Duggy")
                    .font(.headline1)
                    .foregroundColor(.white)
                    .opacity(viewModel.showAppName ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 0.6).delay(1.0),
                        value: viewModel.showAppName
                    )

                // Tagline
                Text("Cricket Club Management")
                    .font(.bodyLarge)
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(viewModel.showTagline ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 0.6).delay(1.5),
                        value: viewModel.showTagline
                    )

                Spacer()

                // Loading Section
                VStack(spacing: 16) {
                    if viewModel.showLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }

                    Text(viewModel.loadingMessage)
                        .font(.bodyMedium)
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(viewModel.showLoading ? 1 : 0)
                        .animation(.easeInOut, value: viewModel.loadingMessage)
                }
                .frame(height: 60)

                Spacer()
            }
        }
        .onAppear {
            viewModel.startInitialization()
        }
        .onChange(of: viewModel.initializationComplete) { isComplete in
            if isComplete {
                handleInitializationComplete()
            }
        }
        .alert("Initialization Error", isPresented: $viewModel.showError) {
            Button("Retry") {
                viewModel.startInitialization()
            }
            Button("Exit") {
                exit(0)
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func handleInitializationComplete() {
        withAnimation(.easeInOut(duration: 0.5)) {
            if authenticationStore.isAuthenticated {
                navigationStore.selectedTab = .home
            } else {
                // Navigate to login
                navigationStore.presentedFullScreen = .authentication
            }
        }
    }
}
```

### Logo Animation Component
```swift
struct LogoView: View {
    let animationPhase: SplashAnimationPhase
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 0.3

    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 140, height: 140)
                .scaleEffect(animationPhase == .initial ? 0.8 : 1.2)
                .opacity(animationPhase == .initial ? 0.3 : 0.1)

            // Cricket Ball Segments
            ForEach(0..<6) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 4, height: 20)
                    .offset(y: -45)
                    .rotationEffect(.degrees(Double(index) * 60 + rotationAngle))
                    .opacity(animationPhase.rawValue >= SplashAnimationPhase.logoSpin.rawValue ? 1 : 0)
            }

            // Center Logo
            Image("DuggyLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .scaleEffect(scale)
        }
        .onAppear {
            startLogoAnimation()
        }
        .onChange(of: animationPhase) { phase in
            updateAnimationForPhase(phase)
        }
    }

    private func startLogoAnimation() {
        // Initial scale animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            scale = 1.0
        }

        // Start rotation after scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }

    private func updateAnimationForPhase(_ phase: SplashAnimationPhase) {
        switch phase {
        case .logoSpin:
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.1
            }
        case .complete:
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.0
            }
        default:
            break
        }
    }
}
```

## ViewModel Implementation

### Splash ViewModel
```swift
@MainActor
class SplashViewModel: ObservableObject {
    @Published var animationPhase: SplashAnimationPhase = .initial
    @Published var showAppName = false
    @Published var showTagline = false
    @Published var showLoading = false
    @Published var loadingMessage = ""
    @Published var initializationComplete = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let initializationService: AppInitializationService
    private var cancellables = Set<AnyCancellable>()

    init(initializationService: AppInitializationService = DependencyContainer.shared.appInitializationService) {
        self.initializationService = initializationService
    }

    func startInitialization() {
        showError = false
        initializationComplete = false

        startAnimationSequence()
        performInitializationTasks()
    }

    private func startAnimationSequence() {
        // Phase 1: Logo appears and spins
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.animationPhase = .logoSpin
        }

        // Phase 2: Show app name
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showAppName = true
        }

        // Phase 3: Show tagline
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showTagline = true
        }

        // Phase 4: Show loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showLoading = true
        }
    }

    private func performInitializationTasks() {
        initializationService.initialize()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleInitializationError(error)
                    }
                },
                receiveValue: { [weak self] status in
                    self?.handleInitializationStatus(status)
                }
            )
            .store(in: &cancellables)
    }

    private func handleInitializationStatus(_ status: InitializationStatus) {
        loadingMessage = status.message

        if status.isComplete {
            animationPhase = .complete

            // Delay completion to allow animation to finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.initializationComplete = true
            }
        }
    }

    private func handleInitializationError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        showLoading = false
    }
}

enum SplashAnimationPhase: Int, CaseIterable {
    case initial = 0
    case logoSpin = 1
    case complete = 2
}
```

## App Initialization Service

### Initialization Service
```swift
protocol AppInitializationServiceProtocol {
    func initialize() -> AnyPublisher<InitializationStatus, Error>
}

class AppInitializationService: AppInitializationServiceProtocol {
    private let authenticationStore: AuthenticationStore
    private let firebaseService: FirebaseService
    private let databaseService: DatabaseService
    private let configurationService: ConfigurationService

    init(
        authenticationStore: AuthenticationStore,
        firebaseService: FirebaseService,
        databaseService: DatabaseService,
        configurationService: ConfigurationService
    ) {
        self.authenticationStore = authenticationStore
        self.firebaseService = firebaseService
        self.databaseService = databaseService
        self.configurationService = configurationService
    }

    func initialize() -> AnyPublisher<InitializationStatus, Error> {
        let initializationSteps: [AnyPublisher<InitializationStatus, Error>] = [
            initializeFirebase(),
            initializeDatabase(),
            loadConfiguration(),
            checkAuthentication(),
            registerForNotifications(),
            checkAppVersion()
        ]

        return Publishers.Sequence(sequence: initializationSteps)
            .flatMap { $0 }
            .scan(InitializationStatus(step: 0, totalSteps: initializationSteps.count, message: "Starting...")) { current, next in
                return InitializationStatus(
                    step: next.step,
                    totalSteps: initializationSteps.count,
                    message: next.message,
                    isComplete: next.step == initializationSteps.count
                )
            }
            .eraseToAnyPublisher()
    }

    private func initializeFirebase() -> AnyPublisher<InitializationStatus, Error> {
        Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.firebaseService.configure()
                    DispatchQueue.main.async {
                        promise(.success(InitializationStatus(step: 1, totalSteps: 6, message: "Initializing services...")))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func initializeDatabase() -> AnyPublisher<InitializationStatus, Error> {
        databaseService.initialize()
            .map { InitializationStatus(step: 2, totalSteps: 6, message: "Setting up local storage...") }
            .eraseToAnyPublisher()
    }

    private func loadConfiguration() -> AnyPublisher<InitializationStatus, Error> {
        configurationService.loadConfiguration()
            .map { InitializationStatus(step: 3, totalSteps: 6, message: "Loading configuration...") }
            .eraseToAnyPublisher()
    }

    private func checkAuthentication() -> AnyPublisher<InitializationStatus, Error> {
        authenticationStore.checkAuthenticationState()
            .map { InitializationStatus(step: 4, totalSteps: 6, message: "Checking authentication...") }
            .eraseToAnyPublisher()
    }

    private func registerForNotifications() -> AnyPublisher<InitializationStatus, Error> {
        Future { promise in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    DispatchQueue.main.async {
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                        promise(.success(InitializationStatus(step: 5, totalSteps: 6, message: "Setting up notifications...")))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func checkAppVersion() -> AnyPublisher<InitializationStatus, Error> {
        configurationService.checkAppVersion()
            .map { InitializationStatus(step: 6, totalSteps: 6, message: "Finalizing...", isComplete: true) }
            .eraseToAnyPublisher()
    }
}

struct InitializationStatus {
    let step: Int
    let totalSteps: Int
    let message: String
    let isComplete: Bool

    init(step: Int, totalSteps: Int, message: String, isComplete: Bool = false) {
        self.step = step
        self.totalSteps = totalSteps
        self.message = message
        self.isComplete = isComplete
    }

    var progress: Double {
        return Double(step) / Double(totalSteps)
    }
}
```

## Launch Screen Configuration

### Launch Screen Storyboard
```xml
<!-- LaunchScreen.storyboard -->
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="32700.99.1234" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="22684"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <!--View Controller-->
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView clipsSubviews="YES" userInteractionEnabled="NO" contentMode="scaleAspectFit" horizontalHuggingPriority="251" verticalHuggingPriority="251" image="DuggyLogo" translatesAutoresizingMaskIntoConstraints="NO" id="tWc-Dq-87w">
                                <rect key="frame" x="146.66666666666666" y="376" width="100" height="100"/>
                                <constraints>
                                    <constraint firstAttribute="width" constant="100" id="Sg8-gJ-6tY"/>
                                    <constraint firstAttribute="height" constant="100" id="rjF-7s-8hg"/>
                                </constraints>
                            </imageView>
                        </subviews>
                        <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                        <color key="backgroundColor" red="0.0" green="0.24705882352941178" blue="0.60784313725490191" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                        <constraints>
                            <constraint firstItem="tWc-Dq-87w" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="2Zg-7h-Qnh"/>
                            <constraint firstItem="tWc-Dq-87w" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="QVf-uO-ggK"/>
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="DuggyLogo" width="512" height="512"/>
    </resources>
</document>
```

## Error Handling

### Initialization Errors
```swift
enum InitializationError: LocalizedError {
    case firebaseConfigurationFailed
    case databaseInitializationFailed
    case configurationLoadFailed
    case authenticationCheckFailed
    case notificationRegistrationFailed
    case versionCheckFailed
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .firebaseConfigurationFailed:
            return "Failed to initialize Firebase services"
        case .databaseInitializationFailed:
            return "Failed to initialize local database"
        case .configurationLoadFailed:
            return "Failed to load app configuration"
        case .authenticationCheckFailed:
            return "Failed to check authentication state"
        case .notificationRegistrationFailed:
            return "Failed to register for notifications"
        case .versionCheckFailed:
            return "Failed to check app version"
        case .networkUnavailable:
            return "Network connection is not available"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection and try again"
        case .firebaseConfigurationFailed, .databaseInitializationFailed:
            return "Please restart the app. If the problem persists, contact support"
        default:
            return "Please try again. If the problem persists, contact support"
        }
    }
}
```

## Performance Optimization

### Lazy Loading
```swift
// Initialize only critical services during splash
private func initializeCriticalServices() {
    // Essential services only
    firebaseService.configure()
    authenticationStore.checkAuthenticationState()
}

private func initializeSecondaryServices() {
    // Non-critical services after main app loads
    DispatchQueue.global(qos: .background).async {
        self.analyticsService.initialize()
        self.crashlyticsService.initialize()
        self.featureFlagService.initialize()
    }
}
```

### Memory Management
```swift
// Ensure proper cleanup
deinit {
    cancellables.removeAll()
    NotificationCenter.default.removeObserver(self)
}
```

## Splash Screen Implementation Tasks

### Core Implementation
- [ ] Create SplashView with brand animations
- [ ] Implement SplashViewModel with state management
- [ ] Build LogoView with rotation and scale animations
- [ ] Create smooth transition animations
- [ ] Add loading progress indicators
- [ ] Implement error handling and retry logic

### Initialization Tasks
- [ ] Set up AppInitializationService
- [ ] Configure Firebase initialization
- [ ] Initialize local database and storage
- [ ] Check authentication state
- [ ] Register for push notifications
- [ ] Load app configuration

### Animation Tasks
- [ ] Create logo scale and rotation animations
- [ ] Implement text fade-in animations
- [ ] Add progress indicator animations
- [ ] Create smooth transition to next screen
- [ ] Optimize animation performance
- [ ] Test animations on different devices

### Navigation Tasks
- [ ] Implement authentication state routing
- [ ] Handle deep link processing during splash
- [ ] Create smooth transitions to login/main app
- [ ] Add first-time user onboarding flow
- [ ] Handle maintenance mode scenarios
- [ ] Implement offline mode detection

### Testing Tasks
- [ ] Test initialization success scenarios
- [ ] Test initialization failure scenarios
- [ ] Test network connectivity issues
- [ ] Test authentication state transitions
- [ ] Test animation performance
- [ ] Test on different device sizes

This splash screen provides a professional first impression while efficiently initializing the app in the background.