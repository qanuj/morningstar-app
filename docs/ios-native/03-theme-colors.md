# Theme & Color System Implementation

## Overview
Complete implementation guide for the Duggy app's theme system, color palette, typography, spacing, and design tokens using SwiftUI and iOS design principles.

## 🎯 Theme Implementation Tasks

### Color System
- [ ] Create color assets in Xcode Asset Catalog
- [ ] Implement Color extensions for brand colors
- [ ] Add semantic color system for different contexts
- [ ] Create dark mode color variants
- [ ] Implement dynamic color support
- [ ] Add accessibility color contrast validation

### Typography System
- [ ] Define typography scale and font weights
- [ ] Create Font extensions for consistent text styles
- [ ] Implement responsive typography
- [ ] Add accessibility font size support
- [ ] Create text style modifiers
- [ ] Add localization support for fonts

### Design System
- [ ] Create spacing and sizing constants
- [ ] Implement shadow and elevation system
- [ ] Add corner radius and border standards
- [ ] Create animation and transition presets
- [ ] Implement iconography system
- [ ] Add component-specific styling

## Color Asset Catalog Setup

### Asset Catalog Structure
```
Assets.xcassets/
├── Colors/
│   ├── Primary/
│   │   ├── PrimaryBlue.colorset
│   │   ├── LightBlue.colorset
│   │   └── LighterBlue.colorset
│   ├── Status/
│   │   ├── SuccessGreen.colorset
│   │   ├── ErrorRed.colorset
│   │   └── WarningOrange.colorset
│   ├── Neutral/
│   │   ├── BackgroundPrimary.colorset
│   │   ├── BackgroundSecondary.colorset
│   │   ├── BorderColor.colorset
│   │   ├── TextPrimary.colorset
│   │   └── TextSecondary.colorset
│   └── Chart/
│       ├── Chart1.colorset
│       ├── Chart2.colorset
│       ├── Chart3.colorset
│       ├── Chart4.colorset
│       └── Chart5.colorset
```

### Color Set Configuration

#### PrimaryBlue.colorset/Contents.json
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.608",
          "green" : "0.247",
          "red" : "0.000"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.700",
          "green" : "0.350",
          "red" : "0.100"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

#### TextPrimary.colorset/Contents.json
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.000",
          "green" : "0.000",
          "red" : "0.000"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "1.000",
          "green" : "1.000",
          "red" : "1.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

## Color System Implementation

