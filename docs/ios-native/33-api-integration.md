# API Integration & Networking

## Overview
Complete implementation guide for REST API integration, networking layer, error handling, authentication, and data synchronization for the Duggy iOS app.

## 🎯 API Integration Tasks

### Core Networking
- [ ] Set up URLSession configuration and managers
- [ ] Implement API service layer with Combine
- [ ] Create request/response models and DTOs
- [ ] Add authentication token management
- [ ] Implement error handling and retry logic
- [ ] Create network reachability monitoring

### API Endpoints
- [ ] Implement authentication endpoints
- [ ] Create club management API calls
- [ ] Add member management endpoints
- [ ] Implement match and tournament APIs
- [ ] Create financial transaction endpoints
- [ ] Add store and order management APIs

### Data Synchronization
- [ ] Implement offline data caching
- [ ] Create background sync mechanisms
- [ ] Add conflict resolution strategies
- [ ] Implement real-time updates
- [ ] Create data validation and integrity checks
- [ ] Add incremental sync capabilities

## Core Networking Layer

### API Service Configuration
```swift
import Foundation
import Combine

protocol APIServiceProtocol {
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) -> AnyPublisher<T, APIError>

    func requestWithProgress<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) -> AnyPublisher<(T?, Progress), APIError>

    func upload<T: Decodable>(
        endpoint: APIEndpoint,
        data: Data,
        responseType: T.Type
    ) -> AnyPublisher<T, APIError>

    func download(
        endpoint: APIEndpoint,
        destination: URL
    ) -> AnyPublisher<URL, APIError>
}

class APIService: APIServiceProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let authenticationStore: AuthenticationStore
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()

    // Request interceptors
    private var requestInterceptors: [RequestInterceptor] = []
    private var responseInterceptors: [ResponseInterceptor] = []

    init(
        configuration: URLSessionConfiguration = .default,
        baseURL: URL = URL(string: Environment.current.apiBaseURL)!,
        authenticationStore: AuthenticationStore,
        networkMonitor: NetworkMonitor
    ) {
        self.session = URLSession(configuration: configuration)
        self.baseURL = baseURL
        self.authenticationStore = authenticationStore
        self.networkMonitor = networkMonitor

        setupDefaultInterceptors()
        setupSessionConfiguration()
    }

    func request<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) -> AnyPublisher<T, APIError> {

        // Check network connectivity
        guard networkMonitor.isConnected else {
            return Fail(error: APIError.networkUnavailable)
                .eraseToAnyPublisher()
        }

        // Build request
        guard let request = buildURLRequest(for: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        // Apply request interceptors
        let interceptedRequest = applyRequestInterceptors(request, endpoint: endpoint)

        return session.dataTaskPublisher(for: interceptedRequest)
            .tryMap { [weak self] data, response in
                try self?.processResponse(data: data, response: response, endpoint: endpoint) ?? data
            }
            .decode(type: T.self, decoder: JSONDecoder.apiDecoder)
            .mapError { error in
                self.mapError(error, endpoint: endpoint)
            }
            .retry(endpoint.retryCount)
            .eraseToAnyPublisher()
    }

    func requestWithProgress<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) -> AnyPublisher<(T?, Progress), APIError> {

        // Implementation for requests with progress tracking
        // Useful for large file uploads/downloads

        return Empty<(T?, Progress), APIError>()
            .eraseToAnyPublisher()
    }

    func upload<T: Decodable>(
        endpoint: APIEndpoint,
        data: Data,
        responseType: T.Type
    ) -> AnyPublisher<T, APIError> {

        guard var request = buildURLRequest(for: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response in
                try self?.processResponse(data: data, response: response, endpoint: endpoint) ?? data
            }
            .decode(type: T.self, decoder: JSONDecoder.apiDecoder)
            .mapError { error in
                self.mapError(error, endpoint: endpoint)
            }
            .eraseToAnyPublisher()
    }

    func download(
        endpoint: APIEndpoint,
        destination: URL
    ) -> AnyPublisher<URL, APIError> {

        guard let request = buildURLRequest(for: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        return session.downloadTaskPublisher(for: request)
            .tryMap { tempURL, response in
                // Move file to destination
                try FileManager.default.moveItem(at: tempURL, to: destination)
                return destination
            }
            .mapError { error in
                self.mapError(error, endpoint: endpoint)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Private Methods

    private func buildURLRequest(for endpoint: APIEndpoint) -> URLRequest? {
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout

        // Set headers
        endpoint.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Set authentication header
        if endpoint.requiresAuthentication, let token = authenticationStore.currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Set request body
        if let parameters = endpoint.parameters {
            switch endpoint.encoding {
            case .json:
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
            case .urlEncoded:
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = parameters.urlEncodedData
            }
        }

        return request
    }

    private func processResponse(
        data: Data,
        response: URLResponse,
        endpoint: APIEndpoint
    ) throws -> Data {

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Apply response interceptors
        applyResponseInterceptors(data: data, response: httpResponse, endpoint: endpoint)

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            // Token might be expired, attempt refresh
            handleUnauthorized()
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.tooManyRequests
        case 400...499:
            throw APIError.clientError(httpResponse.statusCode, parseErrorMessage(from: data))
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode, parseErrorMessage(from: data))
        default:
            throw APIError.unknown
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.message
    }

    private func handleUnauthorized() {
        // Attempt token refresh
        authenticationStore.refreshTokenIfNeeded()
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        // Token refresh failed, redirect to login
                        NotificationCenter.default.post(name: .userNeedsReauthentication, object: nil)
                    }
                },
                receiveValue: { _ in
                    // Token refreshed successfully
                }
            )
            .store(in: &cancellables)
    }

    private func mapError(_ error: Error, endpoint: APIEndpoint) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }

        if error is DecodingError {
            return APIError.decodingError("Failed to decode response for \(endpoint.path)")
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return APIError.networkUnavailable
            case .timedOut:
                return APIError.timeout
            default:
                return APIError.networkError(urlError.localizedDescription)
            }
        }

        return APIError.unknown
    }

    private func setupDefaultInterceptors() {
        // Add logging interceptor
        requestInterceptors.append(LoggingRequestInterceptor())
        responseInterceptors.append(LoggingResponseInterceptor())

        // Add analytics interceptor
        requestInterceptors.append(AnalyticsRequestInterceptor())
        responseInterceptors.append(AnalyticsResponseInterceptor())
    }

    private func setupSessionConfiguration() {
        // Configure caching
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB
            diskCapacity: 200 * 1024 * 1024,  // 200MB
            diskPath: "api_cache"
        )
        URLCache.shared = cache
    }

    private func applyRequestInterceptors(_ request: URLRequest, endpoint: APIEndpoint) -> URLRequest {
        return requestInterceptors.reduce(request) { result, interceptor in
            interceptor.intercept(request: result, endpoint: endpoint)
        }
    }

    private func applyResponseInterceptors(data: Data, response: HTTPURLResponse, endpoint: APIEndpoint) {
        responseInterceptors.forEach { interceptor in
            interceptor.intercept(data: data, response: response, endpoint: endpoint)
        }
    }
}
```

