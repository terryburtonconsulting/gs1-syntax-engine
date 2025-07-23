#!/bin/bash

echo "=== Building All Available Platforms ==="

BUILD_SUCCESS=0
BUILD_ATTEMPTED=0

# Function to attempt a build and track results
attempt_build() {
    local platform="$1"
    local script="$2"
    local requirements="$3"
    
    echo
    echo "🚀 Attempting $platform build..."
    
    if eval "$script"; then
        echo "✅ $platform build successful"
        BUILD_SUCCESS=$((BUILD_SUCCESS + 1))
    else
        echo "❌ $platform build failed"
        if [ ! -z "$requirements" ]; then
            echo "   Requirements: $requirements"
        fi
    fi
    
    BUILD_ATTEMPTED=$((BUILD_ATTEMPTED + 1))
}

# Linux build (works on Linux/macOS/WSL with cross-compilers)
if command -v gcc >/dev/null 2>&1; then
    attempt_build "Linux" "./build-linux.sh" "gcc cross-compilation tools"
else
    echo "⚠️  GCC not found, skipping Linux build"
fi

# Android build (works anywhere with NDK)
if [ ! -z "$ANDROID_NDK_ROOT" ] && [ -d "$ANDROID_NDK_ROOT" ]; then
    attempt_build "Android" "./build-android.sh" "Android NDK at \$ANDROID_NDK_ROOT"
else
    echo "⚠️  Android NDK not found (\$ANDROID_NDK_ROOT), skipping Android build"
    echo "   Set ANDROID_NDK_ROOT to enable Android builds"
fi

# Platform-specific native builds
case "$OSTYPE" in
    msys*|cygwin*|win32)
        echo "🪟 Detected Windows"
        attempt_build "Windows" "./build-windows.ps1" "Visual Studio or Build Tools"
        ;;
    darwin*)
        echo "🍎 Detected macOS" 
        if [ ! -z "$JAVA_HOME" ]; then
            attempt_build "macOS" "./build-macos.sh" "Xcode command line tools"
        else
            echo "⚠️  JAVA_HOME not set, skipping macOS build"
            echo "   Set JAVA_HOME to enable macOS builds"
        fi
        ;;
    linux*)
        echo "🐧 Detected Linux"
        echo "   Linux libraries will be built above"
        ;;
esac

echo
echo "=== Build Summary ==="
echo "Attempted: $BUILD_ATTEMPTED platforms"  
echo "Successful: $BUILD_SUCCESS platforms"

if [ $BUILD_SUCCESS -eq 0 ]; then
    echo "❌ No platforms built successfully"
    echo "   Make sure you have the required build tools installed"
    exit 1
elif [ $BUILD_SUCCESS -lt $BUILD_ATTEMPTED ]; then
    echo "⚠️  Some platforms failed to build"
    echo "   JAR will include only successful platforms"
else
    echo "✅ All attempted platforms built successfully!"
fi

echo
echo "🔧 Assembling universal JAR from built platforms..."
if ./assemble-universal-jar.sh --allow-missing-platforms; then
    echo
    echo "🎉 Universal JAR build complete!"
    echo "📦 Check build/ directory for the final JAR"
else
    echo "❌ Failed to assemble universal JAR"
    exit 1
fi