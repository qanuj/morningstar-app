# iOS App Architecture & Design Patterns

## Overview
Comprehensive architecture guide for the Duggy iOS app using MVVM pattern with SwiftUI, Combine framework, and clean architecture principles.

## 🎯 Architecture Tasks

### Design Pattern Implementation
- [ ] Set up MVVM architecture with ViewModels
- [ ] Implement Repository pattern for data layer
- [ ] Create Service layer for API communication
- [ ] Set up Dependency Injection container
- [ ] Implement Coordinator pattern for navigation
- [ ] Create Use Cases for business logic separation

### Data Flow & State Management
- [ ] Configure Combine publishers and subscribers
- [ ] Implement ObservableObject ViewModels
- [ ] Set up @Published properties for reactive UI
- [ ] Create data binding between Views and ViewModels
- [ ] Implement error handling and loading states
- [ ] Set up global app state management

## Architecture Layers

### 1. Presentation Layer (SwiftUI Views + ViewModels)

#### View Structure
```swift
// Views should be lightweight and delegate business logic to ViewModels
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authenticationStore: AuthenticationStore

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Dashboard")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProfileButton()
                    }
                }
        }
        .onAppear {
            viewModel.loadDashboardData()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            LoadingView()
        } else {
            DashboardContentView(data: viewModel.dashboardData)
        }
    }
}
```

#### ViewModel Pattern
```swift
@MainActor
class HomeViewModel: ObservableObject {
    @Published var dashboardData: DashboardData?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let dashboardUseCase: DashboardUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(dashboardUseCase: DashboardUseCaseProtocol = DependencyContainer.shared.dashboardUseCase) {
        self.dashboardUseCase = dashboardUseCase
    }

    func loadDashboardData() {
        isLoading = true

        dashboardUseCase.getDashboardData()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] data in
                    self?.dashboardData = data
                }
            )
            .store(in: &cancellables)
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

### 2. Domain Layer (Business Logic)

#### Entities
```swift
struct Club {
    let id: String
    let name: String
    let logoURL: String?
    let memberCount: Int
    let isOwner: Bool
    let settings: ClubSettings
}

struct Match {
    let id: String
    let title: String
    let opponent: String
    let date: Date
    let venue: String
    let status: MatchStatus
    let team: Team?
}

struct User {
    let id: String
    let name: String
    let phone: String
    let email: String?
    let profileImageURL: String?
    let role: UserRole
    let clubs: [Club]
}
```

#### Use Cases
```swift
protocol DashboardUseCaseProtocol {
    func getDashboardData() -> AnyPublisher<DashboardData, Error>
}

class DashboardUseCase: DashboardUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol
    private let clubRepository: ClubRepositoryProtocol
    private let matchRepository: MatchRepositoryProtocol

    init(
        userRepository: UserRepositoryProtocol,
        clubRepository: ClubRepositoryProtocol,
        matchRepository: MatchRepositoryProtocol
    ) {
        self.userRepository = userRepository
        self.clubRepository = clubRepository
        self.matchRepository = matchRepository
    }

    func getDashboardData() -> AnyPublisher<DashboardData, Error> {
        Publishers.Zip3(
            userRepository.getCurrentUser(),
            clubRepository.getUserClubs(),
            matchRepository.getUpcomingMatches()
        )
        .map { user, clubs, matches in
            DashboardData(
                user: user,
                clubs: clubs,
                upcomingMatches: matches,
                quickStats: self.calculateQuickStats(clubs: clubs, matches: matches)
            )
        }
        .eraseToAnyPublisher()
    }

    private func calculateQuickStats(clubs: [Club], matches: [Match]) -> QuickStats {
        // Calculate statistics
        QuickStats(
            totalClubs: clubs.count,
            upcomingMatches: matches.count,
            totalBalance: 0 // Calculate from transactions
        )
    }
}
```

### 3. Data Layer (Repositories & Services)

#### Repository Pattern
```swift
protocol ClubRepositoryProtocol {
    func getUserClubs() -> AnyPublisher<[Club], Error>
    func getClubDetails(id: String) -> AnyPublisher<Club, Error>
    func createClub(_ club: CreateClubRequest) -> AnyPublisher<Club, Error>
    func updateClub(id: String, _ club: UpdateClubRequest) -> AnyPublisher<Club, Error>
}