### API Endpoints Definition
```swift
enum APIEndpoint {
    // Authentication
    case sendOTP(phoneNumber: String)
    case verifyOTP(phoneNumber: String, otp: String)
    case refreshToken(refreshToken: String)
    case logout

    // User Management
    case getUserProfile
    case updateUserProfile(UpdateProfileRequest)
    case uploadProfileImage(Data)

    // Club Management
    case getUserClubs
    case getClubDetails(clubId: String)
    case createClub(CreateClubRequest)
    case updateClub(clubId: String, UpdateClubRequest)
    case joinClub(clubId: String, inviteCode: String?)
    case leaveClub(clubId: String)

    // Member Management
    case getClubMembers(clubId: String, page: Int, limit: Int)
    case getMemberDetails(clubId: String, memberId: String)
    case inviteMember(clubId: String, InviteMemberRequest)
    case updateMemberRole(clubId: String, memberId: String, role: String)
    case removeMember(clubId: String, memberId: String)

    // Match Management
    case getMatches(clubId: String, filters: MatchFilters)
    case getMatchDetails(matchId: String)
    case createMatch(clubId: String, CreateMatchRequest)
    case updateMatch(matchId: String, UpdateMatchRequest)
    case deleteMatch(matchId: String)
    case joinMatch(matchId: String)
    case leaveMatch(matchId: String)

    // Financial
    case getTransactions(filters: TransactionFilters)
    case getTransactionDetails(transactionId: String)
    case createPayment(CreatePaymentRequest)
    case getWalletBalance
    case addMoney(AddMoneyRequest)

    // Store & Orders
    case getStoreProducts(clubId: String, category: String?)
    case getProductDetails(productId: String)
    case createOrder(CreateOrderRequest)
    case getOrders(filters: OrderFilters)
    case getOrderDetails(orderId: String)
    case cancelOrder(orderId: String)

    // Notifications
    case getNotifications(page: Int, limit: Int)
    case markNotificationRead(notificationId: String)
    case markAllNotificationsRead
    case updateNotificationSettings(NotificationSettings)

    // Admin endpoints
    case getClubStats(clubId: String)
    case getFinancialSummary(clubId: String)
    case getSystemHealth
    case exportData(clubId: String, type: ExportType)

    var path: String {
        switch self {
        case .sendOTP:
            return "/auth/send-otp"
        case .verifyOTP:
            return "/auth/verify-otp"
        case .refreshToken:
            return "/auth/refresh"
        case .logout:
            return "/auth/logout"

        case .getUserProfile:
            return "/user/profile"
        case .updateUserProfile:
            return "/user/profile"
        case .uploadProfileImage:
            return "/user/profile/image"

        case .getUserClubs:
            return "/clubs"
        case .getClubDetails(let clubId):
            return "/clubs/\(clubId)"
        case .createClub:
            return "/clubs"
        case .updateClub(let clubId, _):
            return "/clubs/\(clubId)"
        case .joinClub(let clubId, _):
            return "/clubs/\(clubId)/join"
        case .leaveClub(let clubId):
            return "/clubs/\(clubId)/leave"

        case .getClubMembers(let clubId, _, _):
            return "/clubs/\(clubId)/members"
        case .getMemberDetails(let clubId, let memberId):
            return "/clubs/\(clubId)/members/\(memberId)"
        case .inviteMember(let clubId, _):
            return "/clubs/\(clubId)/members/invite"
        case .updateMemberRole(let clubId, let memberId, _):
            return "/clubs/\(clubId)/members/\(memberId)/role"
        case .removeMember(let clubId, let memberId):
            return "/clubs/\(clubId)/members/\(memberId)"

        case .getMatches(let clubId, _):
            return "/clubs/\(clubId)/matches"
        case .getMatchDetails(let matchId):
            return "/matches/\(matchId)"
        case .createMatch(let clubId, _):
            return "/clubs/\(clubId)/matches"
        case .updateMatch(let matchId, _):
            return "/matches/\(matchId)"
        case .deleteMatch(let matchId):
            return "/matches/\(matchId)"
        case .joinMatch(let matchId):
            return "/matches/\(matchId)/join"
        case .leaveMatch(let matchId):
            return "/matches/\(matchId)/leave"

        case .getTransactions:
            return "/transactions"
        case .getTransactionDetails(let transactionId):
            return "/transactions/\(transactionId)"
        case .createPayment:
            return "/payments"
        case .getWalletBalance:
            return "/wallet/balance"
        case .addMoney:
            return "/wallet/add-money"

        case .getStoreProducts(let clubId, _):
            return "/clubs/\(clubId)/store/products"
        case .getProductDetails(let productId):
            return "/store/products/\(productId)"
        case .createOrder:
            return "/store/orders"
        case .getOrders:
            return "/store/orders"
        case .getOrderDetails(let orderId):
            return "/store/orders/\(orderId)"
        case .cancelOrder(let orderId):
            return "/store/orders/\(orderId)/cancel"

        case .getNotifications:
            return "/notifications"
        case .markNotificationRead(let notificationId):
            return "/notifications/\(notificationId)/read"
        case .markAllNotificationsRead:
            return "/notifications/read-all"
        case .updateNotificationSettings:
            return "/notifications/settings"

        case .getClubStats(let clubId):
            return "/admin/clubs/\(clubId)/stats"
        case .getFinancialSummary(let clubId):
            return "/admin/clubs/\(clubId)/financial-summary"
        case .getSystemHealth:
            return "/admin/system/health"
        case .exportData(let clubId, _):
            return "/admin/clubs/\(clubId)/export"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .sendOTP, .verifyOTP, .createClub, .joinClub, .inviteMember, .createMatch, .createPayment, .addMoney, .createOrder:
            return .POST
        case .updateUserProfile, .uploadProfileImage, .updateClub, .updateMemberRole, .updateMatch, .updateNotificationSettings:
            return .PUT
        case .logout, .leaveClub, .removeMember, .deleteMatch, .leaveMatch, .cancelOrder:
            return .DELETE
        case .markNotificationRead, .markAllNotificationsRead:
            return .PATCH
        default:
            return .GET
        }
    }

    var headers: [String: String] {
        var headers: [String: String] = [:]

        switch self {
        case .uploadProfileImage:
            headers["Content-Type"] = "multipart/form-data"
        default:
            headers["Content-Type"] = "application/json"
        }

        headers["Accept"] = "application/json"
        headers["X-App-Version"] = Bundle.main.appVersion
        headers["X-Platform"] = "iOS"

        return headers
    }

    var parameters: [String: Any]? {
        switch self {
        case .sendOTP(let phoneNumber):
            return ["phoneNumber": phoneNumber]
        case .verifyOTP(let phoneNumber, let otp):
            return ["phoneNumber": phoneNumber, "otp": otp]
        case .refreshToken(let refreshToken):
            return ["refreshToken": refreshToken]
        case .updateUserProfile(let request):
            return request.toDictionary()
        case .createClub(let request):
            return request.toDictionary()
        case .updateClub(_, let request):
            return request.toDictionary()
        case .joinClub(_, let inviteCode):
            return inviteCode.map { ["inviteCode": $0] }
        case .inviteMember(_, let request):
            return request.toDictionary()
        case .updateMemberRole(_, _, let role):
            return ["role": role]
        case .getClubMembers(_, let page, let limit):
            return ["page": page, "limit": limit]
        case .getMatches(_, let filters):
            return filters.toDictionary()
        case .createMatch(_, let request):
            return request.toDictionary()
        case .updateMatch(_, let request):
            return request.toDictionary()
        case .getTransactions(let filters):
            return filters.toDictionary()
        case .createPayment(let request):
            return request.toDictionary()
        case .addMoney(let request):
            return request.toDictionary()
        case .getStoreProducts(_, let category):
            return category.map { ["category": $0] }
        case .createOrder(let request):
            return request.toDictionary()
        case .getOrders(let filters):
            return filters.toDictionary()
        case .getNotifications(let page, let limit):
            return ["page": page, "limit": limit]
        case .updateNotificationSettings(let settings):
            return settings.toDictionary()
        case .exportData(_, let type):
            return ["type": type.rawValue]
        default:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .sendOTP, .verifyOTP:
            return false
        default:
            return true
        }
    }

    var encoding: ParameterEncoding {
        switch method {
        case .GET, .DELETE:
            return .urlEncoded
        default:
            return .json
        }
    }

    var timeout: TimeInterval {
        switch self {
        case .uploadProfileImage, .exportData:
            return 60.0 // 1 minute for uploads/exports
        default:
            return 30.0 // 30 seconds default
        }
    }

    var retryCount: Int {
        switch self {
        case .sendOTP, .verifyOTP, .createPayment:
            return 0 // Don't retry sensitive operations
        default:
            return 2
        }
    }

    var cachePolicy: URLRequest.CachePolicy {
        switch self {
        case .getUserProfile, .getClubDetails, .getProductDetails:
            return .returnCacheDataElseLoad
        case .getMatches, .getTransactions, .getNotifications:
            return .reloadRevalidatingCacheData
        default:
            return .reloadIgnoringLocalCacheData
        }
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

enum ParameterEncoding {
    case json
    case urlEncoded
}
```

