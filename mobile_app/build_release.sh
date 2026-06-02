#!/bin/bash
# Focus Echo AI — Release Build Script
# Usage: ./build_release.sh

set -e

echo "=== Focus Echo AI Release Build ==="
echo ""

# Check key.properties exists
if [ ! -f "android/app/key.properties" ]; then
    echo "❌ ERROR: android/app/key.properties not found!"
    echo "   1. Generate keystore:"
    echo "      keytool -genkey -v -keystore android/app/focusecho.jks -keyalg RSA -keysize 2048 -validity 10000 -alias focusecho"
    echo "   2. Copy android/app/key.properties.example to android/app/key.properties"
    echo "   3. Fill in your passwords"
    exit 1
fi

# Check for required env vars
if [ -z "$SUPABASE_URL" ]; then
    echo "⚠️  SUPABASE_URL not set. Using default from app_constants.dart"
fi
if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "⚠️  SUPABASE_ANON_KEY not set. Using default from app_constants.dart"
fi

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building release APK..."
flutter build apk --release \
    ${SUPABASE_URL:+--dart-define=SUPABASE_URL=$SUPABASE_URL} \
    ${SUPABASE_ANON_KEY:+--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY} \
    ${BACKEND_URL:+--dart-define=BACKEND_URL=$BACKEND_URL}

echo ""
echo "✅ Release APK built successfully!"
echo "📍 Location: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📦 Building release App Bundle (for Play Store)..."
flutter build appbundle --release \
    ${SUPABASE_URL:+--dart-define=SUPABASE_URL=$SUPABASE_URL} \
    ${SUPABASE_ANON_KEY:+--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY} \
    ${BACKEND_URL:+--dart-define=BACKEND_URL=$BACKEND_URL}

echo ""
echo "✅ App Bundle built successfully!"
echo "📍 Location: build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "🚀 Ready for Play Store upload!"
