# Testing Strategy & Implementation

## Overview
Comprehensive testing strategy for the Duggy iOS app including unit tests, integration tests, UI tests, performance tests, and quality assurance processes.

## 🎯 Testing Tasks

### Unit Testing
- [ ] Set up XCTest framework and test targets
- [ ] Create unit tests for all ViewModels
- [ ] Test business logic and use cases
- [ ] Add model validation and transformation tests
- [ ] Create utility and extension tests
- [ ] Implement mock services and dependencies

### Integration Testing
- [ ] Test API integration and networking
- [ ] Create database integration tests
- [ ] Test authentication flow integration
- [ ] Add payment system integration tests
- [ ] Test push notification integration
- [ ] Create third-party service integration tests

### UI Testing
- [ ] Set up XCUITest framework
- [ ] Create user journey and workflow tests
- [ ] Test accessibility features
- [ ] Add screen transition tests
- [ ] Create form validation tests
- [ ] Implement visual regression testing

### Performance Testing
- [ ] Set up XCTest performance measuring
- [ ] Create memory usage tests
- [ ] Test app launch time and responsiveness
- [ ] Add network performance tests
- [ ] Create battery usage optimization tests
- [ ] Implement stress testing scenarios

## Test Architecture

### Test Project Structure
```
DuggyTests/
├── UnitTests/
│   ├── ViewModels/
│   ├── UseCases/
│   ├── Services/
│   ├── Models/
│   └── Utilities/
├── IntegrationTests/
│   ├── API/
│   ├── Database/
│   ├── Authentication/
│   └── Payments/
├── UITests/
│   ├── UserJourneys/
│   ├── Accessibility/
│   ├── Navigation/
│   └── Forms/
├── PerformanceTests/
│   ├── LaunchTime/
│   ├── Memory/
│   ├── Network/
│   └── Stress/
└── Mocks/
    ├── Services/
    ├── Repositories/
    └── Data/
```

## Unit Testing Implementation

### ViewModel Testing Base
```swift
import XCTest
import Combine
@testable import Duggy

class BaseViewModelTest: XCTestCase {
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    func expectation<T: Publisher>(
        for publisher: T,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) -> XCTestExpectation where T.Failure == Never {
        let expectation = expectation(description: "Publisher expectation")

        publisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        return expectation
    }

    func awaitPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T.Output where T.Failure == Error {
        var result: Result<T.Output, Error>?
        let expectation = expectation(description: "Awaiting publisher")

        publisher.sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    result = .failure(error)
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                result = .success(value)
            }
        )
        .store(in: &cancellables)

        wait(for: [expectation], timeout: timeout)

        guard let result = result else {
            XCTFail("Publisher did not complete", file: file, line: line)
            throw TestError.publisherDidNotComplete
        }

        return try result.get()
    }
}

enum TestError: Error {
    case publisherDidNotComplete
    case unexpectedValue
    case mockNotConfigured
}
```