### Error Handling
```swift
enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case tooManyRequests
    case clientError(Int, String?)
    case serverError(Int, String?)
    case networkUnavailable
    case networkError(String)
    case timeout
    case decodingError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .tooManyRequests:
            return "Too many requests. Please try again later."
        case .clientError(let code, let message):
            return message ?? "Client error (\(code))"
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .networkUnavailable:
            return "No internet connection"
        case .networkError(let message):
            return "Network error: \(message)"
        case .timeout:
            return "Request timed out"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .unknown:
            return "An unknown error occurred"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable, .networkError, .timeout:
            return "Please check your internet connection and try again."
        case .unauthorized:
            return "Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .tooManyRequests:
            return "Please wait a moment before trying again."
        case .serverError:
            return "Our servers are experiencing issues. Please try again later."
        default:
            return "Please try again. If the problem persists, contact support."
        }
    }

    var shouldRetry: Bool {
        switch self {
        case .networkUnavailable, .networkError, .timeout, .serverError:
            return true
        case .unauthorized, .forbidden, .notFound, .clientError, .decodingError:
            return false
        default:
            return false
        }
    }
}

struct ErrorResponse: Codable {
    let error: String
    let message: String
    let code: String?
    let details: [String: Any]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decode(String.self, forKey: .error)
        message = try container.decode(String.self, forKey: .message)
        code = try container.decodeIfPresent(String.self, forKey: .code)

        // Decode details as a flexible dictionary
        if container.contains(.details) {
            let detailsContainer = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: .details)
            var detailsDict = [String: Any]()

            for key in detailsContainer.allKeys {
                if let stringValue = try? detailsContainer.decode(String.self, forKey: key) {
                    detailsDict[key.stringValue] = stringValue
                } else if let intValue = try? detailsContainer.decode(Int.self, forKey: key) {
                    detailsDict[key.stringValue] = intValue
                } else if let doubleValue = try? detailsContainer.decode(Double.self, forKey: key) {
                    detailsDict[key.stringValue] = doubleValue
                } else if let boolValue = try? detailsContainer.decode(Bool.self, forKey: key) {
                    detailsDict[key.stringValue] = boolValue
                }
            }
            details = detailsDict
        } else {
            details = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case error, message, code, details
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }
}
```

