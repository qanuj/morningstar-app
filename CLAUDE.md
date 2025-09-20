# CLAUDE.md - Duggy Flutter App Complete Design & Implementation Guide

## Project Overview

**Duggy** is a comprehensive cricket club management mobile application built with Flutter. It provides feature-rich management tools for both club members and club owners, matching all web app functionality with a modern, smooth mobile experience.

---

## Brand Identity & Colors (Web Project Integration)

### Primary Color Palette
- **Primary Blue**: `#003f9b` - Main brand color, headers, primary buttons
- **Light Blue**: `#06aeef` - Secondary actions, active states, highlights
- **Lighter Blue**: `#4dd0ff` - Tertiary accents, subtle highlights
- **Success Green**: `#16a34a` - Success states, confirmations
- **Error Red**: `#dc2626` - Error states, destructive actions
- **Warning Orange**: `#f59e0b` - Warning states, pending actions

### Neutral System
- **Background**: `#ffffff` - Primary background
- **Card**: `#ffffff` - Card/container backgrounds
- **Secondary**: `#f8f9fa` - Light backgrounds, disabled states
- **Border**: `#dee2e6` - Borders, dividers, separators
- **Text Primary**: `#000000` - Main headings, primary text
- **Text Secondary**: `#6c757d` - Supporting text, descriptions

### Chart Colors (for analytics)
- **Chart 1**: `#003f9b` - Primary data
- **Chart 2**: `#06aeef` - Secondary data
- **Chart 3**: `#4dd0ff` - Tertiary data
- **Chart 4**: `#fbbf24` - Accent data
- **Chart 5**: `#f97316` - Warning data

---

## Complete Screen Architecture

### Phase 1: Authentication & Core Navigation
**Priority**: Critical - Must be implemented first

#### Screens Required:
1. **Splash Screen** ✅ (Existing)
   - Brand logo animation
   - App initialization
   - Auto-login check

2. **Login Screen** ⚠️ (Needs modernization)
   - Phone number input
   - OTP request
   - Brand integration
   - Compact, modern UI

3. **OTP Verification** ✅ (Existing)
   - OTP input field
   - Resend functionality
   - Timer countdown

4. **Main Navigation Shell**
   - Bottom tab navigation
   - Role-based tab visibility
   - Drawer navigation
   - Navigation state management

### Phase 2: Core Member Features
**Priority**: High - Essential member functionality

#### Screens Required:
5. **Home/Dashboard** 🆕
   - Quick overview widgets
   - Recent activities
   - Upcoming matches preview
   - Balance display
   - Quick actions

6. **Matches Screen** ✅ (Existing - needs enhancement)
   - Match list (upcoming/past)
   - Match details modal
   - Team selection view
   - Match statistics
   - Results and scorecards

7. **Store Screen** ✅ (Existing - needs enhancement)
   - Product categories
   - Product grid/list view
   - Product detail screen
   - Shopping cart
   - Wishlist functionality

8. **My Orders Screen** ✅ (Existing - needs enhancement)
   - Order history list
   - Order detail view
   - Order tracking
   - Invoice/receipt view
   - Return/refund requests

9. **Profile Screen** ✅ (Existing - needs enhancement)
   - Profile information display
   - Edit profile screen
   - Profile picture upload
   - Settings menu
   - Account preferences

### Phase 3: Financial & Transaction Management
**Priority**: High - Financial transparency

#### Screens Required:
10. **Transactions Screen** ✅ (Existing - needs enhancement)
    - Transaction history
    - Filter options (date, type, amount)
    - Transaction details
    - Receipt generation
    - Balance tracking

11. **Wallet/Balance Screen** 🆕
    - Current balance display
    - Add money functionality
    - Payment methods
    - Transaction history
    - Automatic payment setup

12. **Payment Screens** 🆕
    - Payment method selection
    - Card/UPI payment forms
    - Payment confirmation
    - Payment success/failure
    - Receipt generation

### Phase 4: Social & Engagement Features
**Priority**: Medium - Community engagement

#### Screens Required:
13. **Polls Screen** ✅ (Existing - needs enhancement)
    - Active polls list
    - Poll detail view
    - Voting interface
    - Results visualization
    - Poll history