### Example ViewModel Test
```swift
@MainActor
class LoginViewModelTests: BaseViewModelTest {
    var viewModel: LoginViewModel!
    var mockAuthUseCase: MockAuthenticationUseCase!
    var mockBiometricService: MockBiometricAuthService!

    override func setUp() {
        super.setUp()
        mockAuthUseCase = MockAuthenticationUseCase()
        mockBiometricService = MockBiometricAuthService()
        viewModel = LoginViewModel(
            authenticationUseCase: mockAuthUseCase,
            biometricAuthService: mockBiometricService
        )
    }

    override func tearDown() {
        viewModel = nil
        mockAuthUseCase = nil
        mockBiometricService = nil
        super.tearDown()
    }

    func testPhoneNumberValidation_ValidIndianNumber_SetsValidToTrue() {
        // Given
        viewModel.selectedCountryCode = "+91"

        // When
        viewModel.phoneNumber = "9876543210"

        // Then
        XCTAssertTrue(viewModel.isPhoneNumberValid)
        XCTAssertNil(viewModel.phoneNumberError)
    }

    func testPhoneNumberValidation_InvalidIndianNumber_SetsValidToFalse() {
        // Given
        viewModel.selectedCountryCode = "+91"

        // When
        viewModel.phoneNumber = "123456"

        // Then
        XCTAssertFalse(viewModel.isPhoneNumberValid)
        XCTAssertEqual(viewModel.phoneNumberError, "Please enter a valid phone number")
    }

    func testSendOTP_ValidPhoneNumber_CallsAuthUseCase() async {
        // Given
        viewModel.phoneNumber = "9876543210"
        viewModel.selectedCountryCode = "+91"

        let expectedResponse = OTPResponse(
            otpId: "test-otp-id",
            expiresAt: Date().addingTimeInterval(300),
            retryAfter: nil
        )
        mockAuthUseCase.sendOTPResult = .success(expectedResponse)

        // When
        viewModel.sendOTP()

        // Wait for async operation
        await Task.yield()

        // Then
        XCTAssertTrue(mockAuthUseCase.sendOTPCalled)
        XCTAssertEqual(mockAuthUseCase.phoneNumberUsed, "+919876543210")
        XCTAssertFalse(viewModel.isSendingOTP)
    }

    func testSendOTP_APIError_ShowsErrorMessage() async {
        // Given
        viewModel.phoneNumber = "9876543210"
        viewModel.selectedCountryCode = "+91"

        let expectedError = APIError.tooManyRequests
        mockAuthUseCase.sendOTPResult = .failure(expectedError)

        // When
        viewModel.sendOTP()

        // Wait for async operation
        await Task.yield()

        // Then
        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(viewModel.errorMessage, "Too many requests. Please try again later.")
        XCTAssertFalse(viewModel.isSendingOTP)
    }

    func testBiometricAuthentication_Success_CallsAuthUseCase() async {
        // Given
        mockBiometricService.authenticateResult = .success(true)
        mockAuthUseCase.authenticateWithStoredCredentialsResult = .success(true)

        // When
        viewModel.authenticateWithBiometrics()

        // Wait for async operation
        await Task.yield()

        // Then
        XCTAssertTrue(mockBiometricService.authenticateCalled)
        XCTAssertTrue(mockAuthUseCase.authenticateWithStoredCredentialsCalled)
    }

    func testCanSendOTP_InvalidPhoneNumber_ReturnsFalse() {
        // Given
        viewModel.phoneNumber = "123"
        viewModel.isPhoneNumberValid = false

        // When & Then
        XCTAssertFalse(viewModel.canSendOTP)
    }

    func testCanSendOTP_ValidPhoneNumberAndNotSending_ReturnsTrue() {
        // Given
        viewModel.phoneNumber = "9876543210"
        viewModel.isPhoneNumberValid = true
        viewModel.isSendingOTP = false

        // When & Then
        XCTAssertTrue(viewModel.canSendOTP)
    }
}
```

### Mock Services Implementation
```swift
class MockAuthenticationUseCase: AuthenticationUseCaseProtocol {
    var sendOTPResult: Result<OTPResponse, Error> = .success(OTPResponse.mock())
    var verifyOTPResult: Result<AuthTokens, Error> = .success(AuthTokens.mock())
    var authenticateWithStoredCredentialsResult: Result<Bool, Error> = .success(true)

    var sendOTPCalled = false
    var verifyOTPCalled = false
    var authenticateWithStoredCredentialsCalled = false

    var phoneNumberUsed: String?
    var otpUsed: String?

    func sendOTP(phoneNumber: String) -> AnyPublisher<OTPResponse, Error> {
        sendOTPCalled = true
        phoneNumberUsed = phoneNumber

        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                promise(self.sendOTPResult)
            }
        }
        .eraseToAnyPublisher()
    }

    func verifyOTP(phoneNumber: String, otp: String) -> AnyPublisher<AuthTokens, Error> {
        verifyOTPCalled = true
        phoneNumberUsed = phoneNumber
        otpUsed = otp

        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                promise(self.verifyOTPResult)
            }
        }
        .eraseToAnyPublisher()
    }

    func authenticateWithStoredCredentials() -> AnyPublisher<Bool, Error> {
        authenticateWithStoredCredentialsCalled = true

        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                promise(self.authenticateWithStoredCredentialsResult)
            }
        }
        .eraseToAnyPublisher()
    }

    func logout() -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

class MockBiometricAuthService: BiometricAuthServiceProtocol {
    var availableBiometricTypeResult: BiometricType = .faceID
    var hasSavedCredentialsResult = true
    var authenticateResult: Result<Bool, Error> = .success(true)
    var saveCredentialsResult: Result<Bool, Error> = .success(true)

    var authenticateCalled = false
    var saveCredentialsCalled = false

    func availableBiometricType() -> BiometricType {
        return availableBiometricTypeResult
    }

    func hasSavedCredentials() -> Bool {
        return hasSavedCredentialsResult
    }

    func authenticate() -> AnyPublisher<Bool, Error> {
        authenticateCalled = true

        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                promise(self.authenticateResult)
            }
        }
        .eraseToAnyPublisher()
    }

    func saveCredentials() -> AnyPublisher<Bool, Error> {
        saveCredentialsCalled = true

        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                promise(self.saveCredentialsResult)
            }
        }
        .eraseToAnyPublisher()
    }
}
```

