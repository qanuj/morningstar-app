# Login Screen Implementation

## Overview
Complete implementation guide for the phone-based authentication system with OTP verification, modern UI design, and seamless user experience.

## 🎯 Login Screen Tasks

### UI Implementation
- [ ] Create modern login screen layout
- [ ] Implement phone number input with country code selection
- [ ] Add input validation and error states
- [ ] Create smooth loading states and animations
- [ ] Implement accessibility features
- [ ] Add biometric authentication option

### Authentication Logic
- [ ] Integrate phone number validation
- [ ] Implement OTP request functionality
- [ ] Add authentication state management
- [ ] Create secure token storage
- [ ] Implement automatic login for returning users
- [ ] Add logout and session management

### Error Handling
- [ ] Handle network connectivity issues
- [ ] Manage API error responses
- [ ] Implement rate limiting for OTP requests
- [ ] Add retry mechanisms
- [ ] Create user-friendly error messages
- [ ] Handle edge cases and validation errors

## UI Implementation

### Login View
```swift
struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject var authenticationStore: AuthenticationStore
    @FocusState private var isPhoneFieldFocused: Bool

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Header Section
                        headerSection
                            .frame(height: geometry.size.height * 0.4)

                        // Form Section
                        formSection
                            .padding(.horizontal, 24)
                            .padding(.top, 40)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setupInitialState()
        }
        .onChange(of: authenticationStore.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // Navigation handled by parent
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var headerSection: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [Color.primaryBlue, Color.lightBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 24) {
                Spacer()

                // Logo
                Image("DuggyLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)

                // Title and Subtitle
                VStack(spacing: 8) {
                    Text("Welcome to Duggy")
                        .font(.headline2)
                        .foregroundColor(.white)
                        .fontWeight(.bold)

                    Text("Your Cricket Club Companion")
                        .font(.bodyLarge)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()
            }
        }
    }

    private var formSection: some View {
        VStack(spacing: 32) {
            // Welcome Message
            VStack(spacing: 8) {
                Text("Sign in to continue")
                    .font(.headline3)
                    .foregroundColor(.textPrimary)

                Text("We'll send you a verification code")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Phone Input Section
            VStack(spacing: 20) {
                PhoneNumberInput(
                    phoneNumber: $viewModel.phoneNumber,
                    countryCode: $viewModel.selectedCountryCode,
                    isValid: $viewModel.isPhoneNumberValid,
                    errorMessage: viewModel.phoneNumberError
                )
                .focused($isPhoneFieldFocused)

                // Send OTP Button
                PrimaryButton(
                    title: "Send Verification Code",
                    action: {
                        isPhoneFieldFocused = false
                        viewModel.sendOTP()
                    },
                    isEnabled: viewModel.canSendOTP,
                    isLoading: viewModel.isSendingOTP
                )
            }

            // Additional Options
            additionalOptionsSection

            Spacer()
        }
    }

    private var additionalOptionsSection: some View {
        VStack(spacing: 20) {
            // Biometric Login (if available)
            if viewModel.biometricAuthAvailable {
                Button(action: viewModel.authenticateWithBiometrics) {
                    HStack {
                        Image(systemName: viewModel.biometricType.iconName)
                            .font(.title2)
                        Text("Sign in with \(viewModel.biometricType.displayName)")
                            .font(.bodyMedium)
                    }
                    .foregroundColor(.primaryBlue)
                }
            }

            // Terms and Privacy
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                HStack {
                    Button("Terms of Service") {
                        viewModel.showTermsOfService()
                    }
                    .font(.caption)
                    .foregroundColor(.primaryBlue)

                    Text("and")
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    Button("Privacy Policy") {
                        viewModel.showPrivacyPolicy()
                    }
                    .font(.caption)
                    .foregroundColor(.primaryBlue)
                }
            }
        }
    }
}
```

