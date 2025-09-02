# API Configuration Guide

## Overview
The app now supports environment-based API configuration for easy switching between development and production environments.

## Current Setup

### Development Mode (Default)
- **API Base URL**: `http://localhost:3000/api`
- **Debug Prints**: Enabled
- **Logging**: Enabled

### Production Mode  
- **API Base URL**: `https://duggy.app/api`
- **Debug Prints**: Disabled
- **Logging**: Disabled

## Running the App

### Option 1: Use Scripts (Recommended)
```bash
# Development mode (localhost:3000/api)
./scripts/run-dev.sh

# Production mode (duggy.app/api)
./scripts/run-prod.sh
```

### Option 2: Direct Flutter Commands
```bash
# Development mode
flutter run --dart-define=PRODUCTION=false

# Production mode  
flutter run --dart-define=PRODUCTION=true
```

### Option 3: Default Run (Development)
```bash
# Runs in development mode by default
flutter run
```

## Configuration Files

### AppConfig (`lib/config/app_config.dart`)
Central configuration file that manages:
- Environment detection
- API base URLs
- Debug settings
- App metadata

### API Service (`lib/services/api_service.dart`) 
Updated to use `AppConfig.apiBaseUrl` instead of hardcoded URLs.

## Verification

When the app starts, you'll see configuration logs in the console:
```
🔧 App Configuration:
   Environment: Development
   API Base URL: http://localhost:3000/api
   Logging Enabled: true
   Debug Prints: true
```

## Making API Calls

No changes needed in your existing code. All API calls will automatically use the configured base URL:

```dart
// This will call http://localhost:3000/api/auth/login in development
// or https://duggy.app/api/auth/login in production
final response = await ApiService.post('/auth/login', loginData);
```

## Server Setup

Make sure your local server is running on `http://localhost:3000` with the `/api` endpoint available.

Example endpoints:
- `http://localhost:3000/api/auth/login`
- `http://localhost:3000/api/clubs`
- `http://localhost:3000/api/matches`
- etc.