## Request/Response Models

### Authentication Models
```swift
struct SendOTPResponse: Codable {
    let success: Bool
    let message: String
    let otpId: String
    let expiresAt: Date
    let retryAfter: TimeInterval?
}

struct VerifyOTPResponse: Codable {
    let success: Bool
    let user: UserDTO
    let tokens: AuthTokens
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tokenType: String
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
    let expiresAt: Date
}
```

### User Models
```swift
struct UserDTO: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String?
    let phoneNumber: String
    let profileImageURL: String?
    let dateOfBirth: Date?
    let gender: String?
    let role: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    func toDomain() -> User {
        return User(
            id: id,
            name: "\(firstName) \(lastName)",
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            profileImageURL: profileImageURL,
            dateOfBirth: dateOfBirth,
            gender: gender.flatMap(Gender.init),
            role: UserRole(rawValue: role) ?? .member,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct UpdateProfileRequest: Codable {
    let firstName: String
    let lastName: String
    let email: String?
    let dateOfBirth: Date?
    let gender: String?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName
        ]

        if let email = email {
            dict["email"] = email
        }
        if let dateOfBirth = dateOfBirth {
            dict["dateOfBirth"] = ISO8601DateFormatter().string(from: dateOfBirth)
        }
        if let gender = gender {
            dict["gender"] = gender
        }

        return dict
    }
}
```