### Enhanced Phone Number Input
```swift
struct PhoneNumberInput: View {
    @Binding var phoneNumber: String
    @Binding var countryCode: String
    @Binding var isValid: Bool
    let errorMessage: String?

    @State private var showCountryPicker = false
    @State private var searchText = ""

    private let countryCodes = CountryCode.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phone Number")
                .font(.label)
                .foregroundColor(.textPrimary)

            HStack(spacing: 12) {
                // Country Code Button
                Button(action: { showCountryPicker = true }) {
                    HStack(spacing: 8) {
                        Text(selectedCountry.flag)
                            .font(.title2)

                        Text(countryCode)
                            .font(.bodyMedium)
                            .foregroundColor(.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.borderColor, lineWidth: 1)
                    )
                }

                // Phone Number Field
                TextField("Enter phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.bodyMedium)
                    .textFieldStyle(
                        CustomTextFieldStyle(isError: errorMessage != nil && !phoneNumber.isEmpty)
                    )
                    .onChange(of: phoneNumber) { newValue in
                        validatePhoneNumber(newValue)
                    }
            }

            // Error Message
            if let errorMessage = errorMessage, !phoneNumber.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.errorRed)
                        .font(.caption)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.errorRed)
                }
            }

            // Format Helper
            if !phoneNumber.isEmpty && errorMessage == nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.successGreen)
                        .font(.caption)

                    Text("Valid phone number")
                        .font(.caption)
                        .foregroundColor(.successGreen)
                }
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryCodePicker(
                selectedCountryCode: $countryCode,
                searchText: $searchText
            )
        }
    }

    private var selectedCountry: CountryCode {
        countryCodes.first { $0.dialCode == countryCode } ?? .india
    }

    private func validatePhoneNumber(_ number: String) {
        let cleanNumber = number.filter { $0.isNumber }
        isValid = selectedCountry.isValidPhoneNumber(cleanNumber)
    }
}
```

### Country Code Picker
```swift
struct CountryCodePicker: View {
    @Binding var selectedCountryCode: String
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss

    private var filteredCountries: [CountryCode] {
        if searchText.isEmpty {
            return CountryCode.allCases
        } else {
            return CountryCode.allCases.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.dialCode.contains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                SearchBar(
                    searchText: $searchText,
                    placeholder: "Search countries..."
                )
                .padding(.horizontal)

                // Country List
                List(filteredCountries, id: \.code) { country in
                    Button(action: {
                        selectedCountryCode = country.dialCode
                        dismiss()
                    }) {
                        HStack {
                            Text(country.flag)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name)
                                    .font(.bodyMedium)
                                    .foregroundColor(.textPrimary)

                                Text(country.dialCode)
                                    .font(.bodySmall)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            if selectedCountryCode == country.dialCode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryBlue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
```

## ViewModel Implementation