class ClubRepository: ClubRepositoryProtocol {
    private let apiService: APIServiceProtocol
    private let localStorage: LocalStorageProtocol

    init(apiService: APIServiceProtocol, localStorage: LocalStorageProtocol) {
        self.apiService = apiService
        self.localStorage = localStorage
    }

    func getUserClubs() -> AnyPublisher<[Club], Error> {
        // Try local storage first, then API
        localStorage.getCachedClubs()
            .catch { _ in
                self.apiService.request(endpoint: .getUserClubs, responseType: [ClubDTO].self)
                    .map { $0.map { $0.toDomain() } }
                    .handleEvents(receiveOutput: { clubs in
                        self.localStorage.cacheClubs(clubs)
                    })
            }
            .eraseToAnyPublisher()
    }

    func getClubDetails(id: String) -> AnyPublisher<Club, Error> {
        apiService.request(
            endpoint: .getClubDetails(id: id),
            responseType: ClubDTO.self
        )
        .map { $0.toDomain() }
        .eraseToAnyPublisher()
    }
}
```

#### API Service
```swift
protocol APIServiceProtocol {
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) -> AnyPublisher<T, Error>
}

class APIService: APIServiceProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let authenticationStore: AuthenticationStore

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: Environment.current.apiBaseURL)!,
        authenticationStore: AuthenticationStore
    ) {
        self.session = session
        self.baseURL = baseURL
        self.authenticationStore = authenticationStore
    }

    func request<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) -> AnyPublisher<T, Error> {

        guard let request = createURLRequest(for: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw APIError.unauthorized
                case 400...499:
                    throw APIError.clientError(httpResponse.statusCode)
                case 500...599:
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    throw APIError.unknown
                }
            }
            .decode(type: T.self, decoder: JSONDecoder.apiDecoder)
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                }
                return error
            }
            .eraseToAnyPublisher()
    }

    private func createURLRequest(for endpoint: APIEndpoint) -> URLRequest? {
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication header
        if let token = authenticationStore.currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add request body if needed
        if let parameters = endpoint.parameters {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }

        return request
    }
}
```

### 4. Navigation & Coordination

#### Navigation Store
```swift
@MainActor
class NavigationStore: ObservableObject {
    @Published var selectedTab: MainTab = .home
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: PresentedSheet?
    @Published var presentedFullScreen: PresentedFullScreen?

    enum MainTab: String, CaseIterable {
        case home = "house.fill"
        case matches = "sportscourt.fill"
        case store = "bag.fill"
        case wallet = "creditcard.fill"
        case profile = "person.fill"

        var title: String {
            switch self {
            case .home: return "Home"
            case .matches: return "Matches"
            case .store: return "Store"
            case .wallet: return "Wallet"
            case .profile: return "Profile"
            }
        }
    }

    enum PresentedSheet: Identifiable {
        case createMatch
        case editProfile
        case addMembers
        case paymentMethod

        var id: String {
            switch self {
            case .createMatch: return "createMatch"
            case .editProfile: return "editProfile"
            case .addMembers: return "addMembers"
            case .paymentMethod: return "paymentMethod"
            }
        }
    }

    func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }

    func presentSheet(_ sheet: PresentedSheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}
```

#### Navigation Destinations
```swift
enum NavigationDestination: Hashable {
    case matchDetail(matchId: String)
    case clubDetail(clubId: String)
    case memberProfile(userId: String)
    case orderDetail(orderId: String)
    case transactionDetail(transactionId: String)
    case productDetail(productId: String)
    case editClub(clubId: String)
    case clubSettings(clubId: String)
}
```

### 5. Dependency Injection

#### Dependency Container
```swift
class DependencyContainer {
    static let shared = DependencyContainer()

    private init() {}

    // MARK: - Stores
    lazy var authenticationStore: AuthenticationStore = {
        AuthenticationStore(
            authService: authService,
            keychain: keychainService
        )
    }()

    lazy var navigationStore: NavigationStore = {
        NavigationStore()
    }()

