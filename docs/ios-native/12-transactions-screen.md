# Transactions Screen Implementation

## Overview
Complete implementation guide for the financial transactions screen with filtering, search, categorization, and detailed transaction views.

## 🎯 Transaction Screen Tasks

### UI Implementation
- [ ] Create transaction list with advanced filtering
- [ ] Implement search and sort functionality
- [ ] Add transaction detail modal views
- [ ] Create category-based grouping
- [ ] Implement date range picker
- [ ] Add receipt generation and sharing

### Data Management
- [ ] Integrate transaction history API
- [ ] Implement local caching and sync
- [ ] Add real-time transaction updates
- [ ] Create transaction categorization
- [ ] Implement export functionality
- [ ] Add balance calculation and tracking

### Financial Features
- [ ] Create expense vs income visualization
- [ ] Implement monthly/yearly summaries
- [ ] Add budget tracking and alerts
- [ ] Create financial insights and trends
- [ ] Implement receipt storage and management
- [ ] Add payment method tracking

## UI Implementation

### Transactions View
```swift
struct TransactionsView: View {
    @StateObject private var viewModel = TransactionsViewModel()
    @State private var showFilters = false
    @State private var selectedTransaction: Transaction? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with balance and search
                headerSection

                // Filter chips
                if !viewModel.activeFilters.isEmpty {
                    filterChipsSection
                }

                // Transaction list
                transactionListSection
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showFilters = true }) {
                            Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
                        }

                        Button(action: viewModel.exportTransactions) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }

                        Button(action: viewModel.refreshTransactions) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            TransactionFiltersView(filters: $viewModel.filters)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
        .onAppear {
            viewModel.loadTransactions()
        }
        .refreshable {
            await viewModel.refreshTransactions()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("Retry") {
                viewModel.loadTransactions()
            }
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Current Balance Card
            StandardCard {
                VStack(spacing: 12) {
                    HStack {
                        Text("Current Balance")
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        Button(action: {
                            // Navigate to wallet
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textSecondary)
                        }
                    }

                    HStack {
                        Text("₹\(viewModel.currentBalance, specifier: "%.2f")")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.successGreen)
                                Text("₹\(viewModel.monthlyIncome, specifier: "%.0f")")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }

                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.errorRed)
                                Text("₹\(viewModel.monthlyExpense, specifier: "%.0f")")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            // Search Bar
            SearchBar(
                searchText: $viewModel.searchText,
                placeholder: "Search transactions..."
            )
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.activeFilters, id: \.id) { filter in
                    FilterChip(
                        title: filter.displayName,
                        onRemove: {
                            viewModel.removeFilter(filter)
                        }
                    )
                }

                Button("Clear All") {
                    viewModel.clearAllFilters()
                }
                .font(.caption)
                .foregroundColor(.primaryBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primaryBlue.opacity(0.1))
                .cornerRadius(16)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    private var transactionListSection: some View {
        Group {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                TransactionSkeletonView()
            } else if viewModel.transactions.isEmpty {
                EmptyStateView(
                    icon: "creditcard",
                    title: "No Transactions",
                    message: "Your transaction history will appear here",
                    actionTitle: "Add Money",
                    action: {
                        // Navigate to add money
                    }
                )
            } else {
                List {
                    ForEach(viewModel.groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                        Section {
                            ForEach(viewModel.groupedTransactions[date] ?? [], id: \.id) { transaction in
                                TransactionRowView(transaction: transaction) {
                                    selectedTransaction = transaction
                                }
                            }
                        } header: {
                            TransactionSectionHeader(
                                date: date,
                                totalAmount: viewModel.dailyTotals[date] ?? 0
                            )
                        }
                    }

                    // Load more indicator
                    if viewModel.hasMoreTransactions {
                        HStack {
                            Spacer()
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button("Load More") {
                                    viewModel.loadMoreTransactions()
                                }
                                .font(.bodyMedium)
                                .foregroundColor(.primaryBlue)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}
```