### Login ViewModel
```swift
@MainActor
class LoginViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published var selectedCountryCode = "+91"
    @Published var isPhoneNumberValid = false
    @Published var phoneNumberError: String? = nil

    @Published var isSendingOTP = false
    @Published var showError = false
    @Published var errorMessage = ""

    @Published var biometricAuthAvailable = false
    @Published var biometricType: BiometricType = .none

    private let authenticationUseCase: AuthenticationUseCaseProtocol
    private let biometricAuthService: BiometricAuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    var canSendOTP: Bool {
        isPhoneNumberValid && !isSendingOTP && !phoneNumber.isEmpty
    }

    init(
        authenticationUseCase: AuthenticationUseCaseProtocol = DependencyContainer.shared.authenticationUseCase,
        biometricAuthService: BiometricAuthServiceProtocol = DependencyContainer.shared.biometricAuthService
    ) {
        self.authenticationUseCase = authenticationUseCase
        self.biometricAuthService = biometricAuthService

        setupValidation()
    }

    func setupInitialState() {
        checkBiometricAvailability()
        loadSavedPhoneNumber()
    }

    func sendOTP() {
        guard canSendOTP else { return }

        let fullPhoneNumber = selectedCountryCode + phoneNumber
        isSendingOTP = true

        authenticationUseCase.sendOTP(phoneNumber: fullPhoneNumber)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSendingOTP = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.handleOTPSent(response)
                }
            )
            .store(in: &cancellables)
    }

    func authenticateWithBiometrics() {
        biometricAuthService.authenticate()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.handleBiometricAuthSuccess()
                    }
                }
            )
            .store(in: &cancellables)
    }

    func showTermsOfService() {
        // Open terms of service
        if let url = URL(string: "https://duggy.com/terms") {
            UIApplication.shared.open(url)
        }
    }

    func showPrivacyPolicy() {
        // Open privacy policy
        if let url = URL(string: "https://duggy.com/privacy") {
            UIApplication.shared.open(url)
        }
    }

    private func setupValidation() {
        $phoneNumber
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] number in
                self?.validatePhoneNumber(number)
            }
            .store(in: &cancellables)
    }

    private func validatePhoneNumber(_ number: String) {
        let cleanNumber = number.filter { $0.isNumber }

        if cleanNumber.isEmpty {
            phoneNumberError = nil
            isPhoneNumberValid = false
            return
        }

        let selectedCountry = CountryCode.allCases.first { $0.dialCode == selectedCountryCode } ?? .india

        if selectedCountry.isValidPhoneNumber(cleanNumber) {
            phoneNumberError = nil
            isPhoneNumberValid = true
        } else {
            phoneNumberError = "Please enter a valid phone number"
            isPhoneNumberValid = false
        }
    }

    private func checkBiometricAvailability() {
        biometricType = biometricAuthService.availableBiometricType()
        biometricAuthAvailable = biometricType != .none && biometricAuthService.hasSavedCredentials()
    }

    private func loadSavedPhoneNumber() {
        if let savedNumber = UserDefaults.standard.string(forKey: "lastPhoneNumber") {
            phoneNumber = savedNumber
        }
    }

    private func handleOTPSent(_ response: OTPResponse) {
        // Save phone number for future use
        UserDefaults.standard.set(phoneNumber, forKey: "lastPhoneNumber")

        // Navigate to OTP verification
        NotificationCenter.default.post(
            name: .navigateToOTPVerification,
            object: OTPVerificationData(
                phoneNumber: selectedCountryCode + phoneNumber,
                otpId: response.otpId
            )
        )
    }

    private func handleBiometricAuthSuccess() {
        // Biometric authentication successful, check stored credentials
        authenticationUseCase.authenticateWithStoredCredentials()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { success in
                    // Authentication handled by AuthenticationStore
                }
            )
            .store(in: &cancellables)
    }

    private func handleError(_ error: Error) {
        if let authError = error as? AuthenticationError {
            switch authError {
            case .invalidPhoneNumber:
                phoneNumberError = "Please enter a valid phone number"
            case .tooManyRequests:
                errorMessage = "Too many requests. Please try again later."
                showError = true
            case .networkError:
                errorMessage = "Network error. Please check your connection."
                showError = true
            default:
                errorMessage = authError.localizedDescription
                showError = true
            }
        } else {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
```

## Country Code Model

### Country Code Implementation
```swift
enum CountryCode: String, CaseIterable {
    case india = "IN"
    case usa = "US"
    case uk = "GB"
    case canada = "CA"
    case australia = "AU"
    case newZealand = "NZ"
    case southAfrica = "ZA"

    var name: String {
        switch self {
        case .india: return "India"
        case .usa: return "United States"
        case .uk: return "United Kingdom"
        case .canada: return "Canada"
        case .australia: return "Australia"
        case .newZealand: return "New Zealand"
        case .southAfrica: return "South Africa"
        }
    }

    var dialCode: String {
        switch self {
        case .india: return "+91"
        case .usa: return "+1"
        case .uk: return "+44"
        case .canada: return "+1"
        case .australia: return "+61"
        case .newZealand: return "+64"
        case .southAfrica: return "+27"
        }
    }

    var flag: String {
        switch self {
        case .india: return "🇮🇳"
        case .usa: return "🇺🇸"
        case .uk: return "🇬🇧"
        case .canada: return "🇨🇦"
        case .australia: return "🇦🇺"
        case .newZealand: return "🇳🇿"
        case .southAfrica: return "🇿🇦"
        }
    }

    var code: String {
        return rawValue
    }

    func isValidPhoneNumber(_ number: String) -> Bool {
        switch self {
        case .india:
            return number.count == 10 && number.first != "0"
        case .usa, .canada:
            return number.count == 10
        case .uk:
            return number.count >= 10 && number.count <= 11
        case .australia:
            return number.count == 9 && number.hasPrefix("4")
        case .newZealand:
            return number.count >= 8 && number.count <= 9
        case .southAfrica:
            return number.count == 9
        }
    }
}
```