### Color Extensions
```swift
import SwiftUI

// MARK: - Brand Colors
extension Color {
    // Primary Brand Colors
    static let primaryBlue = Color("PrimaryBlue")
    static let lightBlue = Color("LightBlue")
    static let lighterBlue = Color("LighterBlue")

    // Status Colors
    static let successGreen = Color("SuccessGreen")
    static let errorRed = Color("ErrorRed")
    static let warningOrange = Color("WarningOrange")

    // Neutral Colors
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let borderColor = Color("BorderColor")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")

    // Chart Colors for Analytics
    static let chart1 = Color("Chart1")
    static let chart2 = Color("Chart2")
    static let chart3 = Color("Chart3")
    static let chart4 = Color("Chart4")
    static let chart5 = Color("Chart5")
}

// MARK: - Semantic Colors
extension Color {
    // Button States
    static let buttonPrimary = Color.primaryBlue
    static let buttonSecondary = Color.lightBlue
    static let buttonDisabled = Color.textSecondary.opacity(0.3)

    // Form Elements
    static let fieldBackground = Color.backgroundSecondary
    static let fieldBorder = Color.borderColor
    static let fieldFocused = Color.primaryBlue
    static let fieldError = Color.errorRed

    // Navigation
    static let navigationBackground = Color.backgroundPrimary
    static let navigationTitle = Color.textPrimary
    static let navigationTint = Color.primaryBlue

    // Cards and Surfaces
    static let cardBackground = Color.backgroundPrimary
    static let cardBorder = Color.borderColor
    static let cardShadow = Color.black.opacity(0.1)

    // Overlays
    static let overlayBackground = Color.black.opacity(0.5)
    static let overlayContent = Color.backgroundPrimary

    // Highlights
    static let highlightBackground = Color.primaryBlue.opacity(0.1)
    static let highlightBorder = Color.primaryBlue.opacity(0.3)

    // Dividers
    static let dividerPrimary = Color.borderColor
    static let dividerSecondary = Color.borderColor.opacity(0.5)
}

// MARK: - Context-Specific Colors
extension Color {
    // Match Status Colors
    static let matchUpcoming = Color.lightBlue
    static let matchLive = Color.successGreen
    static let matchCompleted = Color.textSecondary
    static let matchCancelled = Color.errorRed

    // Transaction Colors
    static let transactionCredit = Color.successGreen
    static let transactionDebit = Color.errorRed
    static let transactionPending = Color.warningOrange

    // Member Role Colors
    static let roleOwner = Color.chart5
    static let roleAdmin = Color.chart4
    static let roleModerator = Color.chart3
    static let roleMember = Color.textSecondary

    // Priority Colors
    static let priorityHigh = Color.errorRed
    static let priorityMedium = Color.warningOrange
    static let priorityLow = Color.successGreen
}

// MARK: - Color Utilities
extension Color {
    /// Creates a color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Returns a lighter version of the color
    func lighter(by percentage: Double = 0.2) -> Color {
        return self.opacity(1.0 - percentage)
    }

    /// Returns a darker version of the color
    func darker(by percentage: Double = 0.2) -> Color {
        // This is a simplified implementation
        // For more accurate color manipulation, use HSB color space
        return Color(red: max(0, self.cgColor?.components?[0] ?? 0 - percentage),
                    green: max(0, self.cgColor?.components?[1] ?? 0 - percentage),
                    blue: max(0, self.cgColor?.components?[2] ?? 0 - percentage))
    }
}

// MARK: - UIColor Bridge
extension UIColor {
    // Convert SwiftUI Color to UIColor for UIKit integration
    static let primaryBlue = UIColor(Color.primaryBlue)
    static let lightBlue = UIColor(Color.lightBlue)
    static let successGreen = UIColor(Color.successGreen)
    static let errorRed = UIColor(Color.errorRed)
    static let warningOrange = UIColor(Color.warningOrange)
    static let backgroundPrimary = UIColor(Color.backgroundPrimary)
    static let textPrimary = UIColor(Color.textPrimary)
    static let textSecondary = UIColor(Color.textSecondary)
}
```

## Typography System