### Transaction Row View
```swift
struct TransactionRowView: View {
    let transaction: Transaction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Transaction Icon
                Image(systemName: transaction.type.iconName)
                    .font(.title3)
                    .foregroundColor(transaction.type.color)
                    .frame(width: 40, height: 40)
                    .background(transaction.type.color.opacity(0.1))
                    .clipShape(Circle())

                // Transaction Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.title)
                        .font(.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(transaction.description)
                        .font(.bodySmall)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)

                    HStack {
                        Text(transaction.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        if let paymentMethod = transaction.paymentMethod {
                            Text("• \(paymentMethod.displayName)")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }

                Spacer()

                // Amount and Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.formattedAmount)
                        .font(.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.amountColor)

                    TransactionStatusBadge(status: transaction.status)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

### Transaction Detail View
```swift
struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with amount
                    transactionHeaderSection

                    // Transaction details
                    transactionDetailsSection

                    // Payment information
                    if let paymentInfo = transaction.paymentInfo {
                        paymentInfoSection(paymentInfo)
                    }

                    // Receipt section
                    if transaction.hasReceipt {
                        receiptSection
                    }

                    // Actions
                    actionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showShareSheet = true }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        if transaction.hasReceipt {
                            Button(action: downloadReceipt) {
                                Label("Download Receipt", systemImage: "arrow.down.circle")
                            }
                        }

                        if transaction.canDispute {
                            Button(action: disputeTransaction) {
                                Label("Report Issue", systemImage: "exclamationmark.triangle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [transaction.shareText])
        }
    }

    private var transactionHeaderSection: some View {
        StandardCard {
            VStack(spacing: 16) {
                // Status and Type
                HStack {
                    TransactionStatusBadge(status: transaction.status)
                    Spacer()
                    Text(transaction.type.displayName)
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                }

                // Amount
                Text(transaction.formattedAmount)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.amountColor)

                // Description
                Text(transaction.description)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var transactionDetailsSection: some View {
        StandardCard {
            VStack(spacing: 16) {
                Text("Transaction Details")
                    .font(.headline4)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    DetailRow(label: "Transaction ID", value: transaction.id)
                    DetailRow(label: "Date & Time", value: transaction.timestamp.formatted(date: .complete, time: .standard))
                    DetailRow(label: "Category", value: transaction.category.displayName)

                    if let reference = transaction.referenceNumber {
                        DetailRow(label: "Reference", value: reference)
                    }

                    if let clubName = transaction.clubName {
                        DetailRow(label: "Club", value: clubName)
                    }
                }
            }
        }
    }

    private func paymentInfoSection(_ paymentInfo: PaymentInfo) -> some View {
        StandardCard {
            VStack(spacing: 16) {
                Text("Payment Information")
                    .font(.headline4)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    DetailRow(label: "Payment Method", value: paymentInfo.method.displayName)

                    if let last4 = paymentInfo.last4Digits {
                        DetailRow(label: "Card", value: "**** **** **** \(last4)")
                    }

                    if let upiId = paymentInfo.upiId {
                        DetailRow(label: "UPI ID", value: upiId)
                    }

                    if let gateway = paymentInfo.gateway {
                        DetailRow(label: "Gateway", value: gateway)
                    }

                    if let fees = paymentInfo.processingFees, fees > 0 {
                        DetailRow(label: "Processing Fee", value: "₹\(fees, specifier: "%.2f")")
                    }
                }
            }
        }
    }

    private var receiptSection: some View {
        StandardCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Receipt")
                        .font(.headline4)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button("View") {
                        // Open receipt
                    }
                    .font(.bodyMedium)
                    .foregroundColor(.primaryBlue)
                }

                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.primaryBlue)

                    Text("Transaction receipt available")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)

                    Spacer()
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if transaction.canRepeat {
                PrimaryButton(
                    title: "Repeat Transaction",
                    action: repeatTransaction
                )
            }

            if transaction.canRefund {
                SecondaryButton(
                    title: "Request Refund",
                    action: requestRefund
                )
            }
        }
    }

    private func downloadReceipt() {
        // Download receipt implementation
    }

    private func disputeTransaction() {
        // Dispute transaction implementation
    }

    private func repeatTransaction() {
        // Repeat transaction implementation
    }

    private func requestRefund() {
        // Request refund implementation
    }
}
```

### Transaction Filters View
```swift
struct TransactionFiltersView: View {
    @Binding var filters: TransactionFilters
    @Environment(\.dismiss) private var dismiss
    @State private var tempFilters: TransactionFilters