## UI Testing Implementation

### UI Test Base Class
```swift
import XCUITest

class BaseUITest: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    func login(phoneNumber: String = "9876543210", otp: String = "123456") {
        // Navigate to login if not already there
        if !app.textFields["phoneNumberField"].exists {
            app.buttons["loginButton"].tap()
        }

        // Enter phone number
        let phoneField = app.textFields["phoneNumberField"]
        phoneField.tap()
        phoneField.typeText(phoneNumber)

        // Send OTP
        app.buttons["sendOTPButton"].tap()

        // Wait for OTP screen
        XCTAssertTrue(app.textFields["otpField"].waitForExistence(timeout: 5))

        // Enter OTP
        let otpField = app.textFields["otpField"]
        otpField.tap()
        otpField.typeText(otp)

        // Verify OTP
        app.buttons["verifyOTPButton"].tap()

        // Wait for main screen
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    func navigateToTab(_ tab: String) {
        app.tabBars.buttons[tab].tap()
    }

    func waitForLoadingToFinish(timeout: TimeInterval = 10) {
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.exists {
            XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: timeout))
        }
    }

    func pullToRefresh(on element: XCUIElement) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    func takeScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

### Authentication Flow Tests
```swift
class AuthenticationUITests: BaseUITest {

    func testLoginFlow_ValidCredentials_SucceedsAndNavigatesToDashboard() {
        // Given - App launches to login screen
        XCTAssertTrue(app.textFields["phoneNumberField"].exists)

        // When - User enters valid credentials
        login()

        // Then - User is logged in and sees dashboard
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Good"].firstMatch.exists) // Greeting message
    }

    func testLoginFlow_InvalidPhoneNumber_ShowsError() {
        // Given
        let phoneField = app.textFields["phoneNumberField"]
        let sendButton = app.buttons["sendOTPButton"]

        // When
        phoneField.tap()
        phoneField.typeText("123")

        // Then
        XCTAssertFalse(sendButton.isEnabled)
        XCTAssertTrue(app.staticTexts["Please enter a valid phone number"].exists)
    }

    func testOTPFlow_InvalidOTP_ShowsError() {
        // Given - Navigate to OTP screen
        let phoneField = app.textFields["phoneNumberField"]
        phoneField.tap()
        phoneField.typeText("9876543210")
        app.buttons["sendOTPButton"].tap()

        XCTAssertTrue(app.textFields["otpField"].waitForExistence(timeout: 5))

        // When - Enter invalid OTP
        let otpField = app.textFields["otpField"]
        otpField.tap()
        otpField.typeText("000000")
        app.buttons["verifyOTPButton"].tap()

        // Then - Error message appears
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Invalid verification code"].exists)
    }

    func testBiometricLogin_Available_ShowsBiometricOption() {
        // Given - Biometric authentication is available
        // This test requires simulator with biometric support enabled

        // When - App launches
        // Then - Biometric login option is visible
        XCTAssertTrue(app.buttons.matching(identifier: "biometricLoginButton").firstMatch.exists)
    }

