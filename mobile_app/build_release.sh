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

# Determine configuration defines
DEFINE_ARGS=()
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
    echo "ℹ️  Using environment variables from shell for Supabase configuration."
    DEFINE_ARGS+=(--dart-define="SUPABASE_URL=$SUPABASE_URL")
    DEFINE_ARGS+=(--dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY")
    if [ -n "$BACKEND_URL" ]; then
        DEFINE_ARGS+=(--dart-define="BACKEND_URL=$BACKEND_URL")
    fi
elif [ -f "dart_defines.json" ]; then
    echo "ℹ️  Using dart_defines.json found in mobile_app directory."
    DEFINE_ARGS+=(--dart-define-from-file="dart_defines.json")
elif [ -f "../dart_defines.json" ]; then
    echo "ℹ️  Using dart_defines.json found in project root."
    DEFINE_ARGS+=(--dart-define-from-file="../dart_defines.json")
else
    echo "❌ ERROR: No Supabase configuration found!"
    echo "   Provide credentials either by setting environment variables:"
    echo "     export SUPABASE_URL=\"...\""
    echo "     export SUPABASE_ANON_KEY=\"...\""
    echo "   OR by creating dart_defines.json in mobile_app/ or the repository root."
    exit 1
fi

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building release APK..."
flutter build apk --release "${DEFINE_ARGS[@]}"

echo ""
echo "✅ Release APK built successfully!"
echo "📍 Location: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📦 Building release App Bundle (for Play Store)..."
flutter build appbundle --release "${DEFINE_ARGS[@]}"

echo ""
echo "✅ App Bundle built successfully!"
echo "📍 Location: build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "🚀 Ready for Play Store upload!"