### Club Models
```swift
struct ClubDTO: Codable {
    let id: String
    let name: String
    let description: String?
    let logoURL: String?
    let bannerURL: String?
    let location: LocationDTO?
    let memberCount: Int
    let maxMembers: Int?
    let isPublic: Bool
    let inviteCode: String?
    let settings: ClubSettingsDTO
    let userRole: String?
    let createdAt: Date
    let updatedAt: Date

    func toDomain() -> Club {
        return Club(
            id: id,
            name: name,
            description: description,
            logoURL: logoURL,
            bannerURL: bannerURL,
            location: location?.toDomain(),
            memberCount: memberCount,
            maxMembers: maxMembers,
            isPublic: isPublic,
            inviteCode: inviteCode,
            settings: settings.toDomain(),
            userRole: userRole.flatMap(ClubRole.init),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct CreateClubRequest: Codable {
    let name: String
    let description: String?
    let isPublic: Bool
    let maxMembers: Int?
    let location: CreateLocationRequest?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "isPublic": isPublic
        ]

        if let description = description {
            dict["description"] = description
        }
        if let maxMembers = maxMembers {
            dict["maxMembers"] = maxMembers
        }
        if let location = location {
            dict["location"] = location.toDictionary()
        }

        return dict
    }
}

struct LocationDTO: Codable {
    let address: String
    let city: String
    let state: String
    let country: String
    let postalCode: String?
    let latitude: Double?
    let longitude: Double?

    func toDomain() -> Location {
        return Location(
            address: address,
            city: city,
            state: state,
            country: country,
            postalCode: postalCode,
            coordinate: (latitude != nil && longitude != nil) ?
                CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!) : nil
        )
    }
}
```

