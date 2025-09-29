# Reusable UI Components & Widgets

## Overview
Comprehensive library of reusable SwiftUI components for the Duggy app, ensuring consistency, maintainability, and efficient development across all screens.

## 🎯 Component Tasks

### Foundation Components
- [ ] Create base button styles and configurations
- [ ] Implement text field components with validation
- [ ] Design card and container layouts
- [ ] Create loading and shimmer effects
- [ ] Implement alert and toast message system
- [ ] Design navigation and tab bar components

### Form Components
- [ ] Build form input fields with validation
- [ ] Create dropdown and picker components
- [ ] Implement date and time pickers
- [ ] Design file upload and image picker
- [ ] Create toggle and checkbox components
- [ ] Build multi-step form navigation

### Data Display Components
- [ ] Create list and grid view components
- [ ] Implement empty state and error views
- [ ] Design chart and graph components
- [ ] Create profile and avatar components
- [ ] Build badge and status indicators
- [ ] Implement pagination and infinite scroll

## Core Design System

### Color Extensions
```swift
import SwiftUI

extension Color {
    // Primary Colors
    static let primaryBlue = Color("PrimaryBlue") // #003f9b
    static let lightBlue = Color("LightBlue") // #06aeef
    static let lighterBlue = Color("LighterBlue") // #4dd0ff

    // Status Colors
    static let successGreen = Color("SuccessGreen") // #16a34a
    static let errorRed = Color("ErrorRed") // #dc2626
    static let warningOrange = Color("WarningOrange") // #f59e0b

    // Neutral Colors
    static let backgroundPrimary = Color("BackgroundPrimary") // #ffffff
    static let backgroundSecondary = Color("BackgroundSecondary") // #f8f9fa
    static let borderColor = Color("BorderColor") // #dee2e6
    static let textPrimary = Color("TextPrimary") // #000000
    static let textSecondary = Color("TextSecondary") // #6c757d

    // Chart Colors
    static let chart1 = Color("Chart1") // #003f9b
    static let chart2 = Color("Chart2") // #06aeef
    static let chart3 = Color("Chart3") // #4dd0ff
    static let chart4 = Color("Chart4") // #fbbf24
    static let chart5 = Color("Chart5") // #f97316
}
```

### Typography System
```swift
extension Font {
    // Headlines
    static let headline1 = Font.system(size: 32, weight: .bold, design: .default)
    static let headline2 = Font.system(size: 28, weight: .bold, design: .default)
    static let headline3 = Font.system(size: 24, weight: .semibold, design: .default)
    static let headline4 = Font.system(size: 20, weight: .semibold, design: .default)

    // Body Text
    static let bodyLarge = Font.system(size: 18, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 16, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)

    // Captions and Labels
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let label = Font.system(size: 14, weight: .medium, design: .default)

    // Button Text
    static let buttonLarge = Font.system(size: 18, weight: .semibold, design: .default)
    static let buttonMedium = Font.system(size: 16, weight: .semibold, design: .default)
    static let buttonSmall = Font.system(size: 14, weight: .medium, design: .default)
}
```

## Button Components

### Primary Button
```swift
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var size: ButtonSize = .medium

    enum ButtonSize {
        case small, medium, large

        var height: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 48
            case .large: return 56
            }
        }

        var font: Font {
            switch self {
            case .small: return .buttonSmall
            case .medium: return .buttonMedium
            case .large: return .buttonLarge
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(size.font)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .background(
                isEnabled ? Color.primaryBlue : Color.gray
            )
            .cornerRadius(12)
        }
        .disabled(!isEnabled || isLoading)
    }
}

// Usage
PrimaryButton(
    title: "Join Club",
    action: { viewModel.joinClub() },
    isEnabled: viewModel.canJoinClub,
    isLoading: viewModel.isJoining
)
```

### Secondary Button
```swift
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var size: PrimaryButton.ButtonSize = .medium

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(size.font)
                .foregroundColor(isEnabled ? .primaryBlue : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? Color.primaryBlue : Color.gray, lineWidth: 2)
                )
        }
        .disabled(!isEnabled)
    }
}
```

### Icon Button
```swift
struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 44
    var backgroundColor: Color = .clear
    var foregroundColor: Color = .primaryBlue

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
        }
    }
}
```

## Input Components

### Custom Text Field
```swift
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var validator: ((String) -> String?)? = nil

    @State private var errorMessage: String? = nil
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.label)
                .foregroundColor(.textPrimary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.bodyMedium)
            .keyboardType(keyboardType)
            .textFieldStyle(CustomTextFieldStyle(isError: errorMessage != nil))
            .onEditingChanged { editing in
                isEditing = editing
                if !editing {
                    validateInput()
                }
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.errorRed)
            }
        }
    }

    private func validateInput() {
        errorMessage = validator?(text)
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    let isError: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.backgroundSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isError ? Color.errorRed : Color.borderColor, lineWidth: 1)
            )
            .cornerRadius(8)
    }
}
```

### Phone Number Input
```swift
struct PhoneNumberInput: View {
    @Binding var phoneNumber: String
    @State private var countryCode: String = "+91"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phone Number")
                .font(.label)
                .foregroundColor(.textPrimary)

            HStack(spacing: 12) {
                // Country Code Picker
                Menu {
                    Button("+91 🇮🇳") { countryCode = "+91" }
                    Button("+1 🇺🇸") { countryCode = "+1" }
                    Button("+44 🇬🇧") { countryCode = "+44" }
                } label: {
                    HStack {
                        Text(countryCode)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(8)
                }

                // Phone Number Field
                TextField("Enter phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textFieldStyle(CustomTextFieldStyle(isError: false))
            }
        }
    }
}
```