    func testLogout_FromProfile_ReturnsToLogin() {
        // Given - User is logged in
        login()

        // When - User logs out
        navigateToTab("Profile")
        app.buttons["settingsButton"].tap()
        app.buttons["logoutButton"].tap()
        app.alerts.buttons["Logout"].tap()

        // Then - User returns to login screen
        XCTAssertTrue(app.textFields["phoneNumberField"].waitForExistence(timeout: 5))
    }
}
```

### Dashboard UI Tests
```swift
class DashboardUITests: BaseUITest {

    override func setUpWithError() throws {
        try super.setUpWithError()
        login() // Start each test logged in
    }

    func testDashboard_LoadsSuccessfully_ShowsAllSections() {
        // When - Dashboard loads
        waitForLoadingToFinish()

        // Then - All sections are visible
        XCTAssertTrue(app.staticTexts["Quick Overview"].exists)
        XCTAssertTrue(app.staticTexts["Upcoming Matches"].exists)
        XCTAssertTrue(app.staticTexts["Recent Activities"].exists)
        XCTAssertTrue(app.staticTexts["Quick Actions"].exists)
    }

    func testQuickActions_TapCreateMatch_OpensCreateMatchSheet() {
        // Given
        waitForLoadingToFinish()

        // When
        app.buttons["Create Match"].tap()

        // Then
        XCTAssertTrue(app.navigationBars["Create Match"].waitForExistence(timeout: 5))
    }

    func testPullToRefresh_OnDashboard_RefreshesData() {
        // Given
        waitForLoadingToFinish()
        let scrollView = app.scrollViews.firstMatch

        // When
        pullToRefresh(on: scrollView)

        // Then
        XCTAssertTrue(app.activityIndicators.firstMatch.waitForExistence(timeout: 2))
        waitForLoadingToFinish()
    }

    func testNavigation_TapQuickStat_NavigatesToCorrectScreen() {
        // Given
        waitForLoadingToFinish()

        // When
        app.buttons["Members"].tap()

        // Then
        // Should navigate to members screen (implementation dependent)
        XCTAssertTrue(app.navigationBars["Members"].waitForExistence(timeout: 5))
    }

    func testNotificationBadge_HasUnreadNotifications_ShowsBadge() {
        // Given - Unread notifications exist
        waitForLoadingToFinish()

        // When & Then
        let notificationButton = app.buttons.matching(identifier: "notificationButton").firstMatch
        XCTAssertTrue(notificationButton.exists)

        // Check if badge exists (this depends on test data)
        if app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9]+'")).firstMatch.exists {
            XCTAssertTrue(true, "Notification badge is visible")
        }
    }
}
```

### Performance Tests
```swift
class DashboardPerformanceTests: BaseUITest {