14. **Notifications Screen** ✅ (Existing - needs enhancement)
    - Notification list
    - Read/unread states
    - Notification categories
    - Action buttons
    - Notification preferences

15. **Club Directory** 🆕
    - Member list
    - Member profiles
    - Contact information
    - Role indicators
    - Search functionality

16. **Chat/Messages** 🆕
    - Club announcements
    - Team discussions
    - Direct messaging
    - File sharing
    - Message history

### Phase 5: Advanced Member Features
**Priority**: Medium - Enhanced functionality

#### Screens Required:
17. **Statistics Dashboard** 🆕
    - Personal performance stats
    - Match participation
    - Spending analytics
    - Achievement badges
    - Progress tracking

18. **Calendar/Schedule** 🆕
    - Match calendar
    - Training sessions
    - Club events
    - Personal availability
    - Reminder settings

19. **Equipment Management** 🆕
    - Equipment requests
    - Booking system
    - Availability tracking
    - Return management
    - Damage reports

---

## Club Owner Exclusive Features

### Phase 6: Club Administration
**Priority**: High - Owner management tools

#### Screens Required:
20. **Admin Dashboard** 🆕
    - Club overview metrics
    - Recent activities
    - Quick actions
    - Financial summary
    - Member statistics

21. **Member Management** 🆕
    - Member list with roles
    - Member details view
    - Role assignment
    - Membership approval
    - Member activity tracking

22. **Club Settings** 🆕
    - Club profile editing
    - Logo/banner management
    - Contact information
    - Membership fees
    - Club rules/policies

### Phase 7: Financial Management (Owner)
**Priority**: High - Business management

#### Screens Required:
23. **Financial Dashboard** 🆕
    - Revenue analytics
    - Expense tracking
    - Profit/loss reports
    - Member payment status
    - Financial forecasting

24. **Payment Management** 🆕
    - Payment collection
    - Due reminders
    - Payment methods setup
    - Refund processing
    - Financial reporting

25. **Expense Management** 🆕
    - Add expenses
    - Expense categories
    - Receipt uploads
    - Approval workflows
    - Budget tracking

### Phase 8: Content & Match Management (Owner)
**Priority**: High - Operational management

#### Screens Required:
26. **Match Management** 🆕
    - Create/schedule matches
    - Team selection interface
    - Match result entry
    - Performance tracking
    - Opposition management

27. **Store Management** 🆕
    - Product catalog management
    - Inventory tracking
    - Order processing
    - Pricing management
    - Supplier management

28. **Content Management** 🆕
    - News/announcements
    - Photo gallery
    - Document library
    - Club policies
    - Training materials

### Phase 9: Analytics & Reporting (Owner)
**Priority**: Medium - Business intelligence

#### Screens Required:
29. **Analytics Dashboard** 🆕
    - Member engagement metrics
    - Financial performance
    - Match statistics
    - Store performance
    - Growth trends

30. **Report Generation** 🆕
    - Custom report builder
    - Export functionality
    - Scheduled reports
    - Report templates
    - Data visualization

---

## Navigation Architecture

### Bottom Tab Navigation (Role-Based)

#### For Club Members:
```dart
enum MemberTabs {
  home,      // Dashboard overview
  matches,   // Match schedules & results
  store,     // Club merchandise
  wallet,    // Transactions & payments
  profile    // Personal settings
}
```

#### For Club Owners:
```dart
enum OwnerTabs {
  dashboard, // Admin overview
  members,   // Member management
  matches,   // Match management
  finance,   // Financial management
  settings   // Club settings
}
```

### Drawer Navigation (Secondary)

#### Common Sections:
- **Profile Header** (user info + role badge)
- **Quick Actions** (context-sensitive)
- **Features** (full feature list)
- **Support & Settings**
- **Logout**

#### Role-Specific Features:
- **Members**: Calendar, Statistics, Directory, Help
- **Owners**: Analytics, Reports, Content Management, System Settings

---

## Implementation Phases & Todo List

### 🔴 Phase 1: Foundation (Weeks 1-2)
**Critical Priority - Must Complete First**

#### Authentication & Navigation
- [ ] Update Flutter theme with web project colors
- [ ] Modernize login screen with new branding
- [ ] Implement role-based bottom tab navigation
- [ ] Create navigation state management
- [ ] Add user role detection and routing
- [ ] Implement secure token management
- [ ] Add biometric authentication option
- [ ] Create navigation transition animations

