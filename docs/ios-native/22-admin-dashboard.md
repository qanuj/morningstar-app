# Admin Dashboard Implementation

## Overview
Complete implementation guide for the club owner/admin dashboard with comprehensive club management, analytics, and administrative features.

## 🎯 Admin Dashboard Tasks

### UI Implementation
- [ ] Create admin-specific dashboard layout
- [ ] Implement club statistics and metrics cards
- [ ] Add member management quick access
- [ ] Create financial overview widgets
- [ ] Implement recent activities feed
- [ ] Add administrative quick actions

### Data Integration
- [ ] Integrate club analytics API
- [ ] Implement real-time member statistics
- [ ] Create financial summary integration
- [ ] Add match management data
- [ ] Implement notification management
- [ ] Create audit trail functionality

### Administrative Features
- [ ] Implement role-based access control
- [ ] Create bulk operations interface
- [ ] Add system notifications
- [ ] Implement backup and export features
- [ ] Create club settings management
- [ ] Add compliance and reporting tools

## UI Implementation

### Admin Dashboard View
```swift
struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var navigationStore: NavigationStore

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Admin Header
                    adminHeaderSection

                    // Club Overview Cards
                    clubOverviewSection

                    // Financial Summary
                    financialSummarySection

                    // Member Management
                    memberManagementSection

                    // Recent Activities
                    recentActivitiesSection

                    // Quick Actions
                    adminQuickActionsSection

                    // System Health
                    systemHealthSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable {
                await viewModel.refreshDashboard()
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadAdminDashboard()
        }
        .sheet(item: $viewModel.presentedSheet) { sheet in
            adminSheetContent(for: sheet)
        }
        .alert("Admin Alert", isPresented: $viewModel.showAlert) {
            Button("OK") { }
            if viewModel.alertType == .critical {
                Button("Take Action") {
                    viewModel.handleCriticalAlert()
                }
            }
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    private var adminHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Club Administration")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)

                    Text(viewModel.clubName)
                        .font(.headline2)
                        .foregroundColor(.textPrimary)
                        .fontWeight(.bold)
                }

                Spacer()

                HStack(spacing: 12) {
                    // System Notifications
                    Button(action: {
                        viewModel.presentedSheet = .systemNotifications
                    }) {
                        ZStack {
                            Image(systemName: "bell.badge")
                                .font(.title3)
                                .foregroundColor(.textPrimary)

                            if viewModel.systemAlertsCount > 0 {
                                NotificationBadge(count: viewModel.systemAlertsCount)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }

                    // Club Settings
                    Button(action: {
                        navigationStore.navigate(to: .clubSettings)
                    }) {
                        Image(systemName: "gear")
                            .font(.title3)
                            .foregroundColor(.textPrimary)
                    }
                }
            }

            // Club Health Status
            ClubHealthIndicator(health: viewModel.clubHealth)
        }
    }

    private var clubOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Club Overview")
                .font(.headline3)
                .foregroundColor(.textPrimary)

            if viewModel.isLoadingOverview {
                AdminOverviewSkeletonView()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    AdminStatCard(
                        icon: "person.3.fill",
                        title: "Total Members",
                        value: "\(viewModel.clubStats?.totalMembers ?? 0)",
                        subtitle: "+\(viewModel.clubStats?.newMembersThisMonth ?? 0) this month",
                        color: .primaryBlue,
                        trend: viewModel.clubStats?.memberGrowthTrend ?? .stable,
                        action: {
                            navigationStore.navigate(to: .memberManagement)
                        }
                    )

                    AdminStatCard(
                        icon: "sportscourt.fill",
                        title: "Active Matches",
                        value: "\(viewModel.clubStats?.activeMatches ?? 0)",
                        subtitle: "\(viewModel.clubStats?.upcomingMatches ?? 0) upcoming",
                        color: .successGreen,
                        trend: viewModel.clubStats?.matchActivityTrend ?? .stable,
                        action: {
                            navigationStore.navigate(to: .matchManagement)
                        }
                    )

                    AdminStatCard(
                        icon: "indianrupeesign.circle.fill",
                        title: "Monthly Revenue",
                        value: "₹\(viewModel.clubStats?.monthlyRevenue ?? 0, specifier: "%.0f")",
                        subtitle: "₹\(viewModel.clubStats?.totalBalance ?? 0, specifier: "%.0f") total",
                        color: .lightBlue,
                        trend: viewModel.clubStats?.revenueTrend ?? .stable,
                        action: {
                            navigationStore.navigate(to: .financialDashboard)
                        }
                    )

                    AdminStatCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Pending Tasks",
                        value: "\(viewModel.clubStats?.pendingTasks ?? 0)",
                        subtitle: "\(viewModel.clubStats?.criticalTasks ?? 0) critical",
                        color: .warningOrange,
                        trend: .stable,
                        action: {
                            viewModel.presentedSheet = .pendingTasks
                        }
                    )
                }
            }
        }
    }

    private var financialSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Financial Summary")
                    .font(.headline3)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("View Details") {
                    navigationStore.navigate(to: .financialDashboard)
                }
                .font(.bodyMedium)
                .foregroundColor(.primaryBlue)
            }

            StandardCard {
                VStack(spacing: 16) {
                    // Revenue vs Expenses Chart
                    if let financialData = viewModel.financialSummary {
                        FinancialSummaryChart(data: financialData)
                            .frame(height: 120)
                    }

                    // Financial KPIs
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This Month")
                                .font(.caption)
                                .foregroundColor(.textSecondary)

                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.successGreen)
                                Text("₹\(viewModel.financialSummary?.monthlyIncome ?? 0, specifier: "%.0f")")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.errorRed)
                                Text("₹\(viewModel.financialSummary?.monthlyExpenses ?? 0, specifier: "%.0f")")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Net Profit")
                                .font(.caption)
                                .foregroundColor(.textSecondary)

                            Text("₹\(viewModel.financialSummary?.netProfit ?? 0, specifier: "%.0f")")
                                .font(.headline4)
                                .fontWeight(.bold)
                                .foregroundColor(viewModel.financialSummary?.netProfit ?? 0 >= 0 ? .successGreen : .errorRed)
                        }
                    }
                }
            }
        }
    }

    private var memberManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Member Management")
                    .font(.headline3)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Manage All") {
                    navigationStore.navigate(to: .memberManagement)
                }
                .font(.bodyMedium)
                .foregroundColor(.primaryBlue)
            }

            StandardCard {
                VStack(spacing: 16) {
                    // Pending Approvals
                    if viewModel.pendingApprovals > 0 {
                        HStack {
                            Image(systemName: "person.badge.clock")
                                .foregroundColor(.warningOrange)

                            Text("\(viewModel.pendingApprovals) membership requests pending")
                                .font(.bodyMedium)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            Button("Review") {
                                viewModel.presentedSheet = .memberApprovals
                            }
                            .font(.bodySmall)
                            .foregroundColor(.primaryBlue)
                        }

                        Divider()
                    }

                    // Recent Members
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Members")
                            .font(.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(.textPrimary)

                        if viewModel.isLoadingMembers {
                            MemberSkeletonView()
                        } else {
                            ForEach(viewModel.recentMembers.prefix(3), id: \.id) { member in
                                MemberRowView(member: member, showRole: true) {
                                    navigationStore.navigate(to: .memberProfile(userId: member.id))
                                }
                            }
                        }
                    }
                }
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

                Button("Audit Log") {
                    viewModel.presentedSheet = .auditLog
                }
                .font(.bodyMedium)
                .foregroundColor(.primaryBlue)
            }

            if viewModel.isLoadingActivities {
                ActivitySkeletonView()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentActivities.prefix(5), id: \.id) { activity in
                        AdminActivityRowView(activity: activity) {
                            handleActivityTap(activity)
                        }
                    }
                }
            }
        }
    }

    private var adminQuickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline3)
                .foregroundColor(.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                AdminQuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add Member",
                    color: .successGreen
                ) {
                    viewModel.presentedSheet = .addMember
                }

                AdminQuickActionButton(
                    icon: "sportscourt",
                    title: "Create Match",
                    color: .primaryBlue
                ) {
                    viewModel.presentedSheet = .createMatch
                }

                AdminQuickActionButton(
                    icon: "megaphone.fill",
                    title: "Send Notice",
                    color: .warningOrange
                ) {
                    viewModel.presentedSheet = .sendNotification
                }

                AdminQuickActionButton(
                    icon: "chart.bar.doc.horizontal",
                    title: "Generate Report",
                    color: .lightBlue
                ) {
                    viewModel.presentedSheet = .reportGenerator
                }

                AdminQuickActionButton(
                    icon: "gear.badge",
                    title: "Club Settings",
                    color: .textSecondary
                ) {
                    navigationStore.navigate(to: .clubSettings)
                }

                AdminQuickActionButton(
                    icon: "dollarsign.circle",
                    title: "Collect Fees",
                    color: .chart4
                ) {
                    viewModel.presentedSheet = .collectFees
                }

                AdminQuickActionButton(
                    icon: "square.and.arrow.up",
                    title: "Export Data",
                    color: .chart5
                ) {
                    viewModel.presentedSheet = .exportData
                }

                AdminQuickActionButton(
                    icon: "shield.checkered",
                    title: "Security",
                    color: .errorRed
                ) {
                    viewModel.presentedSheet = .securitySettings
                }
            }
        }
    }

    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Health")
                .font(.headline3)
                .foregroundColor(.textPrimary)

            StandardCard {
                VStack(spacing: 12) {
                    SystemHealthRow(
                        title: "Database",
                        status: viewModel.systemHealth.databaseStatus,
                        lastUpdated: viewModel.systemHealth.databaseLastCheck
                    )

                    SystemHealthRow(
                        title: "API Services",
                        status: viewModel.systemHealth.apiStatus,
                        lastUpdated: viewModel.systemHealth.apiLastCheck
                    )

                    SystemHealthRow(
                        title: "Payment Gateway",
                        status: viewModel.systemHealth.paymentStatus,
                        lastUpdated: viewModel.systemHealth.paymentLastCheck
                    )

                    SystemHealthRow(
                        title: "Notifications",
                        status: viewModel.systemHealth.notificationStatus,
                        lastUpdated: viewModel.systemHealth.notificationLastCheck
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func adminSheetContent(for sheet: AdminDashboardSheet) -> some View {
        switch sheet {
        case .systemNotifications:
            SystemNotificationsView()
        case .pendingTasks:
            PendingTasksView()
        case .memberApprovals:
            MemberApprovalsView()
        case .auditLog:
            AuditLogView()
        case .addMember:
            AddMemberView()
        case .createMatch:
            CreateMatchView()
        case .sendNotification:
            SendNotificationView()
        case .reportGenerator:
            ReportGeneratorView()
        case .collectFees:
            CollectFeesView()
        case .exportData:
            ExportDataView()
        case .securitySettings:
            SecuritySettingsView()
        }
    }

    private func handleActivityTap(_ activity: AdminActivity) {
        switch activity.type {
        case .memberJoined:
            navigationStore.navigate(to: .memberProfile(userId: activity.referenceId))
        case .matchCreated:
            navigationStore.navigate(to: .matchDetail(matchId: activity.referenceId))
        case .paymentReceived:
            navigationStore.navigate(to: .transactionDetail(transactionId: activity.referenceId))
        case .settingsChanged:
            navigationStore.navigate(to: .clubSettings)
        default:
            break
        }
    }
}
```