## Data Synchronization

### Offline Cache Manager
```swift
protocol CacheManagerProtocol {
    func cache<T: Codable>(_ object: T, forKey key: String, expiryTime: TimeInterval?)
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    func remove(forKey key: String)
    func removeExpired()
    func clear()
}

class CacheManager: CacheManagerProtocol {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let expiryManager: CacheExpiryManager

    init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("Cache")
        expiryManager = CacheExpiryManager()

        createCacheDirectoryIfNeeded()
    }

    func cache<T: Codable>(_ object: T, forKey key: String, expiryTime: TimeInterval? = nil) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")

        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: fileURL)

            if let expiryTime = expiryTime {
                expiryManager.setExpiry(forKey: key, expiryTime: expiryTime)
            }
        } catch {
            print("Failed to cache object for key \(key): \(error)")
        }
    }

    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // Check if cache has expired
        if expiryManager.hasExpired(key: key) {
            remove(forKey: key)
            return nil
        }

        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to retrieve cached object for key \(key): \(error)")
            return nil
        }
    }

    func remove(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
        expiryManager.removeExpiry(forKey: key)
    }

    func removeExpired() {
        let expiredKeys = expiryManager.getExpiredKeys()
        expiredKeys.forEach { remove(forKey: $0) }
    }

    func clear() {
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
        expiryManager.clearAll()
    }

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
}

class CacheExpiryManager {
    private let userDefaults = UserDefaults.standard
    private let expiryKeyPrefix = "cache_expiry_"

    func setExpiry(forKey key: String, expiryTime: TimeInterval) {
        let expiryDate = Date().addingTimeInterval(expiryTime)
        userDefaults.set(expiryDate, forKey: expiryKeyPrefix + key)
    }

    func hasExpired(key: String) -> Bool {
        guard let expiryDate = userDefaults.object(forKey: expiryKeyPrefix + key) as? Date else {
            return false
        }
        return Date() > expiryDate
    }

    func removeExpiry(forKey key: String) {
        userDefaults.removeObject(forKey: expiryKeyPrefix + key)
    }

    func getExpiredKeys() -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let expiryKeys = allKeys.filter { $0.hasPrefix(expiryKeyPrefix) }

        return expiryKeys.compactMap { key in
            let cacheKey = String(key.dropFirst(expiryKeyPrefix.count))
            return hasExpired(key: cacheKey) ? cacheKey : nil
        }
    }

    func clearAll() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let expiryKeys = allKeys.filter { $0.hasPrefix(expiryKeyPrefix) }
        expiryKeys.forEach { userDefaults.removeObject(forKey: $0) }
    }
}
```