### Font Extensions
```swift
import SwiftUI

extension Font {
    // MARK: - Display Fonts (Large Headings)
    static let display1 = Font.system(size: 40, weight: .bold, design: .default)
    static let display2 = Font.system(size: 36, weight: .bold, design: .default)
    static let display3 = Font.system(size: 32, weight: .bold, design: .default)

    // MARK: - Headline Fonts
    static let headline1 = Font.system(size: 28, weight: .bold, design: .default)
    static let headline2 = Font.system(size: 24, weight: .bold, design: .default)
    static let headline3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let headline4 = Font.system(size: 18, weight: .semibold, design: .default)

    // MARK: - Body Text
    static let bodyXLarge = Font.system(size: 20, weight: .regular, design: .default)
    static let bodyLarge = Font.system(size: 18, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 16, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
    static let bodyXSmall = Font.system(size: 12, weight: .regular, design: .default)

    // MARK: - Label Text
    static let labelLarge = Font.system(size: 16, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 14, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 12, weight: .medium, design: .default)

    // MARK: - Caption Text
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 10, weight: .regular, design: .default)

    // MARK: - Button Text
    static let buttonLarge = Font.system(size: 18, weight: .semibold, design: .default)
    static let buttonMedium = Font.system(size: 16, weight: .semibold, design: .default)
    static let buttonSmall = Font.system(size: 14, weight: .medium, design: .default)

    // MARK: - Numeric Fonts (for better number display)
    static let numericLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
    static let numericMedium = Font.system(size: 18, weight: .semibold, design: .monospaced)
    static let numericSmall = Font.system(size: 14, weight: .medium, design: .monospaced)
}

// MARK: - Typography Modifiers
struct TypographyModifier: ViewModifier {
    let style: TypographyStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .foregroundColor(style.color)
            .lineSpacing(style.lineSpacing)
            .tracking(style.letterSpacing)
    }
}

enum TypographyStyle {
    case display1, display2, display3
    case headline1, headline2, headline3, headline4
    case bodyXLarge, bodyLarge, bodyMedium, bodySmall, bodyXSmall
    case labelLarge, labelMedium, labelSmall
    case caption, caption2
    case buttonLarge, buttonMedium, buttonSmall

    var font: Font {
        switch self {
        case .display1: return .display1
        case .display2: return .display2
        case .display3: return .display3
        case .headline1: return .headline1
        case .headline2: return .headline2
        case .headline3: return .headline3
        case .headline4: return .headline4
        case .bodyXLarge: return .bodyXLarge
        case .bodyLarge: return .bodyLarge
        case .bodyMedium: return .bodyMedium
        case .bodySmall: return .bodySmall
        case .bodyXSmall: return .bodyXSmall
        case .labelLarge: return .labelLarge
        case .labelMedium: return .labelMedium
        case .labelSmall: return .labelSmall
        case .caption: return .caption
        case .caption2: return .caption2
        case .buttonLarge: return .buttonLarge
        case .buttonMedium: return .buttonMedium
        case .buttonSmall: return .buttonSmall
        }
    }

    var color: Color {
        switch self {
        case .display1, .display2, .display3, .headline1, .headline2, .headline3, .headline4:
            return .textPrimary
        case .bodyXLarge, .bodyLarge, .bodyMedium:
            return .textPrimary
        case .bodySmall, .bodyXSmall, .caption, .caption2:
            return .textSecondary
        case .labelLarge, .labelMedium, .labelSmall:
            return .textPrimary
        case .buttonLarge, .buttonMedium, .buttonSmall:
            return .white
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .display1, .display2, .display3: return 4
        case .headline1, .headline2: return 2
        case .headline3, .headline4: return 1
        case .bodyXLarge, .bodyLarge: return 2
        case .bodyMedium, .bodySmall, .bodyXSmall: return 1
        default: return 0
        }
    }

    var letterSpacing: CGFloat {
        switch self {
        case .display1, .display2, .display3: return -0.5
        case .headline1, .headline2: return -0.25
        case .labelLarge, .labelMedium, .labelSmall: return 0.1
        case .caption, .caption2: return 0.4
        default: return 0
        }
    }
}

extension View {
    func typography(_ style: TypographyStyle) -> some View {
        self.modifier(TypographyModifier(style: style))
    }
}

// MARK: - Dynamic Type Support
extension Font {
    static func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        return Font.system(size: size, weight: weight, design: design)
    }

    static func adaptiveFont(
        small: CGFloat,
        medium: CGFloat,
        large: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        // Simplified adaptive font - in production, use size classes
        return Font.system(size: medium, weight: weight)
    }
}
```

## Spacing and Layout System