### Admin Stat Card Component
```swift
struct AdminStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let trend: TrendDirection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            StandardCard {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color)

                        Spacer()

                        TrendIndicator(direction: trend)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(value)
                            .font(.headline2)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text(title)
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

### Club Health Indicator
```swift
struct ClubHealthIndicator: View {
    let health: ClubHealth

    var body: some View {
        HStack {
            Image(systemName: health.iconName)
                .foregroundColor(health.color)

            Text(health.status)
                .font(.bodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            Text(health.description)
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(health.color.opacity(0.1))
        .cornerRadius(8)
    }
}
```

### Financial Summary Chart
```swift
struct FinancialSummaryChart: View {
    let data: FinancialSummaryData

    var body: some View {
        HStack(spacing: 8) {
            ForEach(data.monthlyData.indices, id: \.self) { index in
                let monthData = data.monthlyData[index]

                VStack(spacing: 4) {
                    VStack(spacing: 2) {
                        // Income bar
                        Rectangle()
                            .fill(Color.successGreen)
                            .frame(height: CGFloat(monthData.income / data.maxValue) * 80)

                        // Expense bar
                        Rectangle()
                            .fill(Color.errorRed)
                            .frame(height: CGFloat(monthData.expenses / data.maxValue) * 80)
                    }
                    .frame(maxHeight: 80)

                    Text(monthData.monthName)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
```

### System Health Row
```swift
struct SystemHealthRow: View {
    let title: String
    let status: SystemStatus
    let lastUpdated: Date

    var body: some View {
        HStack {
            Text(title)
                .font(.bodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack {
                    Image(systemName: status.iconName)
                        .foregroundColor(status.color)
                        .font(.caption)

                    Text(status.displayName)
                        .font(.bodySmall)
                        .foregroundColor(status.color)
                }

                Text(lastUpdated.timeAgoDisplay)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
        }
    }
}
```

## ViewModel Implementation

### Admin Dashboard ViewModel
```swift
@MainActor
class AdminDashboardViewModel: ObservableObject {
    @Published var clubName = ""
    @Published var clubHealth: ClubHealth = .good
    @Published var clubStats: ClubStats? = nil
    @Published var financialSummary: FinancialSummaryData? = nil
    @Published var systemHealth: SystemHealthData = SystemHealthData()

    @Published var recentMembers: [Member] = []
    @Published var recentActivities: [AdminActivity] = []
    @Published var pendingApprovals = 0
    @Published var systemAlertsCount = 0

    @Published var isLoadingOverview = false
    @Published var isLoadingMembers = false
    @Published var isLoadingActivities = false

    @Published var presentedSheet: AdminDashboardSheet? = nil
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var alertType: AlertType = .info

    private let adminUseCase: AdminUseCaseProtocol
    private let clubUseCase: ClubUseCaseProtocol
    private let memberUseCase: MemberUseCaseProtocol
    private let financialUseCase: FinancialUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        adminUseCase: AdminUseCaseProtocol = DependencyContainer.shared.adminUseCase,
        clubUseCase: ClubUseCaseProtocol = DependencyContainer.shared.clubUseCase,
        memberUseCase: MemberUseCaseProtocol = DependencyContainer.shared.memberUseCase,
        financialUseCase: FinancialUseCaseProtocol = DependencyContainer.shared.financialUseCase
    ) {
        self.adminUseCase = adminUseCase
        self.clubUseCase = clubUseCase
        self.memberUseCase = memberUseCase
        self.financialUseCase = financialUseCase

        setupRealTimeUpdates()
    }

    func loadAdminDashboard() {
        loadClubOverview()
        loadFinancialSummary()
        loadRecentMembers()
        loadRecentActivities()
        loadSystemHealth()
        checkPendingApprovals()
        checkSystemAlerts()
    }

    @MainActor
    func refreshDashboard() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshClubOverview() }
            group.addTask { await self.refreshFinancialSummary() }
            group.addTask { await self.refreshRecentMembers() }
            group.addTask { await self.refreshRecentActivities() }
            group.addTask { await self.refreshSystemHealth() }
        }
    }

    func handleCriticalAlert() {
        switch alertType {
        case .critical:
            // Handle critical system issues
            presentedSheet = .securitySettings
        case .paymentIssue:
            // Handle payment gateway issues
            // Navigate to payment settings
            break
        case .membershipExpiring:
            // Handle membership expiration
            presentedSheet = .collectFees
        default:
            break
        }
    }

    private func loadClubOverview() {
        isLoadingOverview = true

        adminUseCase.getClubStats()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingOverview = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] stats in
                    self?.clubStats = stats
                    self?.clubName = stats.clubName
                    self?.evaluateClubHealth(stats)
                }
            )
            .store(in: &cancellables)
    }

    private func loadFinancialSummary() {
        financialUseCase.getFinancialSummary()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to load financial summary: \(error)")
                    }
                },
                receiveValue: { [weak self] summary in
                    self?.financialSummary = summary
                }
            )
            .store(in: &cancellables)
    }

    private func loadRecentMembers() {
        isLoadingMembers = true

        memberUseCase.getRecentMembers(limit: 5)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingMembers = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] members in
                    self?.recentMembers = members
                }
            )
            .store(in: &cancellables)
    }

    private func loadRecentActivities() {
        isLoadingActivities = true

        adminUseCase.getRecentActivities(limit: 10)
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

    private func loadSystemHealth() {
        adminUseCase.getSystemHealth()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to load system health: \(error)")
                    }
                },
                receiveValue: { [weak self] health in
                    self?.systemHealth = health
                }
            )
            .store(in: &cancellables)
    }

    private func checkPendingApprovals() {
        memberUseCase.getPendingApprovalsCount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to check pending approvals: \(error)")
                    }
                },
                receiveValue: { [weak self] count in
                    self?.pendingApprovals = count
                }
            )
            .store(in: &cancellables)
    }

    private func checkSystemAlerts() {
        adminUseCase.getSystemAlertsCount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to check system alerts: \(error)")
                    }
                },
                receiveValue: { [weak self] count in
                    self?.systemAlertsCount = count
                }
            )
            .store(in: &cancellables)
    }

    private func evaluateClubHealth(_ stats: ClubStats) {
        // Evaluate club health based on various metrics
        if stats.criticalTasks > 0 || stats.systemIssues > 0 {
            clubHealth = .critical
        } else if stats.pendingTasks > 10 || stats.memberGrowthTrend == .declining {
            clubHealth = .warning
        } else {
            clubHealth = .good
        }
    }

    private func setupRealTimeUpdates() {
        // Listen for real-time updates
        NotificationCenter.default.publisher(for: .memberJoined)
            .sink { [weak self] _ in
                self?.loadRecentMembers()
                self?.loadClubOverview()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .paymentReceived)
            .sink { [weak self] _ in
                self?.loadFinancialSummary()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .systemAlert)
            .sink { [weak self] notification in
                self?.handleSystemAlert(notification)
            }
            .store(in: &cancellables)
    }

    private func handleSystemAlert(_ notification: Notification) {
        guard let alertData = notification.object as? SystemAlertData else { return }

        alertMessage = alertData.message
        alertType = alertData.type
        showAlert = true
        systemAlertsCount += 1
    }

    // Async refresh methods
    private func refreshClubOverview() async {
        do {
            let stats = try await adminUseCase.getClubStats().async()
            await MainActor.run {
                self.clubStats = stats
                self.clubName = stats.clubName
                self.evaluateClubHealth(stats)
            }
        } catch {
            await MainActor.run {
                self.handleError(error)
            }
        }
    }

    private func refreshFinancialSummary() async {
        do {
            let summary = try await financialUseCase.getFinancialSummary().async()
            await MainActor.run {
                self.financialSummary = summary
            }
        } catch {
            print("Failed to refresh financial summary: \(error)")
        }
    }

    private func refreshRecentMembers() async {
        do {
            let members = try await memberUseCase.getRecentMembers(limit: 5).async()
            await MainActor.run {
                self.recentMembers = members
            }
        } catch {
            print("Failed to refresh recent members: \(error)")
        }
    }

    private func refreshRecentActivities() async {
        do {
            let activities = try await adminUseCase.getRecentActivities(limit: 10).async()
            await MainActor.run {
                self.recentActivities = activities
            }
        } catch {
            print("Failed to refresh recent activities: \(error)")
        }
    }

    private func refreshSystemHealth() async {
        do {
            let health = try await adminUseCase.getSystemHealth().async()
            await MainActor.run {
                self.systemHealth = health
            }
        } catch {
            print("Failed to refresh system health: \(error)")
        }
    }

    private func handleError(_ error: Error) {
        alertMessage = error.localizedDescription
        alertType = .error
        showAlert = true
    }
}