### Background Sync Service
```swift
protocol BackgroundSyncServiceProtocol {
    func scheduleSync()
    func performSync() -> AnyPublisher<Void, Error>
    func addToSyncQueue(_ operation: SyncOperation)
}

class BackgroundSyncService: BackgroundSyncServiceProtocol {
    private let apiService: APIServiceProtocol
    private let cacheManager: CacheManagerProtocol
    private let syncQueue: SyncQueue
    private var cancellables = Set<AnyCancellable>()

    init(
        apiService: APIServiceProtocol,
        cacheManager: CacheManagerProtocol
    ) {
        self.apiService = apiService
        self.cacheManager = cacheManager
        self.syncQueue = SyncQueue()

        setupBackgroundSync()
    }

    func scheduleSync() {
        // Schedule background app refresh
        let request = BGAppRefreshTaskRequest(identifier: "com.duggy.background-sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        try? BGTaskScheduler.shared.submit(request)
    }

    func performSync() -> AnyPublisher<Void, Error> {
        let operations = syncQueue.getPendingOperations()

        let publishers = operations.map { operation in
            performSyncOperation(operation)
                .handleEvents(receiveOutput: { _ in
                    self.syncQueue.markCompleted(operation)
                })
                .catch { error in
                    // Handle sync failures
                    self.handleSyncFailure(operation, error: error)
                    return Just(()).setFailureType(to: Error.self)
                }
        }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func addToSyncQueue(_ operation: SyncOperation) {
        syncQueue.add(operation)
    }

    private func performSyncOperation(_ operation: SyncOperation) -> AnyPublisher<Void, Error> {
        switch operation.type {
        case .upload:
            return performUploadOperation(operation)
        case .download:
            return performDownloadOperation(operation)
        case .delete:
            return performDeleteOperation(operation)
        }
    }

    private func performUploadOperation(_ operation: SyncOperation) -> AnyPublisher<Void, Error> {
        // Implementation for upload operations
        return Empty<Void, Error>()
            .eraseToAnyPublisher()
    }

    private func performDownloadOperation(_ operation: SyncOperation) -> AnyPublisher<Void, Error> {
        // Implementation for download operations
        return Empty<Void, Error>()
            .eraseToAnyPublisher()
    }

    private func performDeleteOperation(_ operation: SyncOperation) -> AnyPublisher<Void, Error> {
        // Implementation for delete operations
        return Empty<Void, Error>()
            .eraseToAnyPublisher()
    }

    private func handleSyncFailure(_ operation: SyncOperation, error: Error) {
        operation.incrementRetryCount()

        if operation.retryCount < operation.maxRetries {
            // Re-queue for retry
            syncQueue.add(operation)
        } else {
            // Mark as failed permanently
            syncQueue.markFailed(operation)
        }
    }

    private func setupBackgroundSync() {
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.duggy.background-sync", using: nil) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }

        // Schedule periodic sync
        Timer.publish(every: 300, on: .main, in: .common) // 5 minutes
            .autoconnect()
            .sink { _ in
                self.performPeriodicSync()
            }
            .store(in: &cancellables)
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        scheduleSync() // Schedule next background sync

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        performSync()
            .sink(
                receiveCompletion: { completion in
                    task.setTaskCompleted(success: completion == .finished)
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }

    private func performPeriodicSync() {
        guard UIApplication.shared.applicationState == .active else { return }

        performSync()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Periodic sync failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("Periodic sync completed successfully")
                }
            )
            .store(in: &cancellables)
    }
}

struct SyncOperation {
    let id: String
    let type: SyncOperationType
    let endpoint: APIEndpoint
    let data: Data?
    let priority: SyncPriority
    var retryCount: Int = 0
    let maxRetries: Int = 3
    let createdAt: Date = Date()

    mutating func incrementRetryCount() {
        retryCount += 1
    }
}

enum SyncOperationType {
    case upload
    case download
    case delete
}

enum SyncPriority {
    case low
    case normal
    case high
    case critical
}

class SyncQueue {
    private var operations: [SyncOperation] = []
    private let queue = DispatchQueue(label: "sync-queue", qos: .utility)

    func add(_ operation: SyncOperation) {
        queue.async {
            self.operations.append(operation)
            self.operations.sort { $0.priority.rawValue > $1.priority.rawValue }
        }
    }

    func getPendingOperations() -> [SyncOperation] {
        return queue.sync {
            return operations.filter { $0.retryCount < $0.maxRetries }
        }
    }

    func markCompleted(_ operation: SyncOperation) {
        queue.async {
            self.operations.removeAll { $0.id == operation.id }
        }
    }

    func markFailed(_ operation: SyncOperation) {
        queue.async {
            self.operations.removeAll { $0.id == operation.id }
        }
    }
}

extension SyncPriority {
    var rawValue: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .normal: return 2
        case .low: return 1
        }
    }
}
```

