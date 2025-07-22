#!/bin/bash
set -e

echo "=== Building macOS Libraries with Native Toolchain ==="

# Verify we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script must be run on macOS"
    exit 1
fi

# Verify Xcode command line tools are installed
if ! command -v clang &> /dev/null; then
    echo "❌ Xcode command line tools not found"
    echo "   Please install with: xcode-select --install"
    exit 1
fi

echo "✅ Using clang: $(clang --version | head -1)"

# Verify JAVA_HOME is set
if [ -z "$JAVA_HOME" ]; then
    echo "❌ JAVA_HOME environment variable not set"
    echo "   Please set JAVA_HOME to your JDK 8 installation"
    echo "   Example: export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home"
    exit 1
fi

if [ ! -d "$JAVA_HOME" ]; then
    echo "❌ JAVA_HOME path does not exist: $JAVA_HOME"
    exit 1
fi

echo "✅ Using JAVA_HOME: $JAVA_HOME"

# Set deployment target for backward compatibility
# Use the oldest available SDK for broader compatibility
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX12.3.sdk" ]; then
    export MACOSX_DEPLOYMENT_TARGET=12.3
elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX14.5.sdk" ]; then
    export MACOSX_DEPLOYMENT_TARGET=14.0  # Conservative version for 14.5 SDK
else
    export MACOSX_DEPLOYMENT_TARGET=15.0  # Use current if no older versions
fi

echo "✅ Setting deployment target: macOS $MACOSX_DEPLOYMENT_TARGET"

# Get the current SDK path
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
echo "✅ Using SDK: $SDK_PATH"

# Build configurations (bash 4+ required for associative arrays)
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
    declare -A PLATFORMS=(
        ["darwin_x86_64"]="x86_64-apple-macos$MACOSX_DEPLOYMENT_TARGET"
        ["darwin_aarch64"]="arm64-apple-macos$MACOSX_DEPLOYMENT_TARGET"
    )
else
    # Fallback for older bash versions
    PLATFORMS_NAMES=("darwin_x86_64" "darwin_aarch64")
    PLATFORMS_TARGETS=("x86_64-apple-macos$MACOSX_DEPLOYMENT_TARGET" "arm64-apple-macos$MACOSX_DEPLOYMENT_TARGET")
fi

# Function to build a single platform  
build_platform() {
    local platform="$1"
    local target="$2"
    
    echo "=== Building C library for $platform (target: $target) ==="
    
    # Build C library with explicit macOS linker flags override
    make clean > /dev/null 2>&1 || true
    if CC="clang -target $target -isysroot $SDK_PATH" \
       LDFLAGS="" \
       LDFLAGS_SO="-shared -Wl,-install_name,libgs1encoders.dylib.1" \
       LIB_DYN_SUFFIX="dylib" \
       make libstatic > "build-$platform.log" 2>&1; then
        mkdir -p ../java/build/native/$platform
        cp build/libgs1encoders.a ../java/build/native/$platform/
        echo "✓ C library built for $platform"
    else
        echo "✗ Failed to build C library for $platform (see ../c-lib/build-$platform.log)"
        return 1
    fi
    
    # Build JNI library
    cd ../java
    echo "Building JNI library for $platform..."
    
    mkdir -p build/native/$platform
    output_file="build/native/$platform/libgs1encodersjni.dylib"
    
    if clang -shared -fPIC -O2 -fvisibility=hidden \
        -target "$target" -isysroot "$SDK_PATH" \
        -I../c-lib \
        -I"$JAVA_HOME/include" \
        -I"$JAVA_HOME/include/darwin" \
        -o "$output_file" \
        gs1encoders_wrap.c \
        "build/native/$platform/libgs1encoders.a" > "build/native/$platform/build.log" 2>&1; then
        
        echo "✓ Successfully built $platform JNI library"
        
        # Strip debug symbols if available
        strip "$output_file" 2>/dev/null || true
        
        # Show library info and verify deployment target
        file "$output_file"
        echo "  Checking deployment target:"
        otool -l "$output_file" | grep -A 3 LC_VERSION_MIN_MACOSX || \
        otool -l "$output_file" | grep -A 3 LC_BUILD_VERSION | head -4
        
    else
        echo "✗ Failed to build $platform JNI library (see build/native/$platform/build.log)"
        return 1
    fi
    
    cd ../c-lib
    return 0
}

# Create build directories
mkdir -p build/native

cd ../c-lib

# Handle both associative array and fallback approaches
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
    # Modern bash with associative arrays
    for platform in "${!PLATFORMS[@]}"; do
        target="${PLATFORMS[$platform]}"
        build_platform "$platform" "$target"
    done
else
    # Fallback for older bash
    for i in "${!PLATFORMS_NAMES[@]}"; do
        platform="${PLATFORMS_NAMES[$i]}"
        target="${PLATFORMS_TARGETS[$i]}"
        build_platform "$platform" "$target"
    done
fi

cd ../java

echo
echo "=== macOS Build Summary ==="
echo "Built libraries:"
find build/native -name "*.dylib" -path "*/darwin_*/*" | while read lib; do
    echo "  $lib"
    file "$lib" 2>/dev/null || ls -la "$lib"
done

# Verify deployment targets
echo
echo "=== Deployment Target Verification ==="
find build/native -name "*.dylib" -path "*/darwin_*/*" | while read lib; do
    echo "Library: $(basename "$lib")"
    otool -l "$lib" | grep -A 3 LC_VERSION_MIN_MACOSX || \
    otool -l "$lib" | grep -A 3 LC_BUILD_VERSION | head -4
    echo
done

echo "=== macOS Build Complete ==="