enum AdminDashboardSheet: Identifiable {
    case systemNotifications
    case pendingTasks
    case memberApprovals
    case auditLog
    case addMember
    case createMatch
    case sendNotification
    case reportGenerator
    case collectFees
    case exportData
    case securitySettings

    var id: String {
        switch self {
        case .systemNotifications: return "systemNotifications"
        case .pendingTasks: return "pendingTasks"
        case .memberApprovals: return "memberApprovals"
        case .auditLog: return "auditLog"
        case .addMember: return "addMember"
        case .createMatch: return "createMatch"
        case .sendNotification: return "sendNotification"
        case .reportGenerator: return "reportGenerator"
        case .collectFees: return "collectFees"
        case .exportData: return "exportData"
        case .securitySettings: return "securitySettings"
        }
    }
}
```

## Data Models

### Admin Models
```swift
struct ClubStats {
    let clubName: String
    let totalMembers: Int
    let newMembersThisMonth: Int
    let activeMatches: Int
    let upcomingMatches: Int
    let monthlyRevenue: Double
    let totalBalance: Double
    let pendingTasks: Int
    let criticalTasks: Int
    let systemIssues: Int
    let memberGrowthTrend: TrendDirection
    let matchActivityTrend: TrendDirection
    let revenueTrend: TrendDirection
}

