# Home Dashboard Implementation

## Overview
Complete implementation guide for the main dashboard screen showing club overview, quick stats, recent activities, and navigation to all major features.

## 🎯 Dashboard Tasks

### UI Implementation
- [ ] Create responsive dashboard layout
- [ ] Implement quick stats cards with animations
- [ ] Add recent activities feed
- [ ] Create quick action buttons
- [ ] Implement pull-to-refresh functionality
- [ ] Add skeleton loading states

### Data Integration
- [ ] Integrate club overview API
- [ ] Implement real-time data updates
- [ ] Create local data caching
- [ ] Add offline data handling
- [ ] Implement background sync
- [ ] Create data refresh mechanisms

### Navigation
- [ ] Implement quick navigation to features
- [ ] Add deep link handling
- [ ] Create contextual action menus
- [ ] Implement tab bar integration
- [ ] Add floating action button
- [ ] Create notification handling

## UI Implementation

### Home Dashboard View
```swift
struct HomeDashboardView: View {
    @StateObject private var viewModel = HomeDashboardViewModel()
    @EnvironmentObject var navigationStore: NavigationStore
    @EnvironmentObject var userStore: UserStore

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header Section
                    headerSection

                    // Quick Stats Cards
                    quickStatsSection

                    // Upcoming Matches
                    upcomingMatchesSection

                    // Recent Activities
                    recentActivitiesSection

                    // Quick Actions
                    quickActionsSection

                    // Club News
                    clubNewsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadDashboardData()
        }
        .sheet(item: $viewModel.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("Retry") {
                viewModel.loadDashboardData()
            }
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // User Greeting and Profile
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(viewModel.greetingTime)")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)

                    Text(userStore.currentUser?.firstName ?? "Player")
                        .font(.headline2)
                        .foregroundColor(.textPrimary)
                        .fontWeight(.bold)
                }

                Spacer()

                // Profile Picture and Notifications
                HStack(spacing: 12) {
                    // Notification Bell
                    Button(action: {
                        navigationStore.navigate(to: .notifications)
                    }) {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.title3)
                                .foregroundColor(.textPrimary)

                            if viewModel.unreadNotificationsCount > 0 {
                                NotificationBadge(count: viewModel.unreadNotificationsCount)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }

                    // Profile Picture
                    Button(action: {
                        navigationStore.selectedTab = .profile
                    }) {
                        AsyncImage(url: URL(string: userStore.currentUser?.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.textSecondary)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    }
                }
            }

            // Club Selector (if user is in multiple clubs)
            if viewModel.userClubs.count > 1 {
                ClubSelectorView(
                    clubs: viewModel.userClubs,
                    selectedClub: $viewModel.selectedClub
                )
            }
        }
    }

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Overview")
                .font(.headline3)
                .foregroundColor(.textPrimary)

            if viewModel.isLoadingStats {
                QuickStatsSkeletonView()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    QuickStatCard(
                        icon: "person.3.fill",
                        title: "Members",
                        value: "\(viewModel.dashboardStats?.memberCount ?? 0)",
                        color: .primaryBlue,
                        action: { navigationStore.navigate(to: .clubMembers) }
                    )

                    QuickStatCard(
                        icon: "sportscourt.fill",
                        title: "Matches",
                        value: "\(viewModel.dashboardStats?.upcomingMatches ?? 0)",
                        color: .successGreen,
                        action: { navigationStore.selectedTab = .matches }
                    )

                    QuickStatCard(
                        icon: "indianrupeesign.circle.fill",
                        title: "Balance",
                        value: "₹\(viewModel.dashboardStats?.balance ?? 0)",
                        color: .lightBlue,
                        action: { navigationStore.selectedTab = .wallet }
                    )

                    QuickStatCard(
                        icon: "bag.fill",
                        title: "Orders",
                        value: "\(viewModel.dashboardStats?.pendingOrders ?? 0)",
                        color: .warningOrange,
                        action: { navigationStore.navigate(to: .myOrders) }
                    )
                }
            }
        }
    }

    private var upcomingMatchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Matches")
                    .font(.headline3)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("View All") {
                    navigationStore.selectedTab = .matches
                }
                .font(.bodyMedium)
                .foregroundColor(.primaryBlue)
            }

            if viewModel.isLoadingMatches {
                MatchSkeletonView()
            } else if viewModel.upcomingMatches.isEmpty {
                EmptyStateView(
                    icon: "sportscourt",
                    title: "No Upcoming Matches",
                    message: "Check back later for new matches"
                )
                .frame(height: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.upcomingMatches.prefix(5), id: \.id) { match in
                            CompactMatchCard(match: match) {
                                navigationStore.navigate(to: .matchDetail(matchId: match.id))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
        }
    }

    private var recentActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activities")
                    .font(.headline3)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("View All") {
                    viewModel.presentedSheet = .activities
                }
                .font(.bodyMedium)
                .foregroundColor(.primaryBlue)
            }

            if viewModel.isLoadingActivities {
                ActivitySkeletonView()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentActivities.prefix(3), id: \.id) { activity in
                        ActivityRowView(activity: activity) {
                            handleActivityTap(activity)
                        }
                    }
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline3)
                .foregroundColor(.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Create Match",
                    color: .primaryBlue
                ) {
                    viewModel.presentedSheet = .createMatch
                }

                QuickActionButton(
                    icon: "person.badge.plus",
                    title: "Add Member",
                    color: .successGreen
                ) {
                    viewModel.presentedSheet = .addMember
                }

                QuickActionButton(
                    icon: "qrcode.viewfinder",
                    title: "Scan QR",
                    color: .lightBlue
                ) {
                    viewModel.presentedSheet = .qrScanner
                }

                QuickActionButton(
                    icon: "chart.bar.fill",
                    title: "Statistics",
                    color: .warningOrange
                ) {
                    navigationStore.navigate(to: .statistics)
                }
            }
        }
    }

    private var clubNewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Club News")
                    .font(.headline3)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("View All") {
                    navigationStore.navigate(to: .clubNews)
                }
                .font(.bodyMedium)
                .foregroundColor(.primaryBlue)
            }

            if viewModel.isLoadingNews {
                NewsSkeletonView()
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.clubNews.prefix(2), id: \.id) { news in
                        NewsCard(news: news) {
                            navigationStore.navigate(to: .newsDetail(newsId: news.id))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: DashboardSheet) -> some View {
        switch sheet {
        case .createMatch:
            CreateMatchView()
        case .addMember:
            AddMemberView()
        case .qrScanner:
            QRScannerView()
        case .activities:
            AllActivitiesView()
        }
    }

    private func handleActivityTap(_ activity: Activity) {
        switch activity.type {
        case .matchCreated:
            navigationStore.navigate(to: .matchDetail(matchId: activity.referenceId))
        case .memberJoined:
            navigationStore.navigate(to: .memberProfile(userId: activity.referenceId))
        case .orderPlaced:
            navigationStore.navigate(to: .orderDetail(orderId: activity.referenceId))
        case .paymentReceived:
            navigationStore.navigate(to: .transactionDetail(transactionId: activity.referenceId))
        }
    }
}
```