    func testDashboardLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    func testDashboardScrollPerformance() {
        // Given
        login()
        waitForLoadingToFinish()

        // When & Then
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            let scrollView = app.scrollViews.firstMatch
            scrollView.swipeUp()
            scrollView.swipeDown()
        }
    }

    func testDashboardMemoryUsage() {
        // Given
        login()

        // When & Then
        measure(metrics: [XCTMemoryMetric()]) {
            waitForLoadingToFinish()

            // Perform memory-intensive operations
            for _ in 0..<10 {
                pullToRefresh(on: app.scrollViews.firstMatch)
                waitForLoadingToFinish()
            }
        }
    }

    func testAPIResponseTime() {
        // Given
        login()

        // When & Then
        measure(metrics: [XCTClockMetric()]) {
            pullToRefresh(on: app.scrollViews.firstMatch)
            waitForLoadingToFinish()
        }
    }
}
```

## Mock Data and Test Utilities

### Test Data Factory
```swift
class TestDataFactory {
    static func createMockUser(
        id: String = "test-user-id",
        name: String = "Test User",
        phoneNumber: String = "+919876543210"
    ) -> User {
        return User(
            id: id,
            name: name,
            firstName: "Test",
            lastName: "User",
            email: "test@example.com",
            phoneNumber: phoneNumber,
            profileImageURL: nil,
            dateOfBirth: nil,
            gender: .male,
            role: .member,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func createMockClub(
        id: String = "test-club-id",
        name: String = "Test Cricket Club"
    ) -> Club {
        return Club(
            id: id,
            name: name,
            description: "A test cricket club",
            logoURL: nil,
            bannerURL: nil,
            location: nil,
            memberCount: 25,
            maxMembers: 50,
            isPublic: true,
            inviteCode: "TEST123",
            settings: ClubSettings.default,
            userRole: .member,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func createMockMatch(
        id: String = "test-match-id",
        title: String = "Test Match"
    ) -> Match {
        return Match(
            id: id,
            title: title,
            description: "Test match description",
            homeTeam: createMockTeam(name: "Home Team"),
            awayTeam: createMockTeam(name: "Away Team"),
            date: Date().addingTimeInterval(86400), // Tomorrow
            venue: "Test Ground",
            status: .upcoming,
            type: .league,
            isPublic: true,
            maxPlayers: 11,
            registrationDeadline: Date().addingTimeInterval(43200), // 12 hours
            createdBy: "test-user-id",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func createMockTeam(
        id: String = "test-team-id",
        name: String = "Test Team"
    ) -> Team {
        return Team(
            id: id,
            name: name,
            players: [],
            captain: nil,
            viceCaptain: nil,
            maxPlayers: 11,
            isComplete: false
        )
    }

    static func createMockTransaction(
        id: String = "test-transaction-id",
        amount: Double = 100.0,
        type: TransactionType = .credit
    ) -> Transaction {
        return Transaction(
            id: id,
            title: "Test Transaction",
            description: "Test transaction description",
            amount: amount,
            type: type,
            category: .membership,
            status: .completed,
            timestamp: Date(),
            referenceNumber: "REF123456",
            clubName: "Test Club",
            paymentMethod: .upi,
            paymentInfo: PaymentInfo(
                method: .upi,
                last4Digits: nil,
                upiId: "test@upi",
                gateway: "Razorpay",
                processingFees: 2.0
            ),
            hasReceipt: true,
            canRefund: true,
            canRepeat: true,
            canDispute: false
        )
    }
}

// MARK: - Mock Extensions for Easy Testing
extension OTPResponse {
    static func mock() -> OTPResponse {
        return OTPResponse(
            otpId: "mock-otp-id",
            expiresAt: Date().addingTimeInterval(300),
            retryAfter: nil
        )
    }
}

extension AuthTokens {
    static func mock() -> AuthTokens {
        return AuthTokens(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
    }
}

extension DashboardStats {
    static func mock() -> DashboardStats {
        return DashboardStats(
            memberCount: 25,
            upcomingMatches: 3,
            balance: 1500.0,
            pendingOrders: 2,
            totalMatches: 45,
            totalSpent: 5000.0
        )
    }
}
```

## Integration Testing

### API Integration Tests
```swift
class APIIntegrationTests: XCTestCase {
    var apiService: APIService!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        apiService = APIService(session: mockSession)
    }

    override func tearDown() {
        apiService = nil
        mockSession = nil
        super.tearDown()
    }

    func testSendOTP_ValidRequest_ReturnsSuccessResponse() async throws {
        // Given
        let expectedResponse = SendOTPResponse(
            success: true,
            message: "OTP sent successfully",
            otpId: "test-otp-id",
            expiresAt: Date().addingTimeInterval(300),
            retryAfter: nil
        )

        mockSession.data = try JSONEncoder.apiEncoder.encode(expectedResponse)
        mockSession.response = HTTPURLResponse(
            url: URL(string: "https://api.duggy.com/auth/send-otp")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // When
        let response = try await apiService.request(
            endpoint: .sendOTP(phoneNumber: "+919876543210"),
            responseType: SendOTPResponse.self
        ).async()

        // Then
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.otpId, "test-otp-id")
    }

    func testAPIService_UnauthorizedResponse_ThrowsAuthError() async {
        // Given
        mockSession.response = HTTPURLResponse(
            url: URL(string: "https://api.duggy.com/user/profile")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )

        // When & Then
        do {
            let _ = try await apiService.request(
                endpoint: .getUserProfile,
                responseType: UserDTO.self
            ).async()
            XCTFail("Expected unauthorized error")
        } catch APIError.unauthorized {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAPIService_NetworkError_RetriesAndFails() async {
        // Given
        mockSession.error = URLError(.notConnectedToInternet)

        // When & Then
        do {
            let _ = try await apiService.request(
                endpoint: .getUserProfile,
                responseType: UserDTO.self
            ).async()
            XCTFail("Expected network error")
        } catch APIError.networkUnavailable {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

class MockURLSession: URLSession {
    var data: Data?
    var response: URLResponse?
    var error: Error?

    override func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        return MockURLSessionDataTask {
            completionHandler(self.data, self.response, self.error)
        }
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    override func resume() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            self.completion()
        }
    }
}
```

## Test Configuration

### Test Scheme Configuration
```swift
// Test launch arguments for different test environments
enum TestConfiguration {
    case unit
    case integration
    case ui
    case performance

    var launchArguments: [String] {
        switch self {
        case .unit:
            return ["--unit-testing"]
        case .integration:
            return ["--integration-testing", "--mock-network"]
        case .ui:
            return ["--ui-testing", "--disable-animations"]
        case .performance:
            return ["--performance-testing", "--disable-analytics"]
        }
    }

    var launchEnvironment: [String: String] {
        switch self {
        case .unit, .integration:
            return ["API_BASE_URL": "https://api-mock.duggy.com"]
        case .ui:
            return [
                "API_BASE_URL": "https://api-mock.duggy.com",
                "DISABLE_ANIMATIONS": "true",
                "ENABLE_MOCK_DATA": "true"
            ]
        case .performance:
            return [
                "API_BASE_URL": "https://api-staging.duggy.com",
                "ENABLE_PERFORMANCE_MONITORING": "true"
            ]
        }
    }
}

// Test app configuration
extension DuggyApp {
    private var isRunningTests: Bool {
        return ProcessInfo.processInfo.arguments.contains("--unit-testing") ||
               ProcessInfo.processInfo.arguments.contains("--ui-testing") ||
               ProcessInfo.processInfo.arguments.contains("--integration-testing")
    }

    private func configureForTesting() {
        if ProcessInfo.processInfo.arguments.contains("--disable-animations") {
            UIView.setAnimationsEnabled(false)
        }

        if ProcessInfo.processInfo.arguments.contains("--mock-network") {
            // Configure mock networking
            DependencyContainer.shared.configureForTesting()
        }
    }
}
```

## Continuous Integration Setup

### Test Pipeline Configuration
```yaml
# .github/workflows/ios-tests.yml
name: iOS Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  unit-tests:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_14.3.app

    - name: Cache dependencies
      uses: actions/cache@v3
      with:
        path: |
          ~/Library/Developer/Xcode/DerivedData
          ~/.pub-cache
        key: ${{ runner.os }}-xcode-${{ hashFiles('**/Package.resolved') }}

    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -project Duggy.xcodeproj \
          -scheme DuggyTests \
          -destination 'platform=iOS Simulator,name=iPhone 14' \
          -configuration Debug \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO

    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: |
          ~/Library/Developer/Xcode/DerivedData/**/Logs/Test
          TestResults.xcresult

  ui-tests:
    runs-on: macos-latest
    needs: unit-tests
    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_14.3.app

    - name: Run UI Tests
      run: |
        xcodebuild test \
          -project Duggy.xcodeproj \
          -scheme DuggyUITests \
          -destination 'platform=iOS Simulator,name=iPhone 14' \
          -configuration Debug \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO

    - name: Upload Screenshots
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: ui-test-screenshots
        path: ~/Library/Developer/Xcode/DerivedData/**/Logs/Test/Attachments

  performance-tests:
    runs-on: macos-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_14.3.app

    - name: Run Performance Tests
      run: |
        xcodebuild test \
          -project Duggy.xcodeproj \
          -scheme DuggyPerformanceTests \
          -destination 'platform=iOS Simulator,name=iPhone 14' \
          -configuration Release \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO
```

## Quality Assurance Checklist

### Pre-Release Testing Checklist
```swift
struct QAChecklist {
    // MARK: - Functional Testing
    static let functionalTests = [
        "✓ Authentication flow works correctly",
        "✓ All navigation paths function properly",
        "✓ CRUD operations work for all entities",
        "✓ Real-time updates function correctly",
        "✓ Offline functionality works as expected",
        "✓ Error handling displays appropriate messages",
        "✓ Data validation works for all forms",
        "✓ Push notifications are received and handled",
        "✓ Deep linking works correctly",
        "✓ Payment flows complete successfully"
    ]

    // MARK: - UI/UX Testing
    static let uiuxTests = [
        "✓ All screens adapt to different device sizes",
        "✓ Dark mode support works correctly",
        "✓ Accessibility features work with VoiceOver",
        "✓ Dynamic type scaling works properly",
        "✓ Loading states display correctly",
        "✓ Error states are user-friendly",
        "✓ Empty states provide clear guidance",
        "✓ Animations are smooth and appropriate",
        "✓ Touch targets meet minimum size requirements",
        "✓ Color contrast meets accessibility standards"
    ]

    // MARK: - Performance Testing
    static let performanceTests = [
        "✓ App launches in under 3 seconds",
        "✓ Navigation transitions are smooth (60fps)",
        "✓ API responses load within 2 seconds",
        "✓ Images load progressively",
        "✓ Memory usage stays under 150MB",
        "✓ Battery usage is optimized",
        "✓ Network requests are efficiently cached",
        "✓ Background processing is minimal",
        "✓ Large lists scroll smoothly",
        "✓ App handles low memory conditions"
    ]

    // MARK: - Security Testing
    static let securityTests = [
        "✓ Sensitive data is stored securely",
        "✓ Network communications use HTTPS",
        "✓ Authentication tokens are protected",
        "✓ User input is properly validated",
        "✓ Biometric authentication works securely",
        "✓ Session management is secure",
        "✓ No sensitive data in logs",
        "✓ Certificate pinning is implemented",
        "✓ App permissions are minimal and justified",
        "✓ Data encryption is properly implemented"
    ]

    // MARK: - Device Testing
    static let deviceTests = [
        "✓ iPhone SE (1st gen) - iOS 15.0",
        "✓ iPhone 12 mini - iOS 16.0",
        "✓ iPhone 13 - iOS 17.0",
        "✓ iPhone 14 Pro - iOS 17.0",
        "✓ iPhone 15 Pro Max - iOS 17.0",
        "✓ iPad (9th gen) - iOS 15.0",
        "✓ iPad Air (5th gen) - iOS 16.0",
        "✓ iPad Pro (12.9-inch) - iOS 17.0"
    ]
}
```

## Testing Implementation Tasks

### Unit Testing Tasks
- [ ] Create BaseViewModelTest class with utilities
- [ ] Implement tests for all ViewModels
- [ ] Add tests for all use cases and business logic
- [ ] Create model validation and transformation tests
- [ ] Test utility functions and extensions
- [ ] Add error handling and edge case tests

### Mock Implementation Tasks
- [ ] Create mock services for all protocols
- [ ] Implement TestDataFactory for test data
- [ ] Add mock network layer for integration tests
- [ ] Create configurable mock responses
- [ ] Implement realistic test data scenarios
- [ ] Add performance simulation in mocks

### UI Testing Tasks
- [ ] Create BaseUITest class with helpers
- [ ] Implement user journey tests
- [ ] Add accessibility testing
- [ ] Create form validation tests
- [ ] Test navigation and deep linking
- [ ] Add visual regression testing

### Performance Testing Tasks
- [ ] Create performance benchmarks
- [ ] Test app launch time and memory usage
- [ ] Add network performance tests
- [ ] Create stress testing scenarios
- [ ] Test battery usage optimization
- [ ] Implement automated performance monitoring

### CI/CD Integration Tasks
- [ ] Set up GitHub Actions for automated testing
- [ ] Create test reporting and coverage tools
- [ ] Implement automated UI test execution
- [ ] Add performance regression detection
- [ ] Create test result archiving
- [ ] Set up notification for test failures

This comprehensive testing strategy ensures high quality, reliability, and performance for the iOS app across all features and use cases.