    // MARK: - Services
    lazy var apiService: APIServiceProtocol = {
        APIService(authenticationStore: authenticationStore)
    }()

    lazy var keychainService: KeychainServiceProtocol = {
        KeychainService()
    }()

    lazy var localStorage: LocalStorageProtocol = {
        CoreDataStorage()
    }()

    // MARK: - Repositories
    lazy var userRepository: UserRepositoryProtocol = {
        UserRepository(
            apiService: apiService,
            localStorage: localStorage
        )
    }()

    lazy var clubRepository: ClubRepositoryProtocol = {
        ClubRepository(
            apiService: apiService,
            localStorage: localStorage
        )
    }()

    // MARK: - Use Cases
    lazy var dashboardUseCase: DashboardUseCaseProtocol = {
        DashboardUseCase(
            userRepository: userRepository,
            clubRepository: clubRepository,
            matchRepository: matchRepository
        )
    }()

    lazy var authenticationUseCase: AuthenticationUseCaseProtocol = {
        AuthenticationUseCase(
            authService: authService,
            userRepository: userRepository
        )
    }()
}
```

## Error Handling

### Error Types
```swift
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case clientError(Int)
    case serverError(Int)
    case decodingError
    case networkError
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .clientError(let code):
            return "Client error: \(code)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError:
            return "Network connection error"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidPhoneNumber
    case invalidEmail
    case passwordTooShort
    case requiredFieldEmpty(String)

    var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "Please enter a valid phone number"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .passwordTooShort:
            return "Password must be at least 6 characters long"
        case .requiredFieldEmpty(let field):
            return "\(field) is required"
        }
    }
}
```

## Testing Architecture

### ViewModel Testing
```swift
@MainActor
class HomeViewModelTests: XCTestCase {
    var viewModel: HomeViewModel!
    var mockDashboardUseCase: MockDashboardUseCase!

    override func setUp() {
        super.setUp()
        mockDashboardUseCase = MockDashboardUseCase()
        viewModel = HomeViewModel(dashboardUseCase: mockDashboardUseCase)
    }

    override func tearDown() {
        viewModel = nil
        mockDashboardUseCase = nil
        super.tearDown()
    }

    func testLoadDashboardDataSuccess() async {
        // Given
        let expectedData = DashboardData.mock()
        mockDashboardUseCase.result = .success(expectedData)

        // When
        viewModel.loadDashboardData()

        // Wait for async operation
        await Task.yield()

        // Then
        XCTAssertEqual(viewModel.dashboardData, expectedData)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showError)
    }

    func testLoadDashboardDataFailure() async {
        // Given
        let expectedError = APIError.serverError(500)
        mockDashboardUseCase.result = .failure(expectedError)

        // When
        viewModel.loadDashboardData()

        // Wait for async operation
        await Task.yield()

        // Then
        XCTAssertNil(viewModel.dashboardData)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(viewModel.errorMessage, expectedError.localizedDescription)
    }
}
```

## Architecture Implementation Tasks

### Core Setup
- [ ] Create base ViewModels with ObservableObject
- [ ] Implement Repository protocols and concrete implementations
- [ ] Set up API service with Combine publishers
- [ ] Create dependency injection container
- [ ] Implement navigation coordinator pattern
- [ ] Set up error handling system

### Data Layer
- [ ] Create all entity models
- [ ] Implement DTO to entity mapping
- [ ] Set up Core Data stack for local storage
- [ ] Create repository implementations
- [ ] Implement caching strategies
- [ ] Add offline data synchronization

### Presentation Layer
- [ ] Create base View protocols
- [ ] Implement common ViewModels
- [ ] Set up navigation system
- [ ] Create reusable UI components
- [ ] Implement state management
- [ ] Add loading and error states

### Testing Infrastructure
- [ ] Create mock implementations for all protocols
- [ ] Set up unit test structure
- [ ] Implement UI test helpers
- [ ] Create test data factories
- [ ] Add snapshot testing for UI components
- [ ] Set up continuous integration testing

This architecture provides a solid foundation for the entire iOS app with proper separation of concerns, testability, and maintainability.