### Spacing Constants
```swift
import SwiftUI

struct Spacing {
    // Base spacing unit (4pt)
    static let unit: CGFloat = 4

    // Semantic spacing values
    static let xxxs: CGFloat = unit      // 4pt
    static let xxs: CGFloat = unit * 2   // 8pt
    static let xs: CGFloat = unit * 3    // 12pt
    static let sm: CGFloat = unit * 4    // 16pt
    static let md: CGFloat = unit * 5    // 20pt
    static let lg: CGFloat = unit * 6    // 24pt
    static let xl: CGFloat = unit * 8    // 32pt
    static let xxl: CGFloat = unit * 10  // 40pt
    static let xxxl: CGFloat = unit * 12 // 48pt

    // Component-specific spacing
    static let cardPadding: CGFloat = sm
    static let sectionSpacing: CGFloat = lg
    static let itemSpacing: CGFloat = xs
    static let buttonHeight: CGFloat = 48
    static let inputHeight: CGFloat = 44

    // Screen margins
    static let screenHorizontal: CGFloat = sm
    static let screenVertical: CGFloat = md

    // Safe area adjustments
    static let safeAreaTop: CGFloat = xxs
    static let safeAreaBottom: CGFloat = lg
}

struct CornerRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24

    // Component-specific
    static let button: CGFloat = md
    static let card: CGFloat = md
    static let input: CGFloat = sm
    static let modal: CGFloat = lg
    static let image: CGFloat = sm
}

struct BorderWidth {
    static let thin: CGFloat = 0.5
    static let regular: CGFloat = 1
    static let thick: CGFloat = 2
    static let bold: CGFloat = 3

    // Component-specific
    static let button: CGFloat = regular
    static let input: CGFloat = regular
    static let card: CGFloat = thin
    static let divider: CGFloat = thin
}

struct Shadow {
    static let none = Color.clear
    static let xs = Color.black.opacity(0.05)
    static let sm = Color.black.opacity(0.10)
    static let md = Color.black.opacity(0.15)
    static let lg = Color.black.opacity(0.20)
    static let xl = Color.black.opacity(0.25)

    // Shadow configurations
    struct Config {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let none = Config(color: .clear, radius: 0, x: 0, y: 0)
        static let xs = Config(color: Shadow.xs, radius: 2, x: 0, y: 1)
        static let sm = Config(color: Shadow.sm, radius: 4, x: 0, y: 2)
        static let md = Config(color: Shadow.md, radius: 6, x: 0, y: 3)
        static let lg = Config(color: Shadow.lg, radius: 8, x: 0, y: 4)
        static let xl = Config(color: Shadow.xl, radius: 12, x: 0, y: 6)
    }
}

// MARK: - Layout Modifiers
extension View {
    func spacing(_ value: CGFloat) -> some View {
        self.padding(value)
    }

    func cardStyle() -> some View {
        self
            .padding(Spacing.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(CornerRadius.card)
            .shadow(color: Shadow.Config.sm.color, radius: Shadow.Config.sm.radius, x: Shadow.Config.sm.x, y: Shadow.Config.sm.y)
    }

    func buttonStyle(size: ButtonSize = .medium) -> some View {
        self
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .background(Color.buttonPrimary)
            .foregroundColor(.white)
            .cornerRadius(CornerRadius.button)
    }

    func inputStyle(isError: Bool = false) -> some View {
        self
            .frame(height: Spacing.inputHeight)
            .padding(.horizontal, Spacing.xs)
            .background(Color.fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.input)
                    .stroke(isError ? Color.fieldError : Color.fieldBorder, lineWidth: BorderWidth.input)
            )
    }
}

enum ButtonSize {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 52
        }
    }
}
```

## Animation and Transition System

### Animation Presets
```swift
import SwiftUI

struct AnimationPresets {
    // Standard animations
    static let quick = Animation.easeOut(duration: 0.2)
    static let standard = Animation.easeInOut(duration: 0.3)
    static let slow = Animation.easeInOut(duration: 0.5)

    // Spring animations
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.25)
    static let springSmooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.25)
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.15)

    // Specialized animations
    static let buttonPress = Animation.easeOut(duration: 0.1)
    static let modalPresent = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let loading = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    static let shimmer = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)

    // Page transitions
    static let pageTransition = Animation.easeInOut(duration: 0.4)
    static let tabTransition = Animation.easeOut(duration: 0.25)
}

struct TransitionPresets {
    static let slide = AnyTransition.move(edge: .trailing)
    static let fade = AnyTransition.opacity
    static let scale = AnyTransition.scale
    static let slideUp = AnyTransition.move(edge: .bottom)
    static let slideDown = AnyTransition.move(edge: .top)

    // Combined transitions
    static let slideAndFade = AnyTransition.slide.combined(with: .fade)
    static let scaleAndFade = AnyTransition.scale.combined(with: .fade)

    // Modal transitions
    static let modal = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )

    static let sheet = AnyTransition.move(edge: .bottom)
}

// MARK: - Animation Modifiers
extension View {
    func quickAnimation() -> some View {
        self.animation(AnimationPresets.quick, value: UUID())
    }

    func standardAnimation() -> some View {
        self.animation(AnimationPresets.standard, value: UUID())
    }

    func springAnimation() -> some View {
        self.animation(AnimationPresets.springSmooth, value: UUID())
    }

    func pressAnimation() -> some View {
        self.animation(AnimationPresets.buttonPress, value: UUID())
    }
}
```

## Theme Manager