### Search Bar
```swift
struct SearchBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search..."
    var onSearchButtonClicked: (() -> Void)? = nil

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
                .padding(.leading, 12)

            TextField(placeholder, text: $searchText)
                .font(.bodyMedium)
                .onSubmit {
                    onSearchButtonClicked?()
                }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                        .padding(.trailing, 12)
                }
            }
        }
        .frame(height: 44)
        .background(Color.backgroundSecondary)
        .cornerRadius(22)
    }
}
```

## Card Components

### Standard Card
```swift
struct StandardCard<Content: View>: View {
    let content: Content
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 2

    init(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 2,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.backgroundPrimary)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 1)
    }
}
```

### Info Card
```swift
struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    var iconColor: Color = .primaryBlue

    var body: some View {
        StandardCard {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    Text(value)
                        .font(.headline4)
                        .foregroundColor(.textPrimary)
                }

                Spacer()
            }
        }
    }
}
```

### Match Card
```swift
struct MatchCard: View {
    let match: Match
    let onTap: () -> Void

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(match.title)
                        .font(.headline4)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    StatusBadge(status: match.status)
                }

                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.textSecondary)
                    Text(match.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.bodySmall)
                        .foregroundColor(.textSecondary)
                }

                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.textSecondary)
                    Text(match.venue)
                        .font(.bodySmall)
                        .foregroundColor(.textSecondary)
                }

                if let team = match.team {
                    HStack {
                        Image(systemName: "person.3")
                            .foregroundColor(.textSecondary)
                        Text("\(team.selectedPlayers.count)/\(team.maxPlayers) players")
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}
```

## Loading & State Components

### Loading View
```swift
struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryBlue))
                .scaleEffect(1.2)

            Text(message)
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}
```

### Shimmer Effect
```swift
struct ShimmerView: View {
    @State private var isAnimating = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1), Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct ShimmerCard: View {
    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ShimmerView()
                        .frame(width: 150, height: 20)
                        .cornerRadius(4)

                    Spacer()

                    ShimmerView()
                        .frame(width: 60, height: 20)
                        .cornerRadius(10)
                }

                ShimmerView()
                    .frame(height: 16)
                    .cornerRadius(4)

                ShimmerView()
                    .frame(width: 200, height: 16)
                    .cornerRadius(4)
            }
        }
    }
}
```

### Empty State View
```swift
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.textSecondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline3)
                    .foregroundColor(.textPrimary)

                Text(message)
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}
```

### Error View
```swift
struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.errorRed)

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline3)
                    .foregroundColor(.textPrimary)

                Text(error.localizedDescription)
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            PrimaryButton(title: "Try Again", action: retryAction)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}
```

## Badge & Status Components

### Status Badge
```swift
struct StatusBadge: View {
    let status: MatchStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .foregroundColor(status.textColor)
            .cornerRadius(12)
    }
}

extension MatchStatus {
    var displayName: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .live: return "Live"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .upcoming: return .lightBlue.opacity(0.2)
        case .live: return .successGreen.opacity(0.2)
        case .completed: return .textSecondary.opacity(0.2)
        case .cancelled: return .errorRed.opacity(0.2)
        }
    }

    var textColor: Color {
        switch self {
        case .upcoming: return .lightBlue
        case .live: return .successGreen
        case .completed: return .textSecondary
        case .cancelled: return .errorRed
        }
    }
}
```

### Notification Badge
```swift
struct NotificationBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 20, minHeight: 20)
                .background(Color.errorRed)
                .clipShape(Circle())
        }
    }
}
```

## Toast & Alert Components

### Toast Message
```swift
struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool

    enum ToastType {
        case success, error, warning, info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .successGreen
            case .error: return .errorRed
            case .warning: return .warningOrange
            case .info: return .lightBlue
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)

            Text(message)
                .font(.bodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            Button(action: { isShowing = false }) {
                Image(systemName: "xmark")
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.backgroundPrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                isShowing = false
            }
        }
    }
}
```

## Component Implementation Tasks

### Foundation Tasks
- [ ] Implement all color extensions in Assets.xcassets
- [ ] Create typography extension with all font styles
- [ ] Build spacing and sizing constants
- [ ] Create animation presets and transitions
- [ ] Implement accessibility support for all components
- [ ] Add dark mode support for colors

### Button Component Tasks
- [ ] Create PrimaryButton with loading states
- [ ] Implement SecondaryButton and TertiaryButton
- [ ] Build IconButton with various sizes
- [ ] Create FloatingActionButton component
- [ ] Add button press animations and haptic feedback
- [ ] Implement disabled states for all buttons

### Input Component Tasks
- [ ] Build CustomTextField with validation
- [ ] Create PhoneNumberInput with country codes
- [ ] Implement SearchBar with filtering
- [ ] Build DatePicker and TimePicker components
- [ ] Create DropdownPicker and MultiSelectPicker
- [ ] Add TextEditor for long-form content

### Card Component Tasks
- [ ] Create StandardCard as base component
- [ ] Build InfoCard for displaying key-value pairs
- [ ] Implement MatchCard for match displays
- [ ] Create MemberCard for user profiles
- [ ] Build ProductCard for store items
- [ ] Add TransactionCard for financial data

### State Component Tasks
- [ ] Implement LoadingView with custom messages
- [ ] Create ShimmerView and ShimmerCard components
- [ ] Build EmptyStateView with actions
- [ ] Implement ErrorView with retry functionality
- [ ] Create PullToRefreshView
- [ ] Add ProgressIndicator components

### Toast & Alert Tasks
- [ ] Build ToastView with different types
- [ ] Implement custom AlertView
- [ ] Create ActionSheet component
- [ ] Build BottomSheet for mobile-optimized actions
- [ ] Add ConfirmationDialog component
- [ ] Implement SnackBar notifications

These reusable components form the foundation for consistent UI across the entire app.