### Quick Stat Card Component
```swift
struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            StandardCard {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(value)
                            .font(.headline2)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text(title)
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
```

### Compact Match Card
```swift
struct CompactMatchCard: View {
    let match: Match
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            StandardCard(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
                VStack(alignment: .leading, spacing: 8) {
                    // Match Status
                    HStack {
                        StatusBadge(status: match.status)
                        Spacer()
                    }

                    // Teams
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.homeTeam?.name ?? "TBD")
                            .font(.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)

                        Text("vs")
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        Text(match.awayTeam?.name ?? "TBD")
                            .font(.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()

                    // Date and Time
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        Text(match.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.textPrimary)
                    }
                }
            }
        }
        .frame(width: 140, height: 120)
        .buttonStyle(PlainButtonStyle())
    }
}
```

### Quick Action Button
```swift
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())

                Text(title)
                    .font(.caption)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

### Activity Row View
```swift
struct ActivityRowView: View {
    let activity: Activity
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Activity Icon
                Image(systemName: activity.type.iconName)
                    .font(.title3)
                    .foregroundColor(activity.type.color)
                    .frame(width: 32, height: 32)
                    .background(activity.type.color.opacity(0.1))
                    .clipShape(Circle())

                // Activity Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title)
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(activity.subtitle)
                        .font(.bodySmall)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Timestamp
                Text(activity.timestamp.timeAgoDisplay)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

## ViewModel Implementation

### Home Dashboard ViewModel
```swift
@MainActor
class HomeDashboardViewModel: ObservableObject {
    @Published var dashboardStats: DashboardStats? = nil
    @Published var upcomingMatches: [Match] = []
    @Published var recentActivities: [Activity] = []
    @Published var clubNews: [News] = []
    @Published var userClubs: [Club] = []
    @Published var selectedClub: Club? = nil

    @Published var isLoadingStats = false
    @Published var isLoadingMatches = false
    @Published var isLoadingActivities = false
    @Published var isLoadingNews = false

    @Published var unreadNotificationsCount = 0
    @Published var presentedSheet: DashboardSheet? = nil
    @Published var showError = false
    @Published var errorMessage = ""

    private let dashboardUseCase: DashboardUseCaseProtocol
    private let clubUseCase: ClubUseCaseProtocol
    private let notificationUseCase: NotificationUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()

    var greetingTime: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
        }
    }

    init(
        dashboardUseCase: DashboardUseCaseProtocol = DependencyContainer.shared.dashboardUseCase,
        clubUseCase: ClubUseCaseProtocol = DependencyContainer.shared.clubUseCase,
        notificationUseCase: NotificationUseCaseProtocol = DependencyContainer.shared.notificationUseCase
    ) {
        self.dashboardUseCase = dashboardUseCase
        self.clubUseCase = clubUseCase
        self.notificationUseCase = notificationUseCase

        setupNotificationObservers()
    }

    func loadDashboardData() {
        loadUserClubs()
        loadDashboardStats()
        loadUpcomingMatches()
        loadRecentActivities()
        loadClubNews()
        loadUnreadNotificationsCount()
    }

    @MainActor
    func refreshData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshDashboardStats() }
            group.addTask { await self.refreshUpcomingMatches() }
            group.addTask { await self.refreshRecentActivities() }
            group.addTask { await self.refreshClubNews() }
            group.addTask { await self.refreshUnreadNotificationsCount() }
        }
    }

    private func loadUserClubs() {
        clubUseCase.getUserClubs()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to load user clubs: \(error)")
                    }
                },
                receiveValue: { [weak self] clubs in
                    self?.userClubs = clubs
                    self?.selectedClub = clubs.first
                }
            )
            .store(in: &cancellables)
    }

    private func loadDashboardStats() {
        guard let clubId = selectedClub?.id else { return }

        isLoadingStats = true

        dashboardUseCase.getDashboardStats(clubId: clubId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingStats = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] stats in
                    self?.dashboardStats = stats
                }
            )
            .store(in: &cancellables)
    }

    private func loadUpcomingMatches() {
        guard let clubId = selectedClub?.id else { return }

        isLoadingMatches = true

        dashboardUseCase.getUpcomingMatches(clubId: clubId, limit: 5)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingMatches = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] matches in
                    self?.upcomingMatches = matches
                }
            )
            .store(in: &cancellables)
    }

    private func loadRecentActivities() {
        guard let clubId = selectedClub?.id else { return }

        isLoadingActivities = true

        dashboardUseCase.getRecentActivities(clubId: clubId, limit: 3)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingActivities = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] activities in
                    self?.recentActivities = activities
                }
            )
            .store(in: &cancellables)
    }

    private func loadClubNews() {
        guard let clubId = selectedClub?.id else { return }

        isLoadingNews = true

        dashboardUseCase.getClubNews(clubId: clubId, limit: 2)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingNews = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] news in
                    self?.clubNews = news
                }
            )
            .store(in: &cancellables)
    }

    private func loadUnreadNotificationsCount() {
        notificationUseCase.getUnreadCount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to load notification count: \(error)")
                    }
                },
                receiveValue: { [weak self] count in
                    self?.unreadNotificationsCount = count
                }
            )
            .store(in: &cancellables)
    }

    // Async refresh methods
    private func refreshDashboardStats() async {
        guard let clubId = selectedClub?.id else { return }

        do {
            let stats = try await dashboardUseCase.getDashboardStats(clubId: clubId).async()
            await MainActor.run {
                self.dashboardStats = stats
            }
        } catch {
            await MainActor.run {
                self.handleError(error)
            }
        }
    }

    private func refreshUpcomingMatches() async {
        guard let clubId = selectedClub?.id else { return }

        do {
            let matches = try await dashboardUseCase.getUpcomingMatches(clubId: clubId, limit: 5).async()
            await MainActor.run {
                self.upcomingMatches = matches
            }
        } catch {
            print("Failed to refresh matches: \(error)")
        }
    }

    private func refreshRecentActivities() async {
        guard let clubId = selectedClub?.id else { return }

        do {
            let activities = try await dashboardUseCase.getRecentActivities(clubId: clubId, limit: 3).async()
            await MainActor.run {
                self.recentActivities = activities
            }
        } catch {
            print("Failed to refresh activities: \(error)")
        }
    }

    private func refreshClubNews() async {
        guard let clubId = selectedClub?.id else { return }

        do {
            let news = try await dashboardUseCase.getClubNews(clubId: clubId, limit: 2).async()
            await MainActor.run {
                self.clubNews = news
            }
        } catch {
            print("Failed to refresh news: \(error)")
        }
    }

    private func refreshUnreadNotificationsCount() async {
        do {
            let count = try await notificationUseCase.getUnreadCount().async()
            await MainActor.run {
                self.unreadNotificationsCount = count
            }
        } catch {
            print("Failed to refresh notification count: \(error)")
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .newNotificationReceived)
            .sink { [weak self] _ in
                self?.loadUnreadNotificationsCount()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .clubDataUpdated)
            .sink { [weak self] _ in
                self?.loadDashboardData()
            }
            .store(in: &cancellables)
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

enum DashboardSheet: Identifiable {
    case createMatch
    case addMember
    case qrScanner
    case activities

    var id: String {
        switch self {
        case .createMatch: return "createMatch"
        case .addMember: return "addMember"
        case .qrScanner: return "qrScanner"
        case .activities: return "activities"
        }
    }
}
```

## Data Models

### Dashboard Models
```swift
struct DashboardStats {
    let memberCount: Int
    let upcomingMatches: Int
    let balance: Double
    let pendingOrders: Int
    let totalMatches: Int
    let totalSpent: Double
}

struct Activity {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let timestamp: Date
    let referenceId: String
    let userId: String?
    let userName: String?
}

enum ActivityType {
    case matchCreated
    case memberJoined
    case orderPlaced
    case paymentReceived
    case newsPosted
    case pollCreated

    var iconName: String {
        switch self {
        case .matchCreated: return "sportscourt.fill"
        case .memberJoined: return "person.badge.plus"
        case .orderPlaced: return "bag.fill"
        case .paymentReceived: return "indianrupeesign.circle.fill"
        case .newsPosted: return "newspaper.fill"
        case .pollCreated: return "chart.bar.doc.horizontal"
        }
    }

    var color: Color {
        switch self {
        case .matchCreated: return .primaryBlue
        case .memberJoined: return .successGreen
        case .orderPlaced: return .warningOrange
        case .paymentReceived: return .lightBlue
        case .newsPosted: return .textPrimary
        case .pollCreated: return .chart2
        }
    }
}

struct News {
    let id: String
    let title: String
    let content: String
    let author: String
    let publishedAt: Date
    let imageURL: String?
    let isImportant: Bool
}
```

## Skeleton Views

### Loading States
```swift
struct QuickStatsSkeletonView: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                StandardCard {
                    VStack(spacing: 12) {
                        HStack {
                            ShimmerView()
                                .frame(width: 24, height: 24)
                                .cornerRadius(4)

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ShimmerView()
                                .frame(width: 60, height: 24)
                                .cornerRadius(4)

                            ShimmerView()
                                .frame(width: 80, height: 16)
                                .cornerRadius(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

struct MatchSkeletonView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    StandardCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ShimmerView()
                                .frame(width: 60, height: 20)
                                .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 4) {
                                ShimmerView()
                                    .frame(width: 100, height: 16)
                                    .cornerRadius(4)

                                ShimmerView()
                                    .frame(width: 20, height: 12)
                                    .cornerRadius(4)

                                ShimmerView()
                                    .frame(width: 100, height: 16)
                                    .cornerRadius(4)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 2) {
                                ShimmerView()
                                    .frame(width: 80, height: 12)
                                    .cornerRadius(4)

                                ShimmerView()
                                    .frame(width: 60, height: 12)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .frame(width: 140, height: 120)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }
}
```

## Dashboard Implementation Tasks

### Core UI Tasks
- [ ] Create HomeDashboardView with responsive layout
- [ ] Implement QuickStatCard components
- [ ] Build CompactMatchCard for horizontal scrolling
- [ ] Create ActivityRowView for activity feed
- [ ] Add QuickActionButton grid
- [ ] Implement ClubSelectorView for multi-club users

### Data Integration Tasks
- [ ] Create HomeDashboardViewModel with state management
- [ ] Implement DashboardUseCase for API integration
- [ ] Add real-time data updates with Combine
- [ ] Create local caching for offline support
- [ ] Implement pull-to-refresh functionality
- [ ] Add background data synchronization

### Loading States Tasks
- [ ] Create skeleton views for all sections
- [ ] Implement shimmer loading effects
- [ ] Add smooth transitions between loading and content
- [ ] Create error states with retry functionality
- [ ] Implement progressive loading for better UX
- [ ] Add loading indicators for individual sections

### Navigation Tasks
- [ ] Implement quick navigation to all features
- [ ] Add deep link handling for dashboard items
- [ ] Create contextual navigation based on user role
- [ ] Implement sheet presentations for quick actions
- [ ] Add notification badge and navigation
- [ ] Create smooth transitions between sections

### Performance Tasks
- [ ] Optimize image loading with AsyncImage
- [ ] Implement lazy loading for large lists
- [ ] Add memory management for dashboard data
- [ ] Optimize network requests with caching
- [ ] Implement efficient data refresh strategies
- [ ] Add performance monitoring and analytics

This dashboard provides a comprehensive overview of all club activities with smooth navigation and excellent user experience.