#### Core Infrastructure
- [ ] Set up unified API service layer
- [ ] Implement proper error handling
- [ ] Add offline capability framework
- [ ] Set up push notification service
- [ ] Create app state management structure
- [ ] Add logging and analytics
- [ ] Implement app version management
- [ ] Create build configuration

### 🟠 Phase 2: Core Features (Weeks 3-4)
**High Priority - Essential Functionality**

#### Dashboard & Home
- [ ] Create responsive dashboard layout
- [ ] Implement quick stats widgets
- [ ] Add recent activity feed
- [ ] Create balance/wallet overview
- [ ] Add upcoming matches preview
- [ ] Implement quick action buttons
- [ ] Add pull-to-refresh functionality
- [ ] Create loading states and shimmer effects

#### Enhanced Existing Screens
- [ ] Modernize matches screen with filters
- [ ] Add match detail modal with full stats
- [ ] Enhance store with categories and search
- [ ] Implement shopping cart functionality
- [ ] Upgrade orders screen with tracking
- [ ] Add order detail modals
- [ ] Enhance profile with image upload
- [ ] Add profile editing capabilities

### 🟡 Phase 3: Financial System (Weeks 5-6)
**High Priority - Payment Integration**

#### Payment & Wallet
- [ ] Create wallet/balance management screen
- [ ] Implement add money functionality
- [ ] Add payment method selection
- [ ] Integrate UPI/card payment gateways
- [ ] Create payment confirmation flows
- [ ] Add transaction receipt generation
- [ ] Implement automatic payment setup
- [ ] Add payment failure recovery

#### Transaction Management
- [ ] Enhanced transaction history with filters
- [ ] Add transaction categorization
- [ ] Implement search functionality
- [ ] Create detailed transaction views
- [ ] Add receipt download/share
- [ ] Implement expense tracking
- [ ] Add budget alerts
- [ ] Create financial reporting

### 🟢 Phase 4: Social Features (Weeks 7-8)
**Medium Priority - Community Engagement**

#### Communication & Social
- [ ] Enhanced polls with rich voting
- [ ] Add poll creation (for owners)
- [ ] Implement notification system
- [ ] Create club member directory
- [ ] Add basic messaging system
- [ ] Implement club announcements
- [ ] Create event calendar
- [ ] Add social sharing features

#### Engagement Features
- [ ] Personal statistics dashboard
- [ ] Achievement badge system
- [ ] Member activity tracking
- [ ] Create leaderboards
- [ ] Add gamification elements
- [ ] Implement referral system
- [ ] Create feedback collection
- [ ] Add rating systems

### 🔵 Phase 5: Advanced Features (Weeks 9-10)
**Medium Priority - Enhanced Functionality**

#### Advanced Member Tools
- [ ] Equipment booking system
- [ ] Training session management
- [ ] Personal performance analytics
- [ ] Availability calendar
- [ ] Skills tracking
- [ ] Fitness monitoring
- [ ] Goal setting and tracking
- [ ] Progress visualization

#### Content & Media
- [ ] Photo gallery with upload
- [ ] Video content support
- [ ] Document library access
- [ ] News and updates feed
- [ ] File sharing capabilities
- [ ] Media categorization
- [ ] Content search
- [ ] Offline content access

### 🟣 Phase 6: Owner Administration (Weeks 11-12)
**Owner-Specific Features**

#### Club Management
- [ ] Admin dashboard with key metrics
- [ ] Member management interface
- [ ] Role assignment system
- [ ] Membership approval workflow
- [ ] Club settings configuration
- [ ] Logo and branding management
- [ ] Contact information management
- [ ] Club policy management

#### Member Administration
- [ ] Member onboarding workflow
- [ ] Membership renewal system
- [ ] Member activity monitoring
- [ ] Communication tools for admins
- [ ] Member feedback collection
- [ ] Discipline management
- [ ] Member statistics and reports
- [ ] Bulk operations on members

### 🟤 Phase 7: Financial Management (Weeks 13-14)
**Owner Financial Tools**

