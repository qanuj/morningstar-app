# In-App Purchase Subscription Setup Guide

This guide covers setting up subscription products for the Duggy cricket club management app on both iOS (App Store Connect) and Android (Google Play Console).

## Product IDs Overview

The app has three subscription tiers:

1. **Club Starter** - `club_starter_annual` - ₹2,999/year - Up to 30 members
2. **Team Captain** - `team_captain_annual` - ₹4,499/year - Up to 100 members (Recommended)
3. **League Master** - `league_master_annual` - ₹5,999/year - Up to 500 members (Enterprise)

---

## iOS Setup (App Store Connect)

### Prerequisites
- Apple Developer Account
- App registered in App Store Connect
- Agreements, Tax, and Banking information completed

### Step 1: Create Subscription Groups

1. Log into [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** → **Duggy** → **Features** → **In-App Purchases**
3. Click **"+"** → **Auto-Renewable Subscriptions**
4. Create a subscription group:
   - **Reference Name**: `Duggy Club Subscriptions`
   - **Group ID**: `club_subscriptions`

### Step 2: Create Subscription Products

For each subscription tier, create a new auto-renewable subscription:

#### Club Starter Subscription
- **Product ID**: `club_starter_annual`
- **Reference Name**: `Club Starter Annual`
- **Subscription Duration**: 1 Year
- **Price**: Select price tier equivalent to ₹2,999 (approximately $35.99 USD)
- **Subscription Group**: `club_subscriptions`

**Localized Information (English - US):**
- **Display Name**: `Club Starter`
- **Description**: `Perfect for small cricket clubs. Manage up to 30 members with match scheduling, payment tracking, and basic analytics.`

**Localized Information (Hindi - India):**
- **Display Name**: `क्लब स्टार्टर`
- **Description**: `छोटे क्रिकेट क्लबों के लिए आदर्श। 30 सदस्यों तक का प्रबंधन, मैच शेड्यूलिंग, पेमेंट ट्रैकिंग और बेसिक एनालिटिक्स।`

#### Team Captain Subscription
- **Product ID**: `team_captain_annual`
- **Reference Name**: `Team Captain Annual`
- **Subscription Duration**: 1 Year
- **Price**: Select price tier equivalent to ₹4,499 (approximately $53.99 USD)
- **Subscription Group**: `club_subscriptions`

**Localized Information (English - US):**
- **Display Name**: `Team Captain`
- **Description**: `Most popular choice! Manage up to 100 members with advanced analytics, store management, and financial reports.`

**Localized Information (Hindi - India):**
- **Display Name**: `टीम कैप्टन`
- **Description**: `सबसे लोकप्रिय विकल्प! 100 सदस्यों तक का प्रबंधन, एडवांस्ड एनालिटिक्स, स्टोर मैनेजमेंट और फाइनेंसियल रिपोर्ट्स।`

#### League Master Subscription
- **Product ID**: `league_master_annual`
- **Reference Name**: `League Master Annual`
- **Subscription Duration**: 1 Year
- **Price**: Select price tier equivalent to ₹5,999 (approximately $71.99 USD)
- **Subscription Group**: `club_subscriptions`

**Localized Information (English - US):**
- **Display Name**: `League Master`
- **Description**: `Enterprise solution for large clubs. Manage up to 500 members with multiple teams, tournaments, and priority support.`

**Localized Information (Hindi - India):**
- **Display Name**: `लीग मास्टर`
- **Description**: `बड़े क्लबों के लिए एंटरप्राइज़ सोल्यूशन। 500 सदस्यों तक का प्रबंधन, मल्टिपल टीमें, टूर्नामेंट्स और प्राथमिकता सपोर्ट।`

### Step 3: Configure Subscription Options

For each subscription:

1. **Subscription Prices**: Set pricing for India (INR) and other relevant markets
2. **App Review Information**:
   - **Screenshot**: Upload a screenshot showing the subscription selection screen
   - **Review Notes**: "This subscription unlocks premium club management features including member management, match scheduling, and analytics."
3. **Subscription Information**:
   - **Subscription Name**: Use display names from above
   - **Privacy Policy URL**: Add your privacy policy URL

### Step 4: Submit for Review

1. Add subscriptions to a new app version
2. Submit for App Review
3. Subscriptions must be approved before going live

---

## Android Setup (Google Play Console)

### Prerequisites
- Google Play Console Developer Account
- App published on Google Play (at least in internal testing)
- Merchant account set up for payments

### Step 1: Access Subscriptions

1. Log into [Google Play Console](https://play.google.com/console)
2. Select your app (Duggy)
3. Go to **Monetize** → **Products** → **Subscriptions**

### Step 2: Create Base Plans

For each subscription tier, create a new subscription:

#### Club Starter Subscription
1. Click **Create subscription**
2. **Product ID**: `club_starter_annual`
3. **Name**: `Club Starter`
4. **Description**: `Perfect for small cricket clubs. Manage up to 30 members with match scheduling, payment tracking, and basic analytics.`

**Base Plan:**
- **Base plan ID**: `annual`
- **Billing period**: Yearly
- **Price**: ₹2,999.00 INR
- **Free trial**: 7 days (optional)

#### Team Captain Subscription
1. Click **Create subscription**
2. **Product ID**: `team_captain_annual`
3. **Name**: `Team Captain`
4. **Description**: `Most popular choice! Manage up to 100 members with advanced analytics, store management, and financial reports.`

**Base Plan:**
- **Base plan ID**: `annual`
- **Billing period**: Yearly
- **Price**: ₹4,499.00 INR
- **Free trial**: 7 days (optional)

#### League Master Subscription
1. Click **Create subscription**
2. **Product ID**: `league_master_annual`
3. **Name**: `League Master`
4. **Description**: `Enterprise solution for large clubs. Manage up to 500 members with multiple teams, tournaments, and priority support.`

**Base Plan:**
- **Base plan ID**: `annual`
- **Billing period**: Yearly
- **Price**: ₹5,999.00 INR
- **Free trial**: 7 days (optional)

### Step 3: Configure Additional Settings

For each subscription:

1. **Eligibility**:
   - ✅ New subscribers
   - ✅ Returning subscribers

2. **Regional Pricing**:
   - Set prices for other markets (US, UK, etc.)
   - Enable automatic price updates

3. **Taxation**:
   - Configure tax rates for India and other regions

### Step 4: Activate Subscriptions

1. Save each subscription
2. Click **Activate** for each subscription
3. Subscriptions are immediately available for testing

---

## Testing Setup

### iOS Testing (App Store Connect)

1. **Create Sandbox Test Users**:
   - Go to **Users and Access** → **Sandbox** → **Testers**
   - Add test accounts with Indian addresses
   - Use these accounts to test purchases

2. **Test Purchases**:
   - Install app through TestFlight
   - Use sandbox accounts to test subscription flow
   - Verify purchase receipts

### Android Testing (Google Play Console)

1. **License Testing**:
   - Go to **Setup** → **License testing**
   - Add Gmail accounts for testing
   - Set response for test purchases

2. **Internal Testing**:
   - Upload APK to internal testing track
   - Add testers to internal testing
   - Test subscription purchases

---

## Implementation Verification

### Required App Permissions

**iOS (Info.plist):**
```xml
<key>NSAppleMusicUsageDescription</key>
<string>This app uses subscription services for club management features.</string>
```

**Android (android/app/src/main/AndroidManifest.xml):**
```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

### Test Checklist

- [ ] App initializes subscription service correctly
- [ ] All three subscription products load and display
- [ ] Purchase flow works for each subscription tier
- [ ] Success/failure dialogs appear appropriately
- [ ] Subscription status is properly tracked
- [ ] Restore purchases functionality works
- [ ] App handles network errors gracefully

---

## Backend Integration (Required)

You'll need to implement server-side verification:

1. **Receipt Validation**:
   - iOS: Validate receipts with Apple's validation servers
   - Android: Verify purchases with Google Play Developer API

2. **Subscription Status Tracking**:
   - Store subscription status in your database
   - Handle subscription renewals and cancellations
   - Implement webhook handlers for status changes

3. **Club Features Access**:
   - Grant/revoke access based on subscription status
   - Implement subscription checking in your API endpoints

---

## Troubleshooting

### Common Issues

1. **Products not loading**:
   - Verify product IDs match exactly
   - Check that subscriptions are approved/activated
   - Ensure app is signed with correct certificates

2. **Purchase failures**:
   - Verify test accounts are properly configured
   - Check network connectivity
   - Ensure app has billing permissions

3. **Receipt validation errors**:
   - Implement proper error handling
   - Add retry logic for network failures
   - Log detailed error information for debugging

---

## Next Steps

1. Complete store configuration for both platforms
2. Submit iOS subscriptions for review
3. Test thoroughly with sandbox/test accounts
4. Implement backend receipt validation
5. Deploy to production with subscription features enabled

This setup will enable users to subscribe to your club management service directly through the app stores, providing a seamless payment experience.