### Theme Manager Implementation
```swift
import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .light
    @Published var accentColor: Color = .primaryBlue

    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    private let accentColorKey = "accent_color"

    init() {
        loadTheme()
        observeSystemThemeChanges()
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        userDefaults.set(theme.rawValue, forKey: themeKey)

        // Apply theme to UIKit components
        applyThemeToUIKit()
    }

    func setAccentColor(_ color: Color) {
        accentColor = color
        userDefaults.set(color.toHex(), forKey: accentColorKey)
    }

    private func loadTheme() {
        if let themeString = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: themeString) {
            currentTheme = theme
        } else {
            currentTheme = .system
        }

        if let colorHex = userDefaults.string(forKey: accentColorKey) {
            accentColor = Color(hex: colorHex)
        }
    }

    private func observeSystemThemeChanges() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                if self?.currentTheme == .system {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    private func applyThemeToUIKit() {
        DispatchQueue.main.async {
            // Update navigation bar appearance
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.navigationBackground)
            appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.navigationTitle)]

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance

            // Update tab bar appearance
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(Color.backgroundPrimary)

            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

            // Update window background
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.backgroundColor = UIColor(Color.backgroundPrimary)
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
}

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Color Hex Conversion
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(format: "#%02X%02X%02X",
                     Int(red * 255),
                     Int(green * 255),
                     Int(blue * 255))
    }
}
```

## Accessibility Support

### Accessibility Extensions
```swift
import SwiftUI

extension View {
    func accessibleColors() -> some View {
        self.modifier(AccessibleColorModifier())
    }

    func highContrastColors() -> some View {
        self.modifier(HighContrastModifier())
    }

    func dynamicTypeSupport() -> some View {
        self.modifier(DynamicTypeModifier())
    }
}

struct AccessibleColorModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityInvertColors) var invertColors

    func body(content: Content) -> some View {
        content
            .foregroundColor(adaptiveTextColor)
            .background(adaptiveBackgroundColor)
    }

    private var adaptiveTextColor: Color {
        if invertColors {
            return .white
        }
        return .textPrimary
    }

    private var adaptiveBackgroundColor: Color {
        if reduceTransparency {
            return .backgroundPrimary
        }
        return .backgroundPrimary.opacity(0.95)
    }
}

struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        content
            .foregroundColor(highContrastTextColor)
            .background(highContrastBackgroundColor)
            .overlay(
                differentiateWithoutColor ?
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(Color.textPrimary, lineWidth: BorderWidth.thick) :
                nil
            )
    }

    private var highContrastTextColor: Color {
        return differentiateWithoutColor ? .black : .textPrimary
    }

    private var highContrastBackgroundColor: Color {
        return differentiateWithoutColor ? .white : .backgroundPrimary
    }
}

struct DynamicTypeModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory

    func body(content: Content) -> some View {
        content
            .font(adaptiveFont)
            .lineLimit(adaptiveLineLimit)
    }

    private var adaptiveFont: Font {
        switch sizeCategory {
        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
            return .bodyLarge
        case .extraSmall, .small:
            return .bodySmall
        default:
            return .bodyMedium
        }
    }

    private var adaptiveLineLimit: Int? {
        switch sizeCategory {
        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
            return nil // Remove line limits for accessibility
        default:
            return 2
        }
    }
}
```

## Theme Implementation Tasks

### Color System Tasks
- [ ] Create all color assets in Xcode Asset Catalog
- [ ] Implement Color extensions with brand colors
- [ ] Add semantic color system for contexts
- [ ] Create dark mode color variants
- [ ] Implement accessibility color support
- [ ] Add color contrast validation

### Typography Tasks
- [ ] Define complete typography scale
- [ ] Create Font extensions with semantic naming
- [ ] Implement typography modifiers
- [ ] Add dynamic type support
- [ ] Create accessibility font scaling
- [ ] Add localization font support

### Spacing & Layout Tasks
- [ ] Create spacing constant system
- [ ] Implement corner radius standards
- [ ] Add shadow and elevation system
- [ ] Create layout modifier utilities
- [ ] Implement responsive spacing
- [ ] Add component-specific spacing

### Animation Tasks
- [ ] Create animation preset library
- [ ] Implement transition presets
- [ ] Add animation modifier utilities
- [ ] Create loading and shimmer animations
- [ ] Implement interactive animations
- [ ] Add performance optimizations

### Theme Management Tasks
- [ ] Create ThemeManager class
- [ ] Implement theme switching functionality
- [ ] Add accent color customization
- [ ] Create UIKit integration
- [ ] Implement theme persistence
- [ ] Add system theme detection

### Accessibility Tasks
- [ ] Create accessibility color modifiers
- [ ] Implement high contrast support
- [ ] Add dynamic type scaling
- [ ] Create VoiceOver optimizations
- [ ] Implement reduce motion support
- [ ] Add accessibility testing utilities

This comprehensive theme system provides a solid foundation for consistent, accessible, and beautiful UI throughout the entire iOS app.