    init(filters: Binding<TransactionFilters>) {
        self._filters = filters
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }

    var body: some View {
        NavigationView {
            Form {
                // Date Range Section
                Section("Date Range") {
                    Picker("Period", selection: $tempFilters.dateRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }

                    if tempFilters.dateRange == .custom {
                        DatePicker("From", selection: $tempFilters.startDate, displayedComponents: .date)
                        DatePicker("To", selection: $tempFilters.endDate, displayedComponents: .date)
                    }
                }

                // Transaction Type Section
                Section("Transaction Type") {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.iconName)
                                .foregroundColor(type.color)
                            Text(type.displayName)
                            Spacer()
                            if tempFilters.selectedTypes.contains(type) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryBlue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempFilters.selectedTypes.contains(type) {
                                tempFilters.selectedTypes.remove(type)
                            } else {
                                tempFilters.selectedTypes.insert(type)
                            }
                        }
                    }
                }

                // Status Section
                Section("Status") {
                    ForEach(TransactionStatus.allCases, id: \.self) { status in
                        HStack {
                            Text(status.displayName)
                            Spacer()
                            if tempFilters.selectedStatuses.contains(status) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryBlue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempFilters.selectedStatuses.contains(status) {
                                tempFilters.selectedStatuses.remove(status)
                            } else {
                                tempFilters.selectedStatuses.insert(status)
                            }
                        }
                    }
                }

                // Amount Range Section
                Section("Amount Range") {
                    HStack {
                        Text("₹")
                        TextField("Min", value: $tempFilters.minAmount, format: .number)
                            .keyboardType(.decimalPad)
                        Text("-")
                        TextField("Max", value: $tempFilters.maxAmount, format: .number)
                            .keyboardType(.decimalPad)
                        Text("₹")
                    }
                }