enum ClubHealth {
    case good
    case warning
    case critical

    var status: String {
        switch self {
        case .good: return "All Systems Operational"
        case .warning: return "Attention Required"
        case .critical: return "Critical Issues Detected"
        }
    }

    var description: String {
        switch self {
        case .good: return "Club running smoothly"
        case .warning: return "Some issues need attention"
        case .critical: return "Immediate action required"
        }
    }

    var iconName: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .good: return .successGreen
        case .warning: return .warningOrange
        case .critical: return .errorRed
        }
    }
}

enum TrendDirection {
    case up
    case down
    case stable

    var iconName: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .up: return .successGreen
        case .down: return .errorRed
        case .stable: return .textSecondary
        }
    }
}

struct AdminActivity {
    let id: String
    let type: AdminActivityType
    let title: String
    let description: String
    let timestamp: Date
    let userId: String?
    let userName: String?
    let referenceId: String
    let severity: ActivitySeverity
}

enum AdminActivityType {
    case memberJoined
    case memberLeft
    case matchCreated
    case matchCancelled
    case paymentReceived
    case paymentFailed
    case settingsChanged
    case securityAlert
    case systemError

    var iconName: String {
        switch self {
        case .memberJoined: return "person.badge.plus"
        case .memberLeft: return "person.badge.minus"
        case .matchCreated: return "sportscourt.fill"
        case .matchCancelled: return "xmark.circle"
        case .paymentReceived: return "indianrupeesign.circle.fill"
        case .paymentFailed: return "exclamationmark.triangle"
        case .settingsChanged: return "gear"
        case .securityAlert: return "shield.slash"
        case .systemError: return "exclamationmark.octagon"
        }
    }

