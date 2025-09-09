#!/bin/bash

# iOS Release Build Script for Duggy App
# This script builds the iOS app with production API configuration

echo "🚀 Building iOS Release with Production API..."
echo "📡 API URL will be: https://duggy.app/api"
echo "🔧 Using kReleaseMode detection for Xcode compatibility"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Build release version (automatically uses production API in release mode)
echo "🔨 Building iOS release..."
flutter build ios --release --no-codesign

if [ $? -eq 0 ]; then
    echo "✅ iOS Release build completed successfully!"
    echo "📱 Built app is ready at: build/ios/iphoneos/Runner.app"
    echo "🔧 Remember to sign the app before deployment to device/App Store"
    echo "✨ Xcode Archive will now automatically use production API!"
else
    echo "❌ Build failed!"
    exit 1
fi