## Biometric Authentication

### Biometric Auth Service
```swift
protocol BiometricAuthServiceProtocol {
    func availableBiometricType() -> BiometricType
    func hasSavedCredentials() -> Bool
    func authenticate() -> AnyPublisher<Bool, Error>
    func saveCredentials() -> AnyPublisher<Bool, Error>
}

class BiometricAuthService: BiometricAuthServiceProtocol {
    private let context = LAContext()
    private let keychain = KeychainAccess.Keychain(service: "com.duggy.biometric")

    func availableBiometricType() -> BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.biometryAny, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    func hasSavedCredentials() -> Bool {
        do {
            let _ = try keychain.get("biometric_token")
            return true
        } catch {
            return false
        }
    }

    func authenticate() -> AnyPublisher<Bool, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(BiometricError.serviceUnavailable))
                return
            }

            let reason = "Authenticate to access your account"

            self.context.evaluatePolicy(.biometryAny, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        promise(.success(true))
                    } else if let error = error {
                        promise(.failure(error))
                    } else {
                        promise(.failure(BiometricError.authenticationFailed))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func saveCredentials() -> AnyPublisher<Bool, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(BiometricError.serviceUnavailable))
                return
            }

            // Save encrypted token to keychain
            do {
                let token = UUID().uuidString // This would be actual auth token
                try self.keychain.set(token, key: "biometric_token")
                promise(.success(true))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
}

enum BiometricType {
    case none
    case touchID
    case faceID

    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        }
    }

    var iconName: String {
        switch self {
        case .none: return ""
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        }
    }
}

enum BiometricError: LocalizedError {
    case serviceUnavailable
    case authenticationFailed
    case biometryNotAvailable
    case biometryNotEnrolled

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Biometric service is not available"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometryNotEnrolled:
            return "No biometric data is enrolled on this device"
        }
    }
}
```

## Authentication Data Models

### OTP Response Model
```swift
struct OTPResponse {
    let otpId: String
    let expiresAt: Date
    let retryAfter: TimeInterval?
}

struct OTPVerificationData {
    let phoneNumber: String
    let otpId: String
}
```

## Notification Extensions

### Navigation Notifications
```swift
extension Notification.Name {
    static let navigateToOTPVerification = Notification.Name("navigateToOTPVerification")
    static let authenticationStateChanged = Notification.Name("authenticationStateChanged")
}
```

## Login Screen Implementation Tasks

### UI Implementation Tasks
- [ ] Create LoginView with modern design
- [ ] Implement PhoneNumberInput with validation
- [ ] Build CountryCodePicker with search
- [ ] Add smooth animations and transitions
- [ ] Implement loading states and error handling
- [ ] Add accessibility features and VoiceOver support

### Authentication Tasks
- [ ] Create LoginViewModel with validation logic
- [ ] Implement phone number validation for different countries
- [ ] Add OTP request functionality
- [ ] Create BiometricAuthService
- [ ] Implement secure credential storage
- [ ] Add automatic login for returning users

### Validation Tasks
- [ ] Add real-time phone number validation
- [ ] Implement country-specific number formats
- [ ] Create error handling for different scenarios
- [ ] Add rate limiting for OTP requests
- [ ] Implement retry mechanisms
- [ ] Test validation across all supported countries

### Security Tasks
- [ ] Implement secure token storage in Keychain
- [ ] Add biometric authentication option
- [ ] Create session management
- [ ] Implement logout functionality
- [ ] Add security measures for sensitive operations
- [ ] Test security implementations

This login screen provides a modern, secure, and user-friendly authentication experience with support for multiple countries and biometric authentication.