#### Revenue & Finance
- [ ] Financial dashboard with analytics
- [ ] Revenue tracking and forecasting
- [ ] Expense management system
- [ ] Budget planning tools
- [ ] Payment collection interface
- [ ] Due payment reminders
- [ ] Financial report generation
- [ ] Tax calculation support

#### Payment Processing
- [ ] Payment method configuration
- [ ] Refund processing system
- [ ] Payment gateway management
- [ ] Transaction monitoring
- [ ] Fraud detection alerts
- [ ] Financial audit trails
- [ ] Automated billing system
- [ ] Payment analytics

### ⚫ Phase 8: Content & Operations (Weeks 15-16)
**Operational Management**

#### Match & Event Management
- [ ] Match scheduling interface
- [ ] Team selection tools
- [ ] Match result entry system
- [ ] Performance tracking
- [ ] Opposition team management
- [ ] Venue management
- [ ] Weather integration
- [ ] Match statistics analysis

#### Store & Inventory
- [ ] Product catalog management
- [ ] Inventory tracking system
- [ ] Order processing workflow
- [ ] Pricing management tools
- [ ] Supplier management
- [ ] Stock alerts and reordering
- [ ] Product analytics
- [ ] Promotional tools

### 🔶 Phase 9: Analytics & Intelligence (Weeks 17-18)
**Business Intelligence**

#### Analytics Dashboard
- [ ] Member engagement analytics
- [ ] Financial performance metrics
- [ ] Match and team statistics
- [ ] Store and sales analytics
- [ ] Growth trend analysis
- [ ] Predictive analytics
- [ ] Custom metric creation
- [ ] Real-time monitoring

#### Reporting System
- [ ] Custom report builder
- [ ] Automated report generation
- [ ] Report scheduling system
- [ ] Export functionality (PDF, Excel)
- [ ] Data visualization tools
- [ ] Historical data analysis
- [ ] Comparative reporting
- [ ] Report sharing system

---

## Technical Implementation Guidelines

### Performance Targets
- **App Launch**: < 3 seconds cold start
- **Screen Transitions**: < 300ms smooth animations
- **API Response Handling**: < 2 seconds with loading states
- **Image Loading**: Progressive with caching
- **Memory Usage**: < 150MB average
- **Battery Optimization**: Background processing limits

### Code Quality Standards
- **Architecture**: Clean Architecture with Provider
- **State Management**: Provider for app state, Local storage for persistence
- **API Layer**: Centralized service with error handling
- **Testing**: Unit tests for business logic, Widget tests for UI
- **Documentation**: Inline documentation for all public methods
- **Code Review**: All features require review before merge

### Security Implementation
- **Authentication**: JWT tokens with refresh mechanism
- **Data Storage**: Sensitive data in secure storage only
- **API Communication**: HTTPS only, certificate pinning
- **User Input**: All inputs validated and sanitized
- **Permissions**: Minimum required permissions only
- **Biometric**: Optional biometric authentication
- **Session Management**: Automatic logout on inactivity

---

## Quality Assurance Checklist

### UI/UX Testing
- [ ] All screens responsive on different device sizes
- [ ] Navigation flows intuitive and consistent
- [ ] Loading states implemented for all async operations
- [ ] Error states handled gracefully
- [ ] Offline functionality where applicable
- [ ] Accessibility compliance (screen readers, color contrast)
- [ ] Performance smooth on older devices
- [ ] Battery usage optimized

### Functional Testing
- [ ] All API endpoints properly integrated
- [ ] Authentication flow secure and reliable
- [ ] Role-based access control working correctly
- [ ] Payment flows tested end-to-end
- [ ] Data persistence working correctly
- [ ] Push notifications functioning
- [ ] File upload/download working
- [ ] Search functionality accurate

### Security Testing
- [ ] No sensitive data in logs
- [ ] Secure storage implementation verified
- [ ] API authentication working correctly
- [ ] Input validation preventing injection attacks
- [ ] Session management secure
- [ ] Biometric authentication (if implemented) secure
- [ ] App permissions appropriate
- [ ] Data encryption in transit and at rest

---

This comprehensive guide ensures the Flutter app achieves 100% feature parity with the web application while providing a superior mobile experience. Each phase builds upon the previous, ensuring stable and progressive development.
- do not dun flutter on device. I'll run myself.