## JSON Decoder Extensions

### API JSON Decoder
```swift
extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

extension JSONEncoder {
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
```

## Utility Extensions

### Dictionary Extensions
```swift
extension Dictionary where Key == String, Value == Any {
    var urlEncodedData: Data? {
        let encodedString = self.compactMap { key, value in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        return encodedString.data(using: .utf8)
    }
}

extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
```

## API Integration Implementation Tasks

### Core Networking Tasks
- [ ] Create APIService with URLSession and Combine
- [ ] Implement APIEndpoint enumeration with all endpoints
- [ ] Add request/response interceptors for logging and analytics
- [ ] Create comprehensive error handling system
- [ ] Implement authentication token management
- [ ] Add network connectivity monitoring

### Request/Response Tasks
- [ ] Create all DTO models for API responses
- [ ] Implement domain model mapping from DTOs
- [ ] Add request model builders with validation
- [ ] Create parameter encoding utilities
- [ ] Implement file upload/download capabilities
- [ ] Add request/response serialization

### Caching Tasks
- [ ] Implement CacheManager for offline data
- [ ] Create cache expiry management system
- [ ] Add intelligent cache invalidation
- [ ] Implement cache size management
- [ ] Create cache performance optimization
- [ ] Add cache analytics and monitoring

### Background Sync Tasks
- [ ] Create BackgroundSyncService
- [ ] Implement sync operation queue
- [ ] Add conflict resolution strategies
- [ ] Create retry mechanisms with exponential backoff
- [ ] Implement priority-based sync scheduling
- [ ] Add sync progress monitoring

### Testing Tasks
- [ ] Create mock API service for testing
- [ ] Implement network simulation for testing
- [ ] Add API integration tests
- [ ] Create performance testing for API calls
- [ ] Implement offline scenario testing
- [ ] Add error handling validation tests

This comprehensive API integration layer provides robust networking capabilities with offline support, intelligent caching, and background synchronization for the entire iOS app.