    var color: Color {
        switch self {
        case .memberJoined, .matchCreated, .paymentReceived: return .successGreen
        case .memberLeft, .matchCancelled: return .warningOrange
        case .paymentFailed, .securityAlert, .systemError: return .errorRed
        case .settingsChanged: return .primaryBlue
        }
    }
}

enum ActivitySeverity {
    case low
    case medium
    case high
    case critical
}

struct SystemHealthData {
    let databaseStatus: SystemStatus = .operational
    let apiStatus: SystemStatus = .operational
    let paymentStatus: SystemStatus = .operational
    let notificationStatus: SystemStatus = .operational
    let databaseLastCheck: Date = Date()
    let apiLastCheck: Date = Date()
    let paymentLastCheck: Date = Date()
    let notificationLastCheck: Date = Date()
}

enum SystemStatus {
    case operational
    case degraded
    case down
    case maintenance

    var displayName: String {
        switch self {
        case .operational: return "Operational"
        case .degraded: return "Degraded"
        case .down: return "Down"
        case .maintenance: return "Maintenance"
        }
    }

    var iconName: String {
        switch self {
        case .operational: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .down: return "xmark.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }

    var color: Color {
        switch self {
        case .operational: return .successGreen
        case .degraded: return .warningOrange
        case .down: return .errorRed
        case .maintenance: return .primaryBlue
        }
    }
}

struct FinancialSummaryData {
    let monthlyIncome: Double
    let monthlyExpenses: Double
    let netProfit: Double
    let monthlyData: [MonthlyFinancialData]
    let maxValue: Double
}

struct MonthlyFinancialData {
    let monthName: String
    let income: Double
    let expenses: Double
}

enum AlertType {
    case info
    case warning
    case error
    case critical
    case paymentIssue
    case membershipExpiring
}

struct SystemAlertData {
    let message: String
    let type: AlertType
    let timestamp: Date
}
```

## Supporting Components

### Trend Indicator
```swift
struct TrendIndicator: View {
    let direction: TrendDirection

    var body: some View {
        Image(systemName: direction.iconName)
            .font(.caption)
            .foregroundColor(direction.color)
    }
}
```

### Admin Quick Action Button
```swift
struct AdminQuickActionButton: View {
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

### Admin Activity Row View
```swift
struct AdminActivityRowView: View {
    let activity: AdminActivity
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
                    HStack {
                        Text(activity.title)
                            .font(.bodyMedium)
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)

                        if activity.severity == .critical {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.errorRed)
                        }
                    }

                    Text(activity.description)
                        .font(.bodySmall)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)

                    if let userName = activity.userName {
                        Text("by \(userName)")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
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

## Admin Dashboard Implementation Tasks

### Core UI Tasks
- [ ] Create AdminDashboardView with comprehensive layout
- [ ] Implement AdminStatCard with trend indicators
- [ ] Build ClubHealthIndicator component
- [ ] Create FinancialSummaryChart visualization
- [ ] Add SystemHealthRow monitoring components
- [ ] Implement AdminQuickActionButton grid

### Data Integration Tasks
- [ ] Create AdminDashboardViewModel with state management
- [ ] Implement AdminUseCase for club statistics
- [ ] Add real-time data updates and notifications
- [ ] Create financial summary integration
- [ ] Implement system health monitoring
- [ ] Add audit trail and activity logging

### Administrative Features Tasks
- [ ] Create role-based access control
- [ ] Implement bulk operations interface
- [ ] Add system notification management
- [ ] Create backup and export functionality
- [ ] Implement compliance reporting tools
- [ ] Add security monitoring and alerts

### Management Tools Tasks
- [ ] Create member approval workflow
- [ ] Implement fee collection system
- [ ] Add notification broadcasting
- [ ] Create report generation tools
- [ ] Implement data export functionality
- [ ] Add club settings management

### Monitoring Tasks
- [ ] Implement real-time system health monitoring
- [ ] Create performance metrics tracking
- [ ] Add error logging and reporting
- [ ] Implement usage analytics
- [ ] Create automated alert system
- [ ] Add compliance monitoring

This admin dashboard provides comprehensive club management capabilities with real-time monitoring, analytics, and powerful administrative tools for club owners.