                // Categories Section
                Section("Categories") {
                    ForEach(TransactionCategory.allCases, id: \.self) { category in
                        HStack {
                            Text(category.displayName)
                            Spacer()
                            if tempFilters.selectedCategories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryBlue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempFilters.selectedCategories.contains(category) {
                                tempFilters.selectedCategories.remove(category)
                            } else {
                                tempFilters.selectedCategories.insert(category)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filters = tempFilters
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset Filters") {
                        tempFilters = TransactionFilters()
                    }
                    .foregroundColor(.errorRed)
                }
            }
        }
    }
}
```

## ViewModel Implementation

### Transactions ViewModel
```swift
@MainActor
class TransactionsViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var groupedTransactions: [Date: [Transaction]] = [:]
    @Published var dailyTotals: [Date: Double] = [:]

    @Published var currentBalance: Double = 0
    @Published var monthlyIncome: Double = 0
    @Published var monthlyExpense: Double = 0

    @Published var searchText = ""
    @Published var filters = TransactionFilters()
    @Published var activeFilters: [ActiveFilter] = []

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreTransactions = true
    @Published var showError = false
    @Published var errorMessage = ""

    private let transactionUseCase: TransactionUseCaseProtocol
    private let walletUseCase: WalletUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 1
    private let pageSize = 20

    init(
        transactionUseCase: TransactionUseCaseProtocol = DependencyContainer.shared.transactionUseCase,
        walletUseCase: WalletUseCaseProtocol = DependencyContainer.shared.walletUseCase
    ) {
        self.transactionUseCase = transactionUseCase
        self.walletUseCase = walletUseCase

        setupSearchDebouncing()
        setupFilterObserver()
    }

    func loadTransactions() {
        currentPage = 1
        hasMoreTransactions = true
        transactions.removeAll()

        isLoading = true

        Publishers.Zip(
            loadCurrentBalance(),
            loadTransactionPage(page: currentPage)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            },
            receiveValue: { [weak self] (balance, transactionResponse) in
                self?.currentBalance = balance
                self?.processTransactionResponse(transactionResponse)
                self?.calculateMonthlySummary()
                self?.groupTransactionsByDate()
                self?.updateActiveFilters()
            }
        )
        .store(in: &cancellables)
    }

    func loadMoreTransactions() {
        guard !isLoadingMore && hasMoreTransactions else { return }

        isLoadingMore = true
        currentPage += 1

        loadTransactionPage(page: currentPage)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingMore = false
                    if case .failure(let error) = completion {
                        self?.currentPage -= 1 // Rollback page increment
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.processTransactionResponse(response, append: true)
                    self?.groupTransactionsByDate()
                }
            )
            .store(in: &cancellables)
    }

    @MainActor
    func refreshTransactions() async {
        do {
            let (balance, transactionResponse) = try await Publishers.Zip(
                loadCurrentBalance(),
                loadTransactionPage(page: 1)
            ).async()

            currentBalance = balance
            currentPage = 1
            hasMoreTransactions = true
            transactions.removeAll()
            processTransactionResponse(transactionResponse)
            calculateMonthlySummary()
            groupTransactionsByDate()
        } catch {
            handleError(error)
        }
    }

    func exportTransactions() {
        transactionUseCase.exportTransactions(filters: filters)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Export failed: \(error)")
                    }
                },
                receiveValue: { exportURL in
                    // Share exported file
                    self.shareExportedFile(url: exportURL)
                }
            )
            .store(in: &cancellables)
    }

    func removeFilter(_ filter: ActiveFilter) {
        filters.removeFilter(filter)
    }

    func clearAllFilters() {
        filters = TransactionFilters()
    }

    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.loadTransactions()
            }
            .store(in: &cancellables)
    }

    private func setupFilterObserver() {
        $filters
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadTransactions()
            }
            .store(in: &cancellables)
    }

    private func loadCurrentBalance() -> AnyPublisher<Double, Error> {
        walletUseCase.getCurrentBalance()
    }

    private func loadTransactionPage(page: Int) -> AnyPublisher<TransactionResponse, Error> {
        let request = TransactionRequest(
            page: page,
            pageSize: pageSize,
            searchText: searchText.isEmpty ? nil : searchText,
            filters: filters
        )

        return transactionUseCase.getTransactions(request: request)
    }

    private func processTransactionResponse(_ response: TransactionResponse, append: Bool = false) {
        if append {
            transactions.append(contentsOf: response.transactions)
        } else {
            transactions = response.transactions
        }

        hasMoreTransactions = response.hasMore
    }

    private func calculateMonthlySummary() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())

        let monthlyTransactions = transactions.filter { transaction in
            let transactionMonth = Calendar.current.component(.month, from: transaction.timestamp)
            let transactionYear = Calendar.current.component(.year, from: transaction.timestamp)
            return transactionMonth == currentMonth && transactionYear == currentYear
        }

        monthlyIncome = monthlyTransactions
            .filter { $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }

        monthlyExpense = abs(monthlyTransactions
            .filter { $0.amount < 0 }
            .reduce(0) { $0 + $1.amount })
    }

    private func groupTransactionsByDate() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.timestamp)
        }

        groupedTransactions = grouped

        // Calculate daily totals
        dailyTotals = grouped.mapValues { transactions in
            transactions.reduce(0) { $0 + $1.amount }
        }
    }

    private func updateActiveFilters() {
        activeFilters = filters.getActiveFilters()
    }

    private func shareExportedFile(url: URL) {
        // Implementation for sharing exported file
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

## Data Models

### Transaction Models
```swift
struct Transaction: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let amount: Double
    let type: TransactionType
    let category: TransactionCategory
    let status: TransactionStatus
    let timestamp: Date
    let referenceNumber: String?
    let clubName: String?
    let paymentMethod: PaymentMethod?
    let paymentInfo: PaymentInfo?
    let hasReceipt: Bool
    let canRefund: Bool
    let canRepeat: Bool
    let canDispute: Bool

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"

        return formatter.string(from: NSNumber(value: abs(amount))) ?? "₹0"
    }

    var amountColor: Color {
        return amount >= 0 ? .successGreen : .errorRed
    }

    var shareText: String {
        return "Transaction: \(title)\nAmount: \(formattedAmount)\nDate: \(timestamp.formatted())\nID: \(id)"
    }
}

enum TransactionType: String, CaseIterable, Codable {
    case credit = "credit"
    case debit = "debit"
    case refund = "refund"
    case fee = "fee"

    var displayName: String {
        switch self {
        case .credit: return "Credit"
        case .debit: return "Debit"
        case .refund: return "Refund"
        case .fee: return "Fee"
        }
    }

    var iconName: String {
        switch self {
        case .credit: return "arrow.down.circle.fill"
        case .debit: return "arrow.up.circle.fill"
        case .refund: return "arrow.counterclockwise.circle.fill"
        case .fee: return "doc.text.fill"
        }
    }

    var color: Color {
        switch self {
        case .credit: return .successGreen
        case .debit: return .errorRed
        case .refund: return .lightBlue
        case .fee: return .warningOrange
        }
    }
}

enum TransactionStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

enum TransactionCategory: String, CaseIterable, Codable {
    case membership = "membership"
    case equipment = "equipment"
    case match = "match"
    case merchandise = "merchandise"
    case food = "food"
    case other = "other"

    var displayName: String {
        switch self {
        case .membership: return "Membership"
        case .equipment: return "Equipment"
        case .match: return "Match"
        case .merchandise: return "Merchandise"
        case .food: return "Food & Beverage"
        case .other: return "Other"
        }
    }
}

struct PaymentInfo: Codable {
    let method: PaymentMethod
    let last4Digits: String?
    let upiId: String?
    let gateway: String?
    let processingFees: Double?
}

enum PaymentMethod: String, CaseIterable, Codable {
    case creditCard = "credit_card"
    case debitCard = "debit_card"
    case upi = "upi"
    case netBanking = "net_banking"
    case wallet = "wallet"
    case cash = "cash"

    var displayName: String {
        switch self {
        case .creditCard: return "Credit Card"
        case .debitCard: return "Debit Card"
        case .upi: return "UPI"
        case .netBanking: return "Net Banking"
        case .wallet: return "Wallet"
        case .cash: return "Cash"
        }
    }
}
```

### Filter Models
```swift
struct TransactionFilters {
    var dateRange: DateRange = .all
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    var selectedTypes: Set<TransactionType> = []
    var selectedStatuses: Set<TransactionStatus> = []
    var selectedCategories: Set<TransactionCategory> = []
    var minAmount: Double? = nil
    var maxAmount: Double? = nil

    func getActiveFilters() -> [ActiveFilter] {
        var filters: [ActiveFilter] = []

        if dateRange != .all {
            filters.append(ActiveFilter(id: "dateRange", displayName: dateRange.displayName, type: .dateRange))
        }

        for type in selectedTypes {
            filters.append(ActiveFilter(id: "type_\(type.rawValue)", displayName: type.displayName, type: .transactionType))
        }

        for status in selectedStatuses {
            filters.append(ActiveFilter(id: "status_\(status.rawValue)", displayName: status.displayName, type: .status))
        }

        for category in selectedCategories {
            filters.append(ActiveFilter(id: "category_\(category.rawValue)", displayName: category.displayName, type: .category))
        }

        if minAmount != nil || maxAmount != nil {
            let min = minAmount ?? 0
            let max = maxAmount ?? Double.infinity
            filters.append(ActiveFilter(id: "amount", displayName: "₹\(Int(min))-₹\(max == Double.infinity ? "∞" : String(Int(max)))", type: .amount))
        }

        return filters
    }

    mutating func removeFilter(_ filter: ActiveFilter) {
        switch filter.type {
        case .dateRange:
            dateRange = .all
        case .transactionType:
            if let typeString = filter.id.components(separatedBy: "_").last,
               let type = TransactionType(rawValue: typeString) {
                selectedTypes.remove(type)
            }
        case .status:
            if let statusString = filter.id.components(separatedBy: "_").last,
               let status = TransactionStatus(rawValue: statusString) {
                selectedStatuses.remove(status)
            }
        case .category:
            if let categoryString = filter.id.components(separatedBy: "_").last,
               let category = TransactionCategory(rawValue: categoryString) {
                selectedCategories.remove(category)
            }
        case .amount:
            minAmount = nil
            maxAmount = nil
        }
    }
}

struct ActiveFilter: Identifiable {
    let id: String
    let displayName: String
    let type: FilterType
}

enum FilterType {
    case dateRange
    case transactionType
    case status
    case category
    case amount
}

enum DateRange: CaseIterable {
    case all
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case custom

    var displayName: String {
        switch self {
        case .all: return "All Time"
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .custom: return "Custom Range"
        }
    }
}
```

## Supporting Components

### Filter Chip
```swift
struct FilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.primaryBlue)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.primaryBlue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primaryBlue.opacity(0.1))
        .cornerRadius(16)
    }
}
```

### Transaction Status Badge
```swift
struct TransactionStatusBadge: View {
    let status: TransactionStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .foregroundColor(status.textColor)
            .cornerRadius(8)
    }
}

extension TransactionStatus {
    var backgroundColor: Color {
        switch self {
        case .pending: return .warningOrange.opacity(0.2)
        case .completed: return .successGreen.opacity(0.2)
        case .failed: return .errorRed.opacity(0.2)
        case .cancelled: return .textSecondary.opacity(0.2)
        }
    }

    var textColor: Color {
        switch self {
        case .pending: return .warningOrange
        case .completed: return .successGreen
        case .failed: return .errorRed
        case .cancelled: return .textSecondary
        }
    }
}
```

## Transaction Screen Implementation Tasks

### Core UI Tasks
- [ ] Create TransactionsView with filtering and search
- [ ] Implement TransactionRowView with transaction details
- [ ] Build TransactionDetailView with complete information
- [ ] Create TransactionFiltersView with all filter options
- [ ] Add transaction grouping by date
- [ ] Implement pull-to-refresh and pagination

### Data Management Tasks
- [ ] Create TransactionsViewModel with state management
- [ ] Implement TransactionUseCase for API integration
- [ ] Add local caching and offline support
- [ ] Create real-time transaction updates
- [ ] Implement search and filtering logic
- [ ] Add export functionality

### Financial Features Tasks
- [ ] Create balance display and tracking
- [ ] Implement monthly income/expense calculation
- [ ] Add transaction categorization
- [ ] Create receipt storage and viewing
- [ ] Implement payment method tracking
- [ ] Add financial insights and trends

### Advanced Features Tasks
- [ ] Create transaction export functionality
- [ ] Implement receipt generation and sharing
- [ ] Add transaction dispute system
- [ ] Create refund request functionality
- [ ] Implement repeat transaction feature
- [ ] Add advanced analytics and reporting

This transactions screen provides comprehensive financial management with advanced filtering, detailed views, and powerful features for tracking all financial activities.