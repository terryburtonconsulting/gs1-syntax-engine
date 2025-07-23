#!/bin/bash
set -e

echo "=== Building Android Libraries Natively (with cached NDK) ==="

# Verify NDK is available
if [ -z "$ANDROID_NDK_ROOT" ]; then
    echo "❌ ANDROID_NDK_ROOT environment variable not set"
    echo "   Set it to the path of your Android NDK installation"
    echo "   Example: export ANDROID_NDK_ROOT=/path/to/android-ndk-r25c"
    exit 1
fi

if [ ! -d "$ANDROID_NDK_ROOT" ]; then
    echo "❌ Android NDK not found at: $ANDROID_NDK_ROOT"
    echo "   Make sure the NDK is downloaded and extracted"
    exit 1
fi

echo "✅ Using Android NDK at: $ANDROID_NDK_ROOT"

# Verify NDK compilers are available
echo "=== Checking Android NDK Compilers ==="
NDK_BIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"

if [ ! -d "$NDK_BIN" ]; then
    echo "❌ NDK toolchain not found at: $NDK_BIN"
    exit 1
fi

# Check NDK compilers
[ -f "$NDK_BIN/aarch64-linux-android21-clang" ] && echo "✓ Android ARM64 (arm64-v8a)" || echo "✗ Android ARM64 not found"
[ -f "$NDK_BIN/armv7a-linux-androideabi21-clang" ] && echo "✓ Android ARM32 (armeabi-v7a)" || echo "✗ Android ARM32 not found"  
[ -f "$NDK_BIN/x86_64-linux-android21-clang" ] && echo "✓ Android x86_64" || echo "✗ Android x86_64 not found"
[ -f "$NDK_BIN/i686-linux-android21-clang" ] && echo "✓ Android x86" || echo "✗ Android x86 not found"

# Build configurations
declare -A PLATFORMS=(
    ["android_arm64"]="aarch64-linux-android21-clang"
    ["android_arm"]="armv7a-linux-androideabi21-clang"
    ["android_x86_64"]="x86_64-linux-android21-clang"
    ["android_x86"]="i686-linux-android21-clang"
)

# Create build directories
mkdir -p build/native

cd ../c-lib

for platform in "${!PLATFORMS[@]}"; do
    compiler="${PLATFORMS[$platform]}"
    
    # Check if compiler is available
    if [ ! -f "$NDK_BIN/$compiler" ]; then
        echo "⚠️  Compiler $compiler not available, skipping $platform"
        continue
    fi
    
    echo "=== Building C library for $platform using $compiler ==="
    
    # Build C library
    make clean > /dev/null 2>&1 || true
    if CC="$NDK_BIN/$compiler" AR="$NDK_BIN/llvm-ar" RANLIB="$NDK_BIN/llvm-ranlib" make > "build-$platform.log" 2>&1; then
        mkdir -p ../java/build/native/$platform
        cp build/libgs1encoders.a ../java/build/native/$platform/
        echo "✓ C library built for $platform"
    else
        echo "✗ Failed to build C library for $platform (see ../c-lib/build-$platform.log)"
        continue
    fi
    
    # Build JNI library
    cd ../java
    echo "Building JNI library for $platform..."
    
    mkdir -p build/native/$platform
    output_file="build/native/$platform/libgs1encodersjni.so"
    
    # Map platform to Android ABI for JAR structure
    case $platform in
        android_arm64)
            jar_platform="android_arm64-v8a"
            ;;
        android_arm)
            jar_platform="android_armeabi-v7a"
            ;;
        android_x86_64)
            jar_platform="android_x86_64"
            ;;
        android_x86)
            jar_platform="android_x86"
            ;;
    esac
    
    if "$NDK_BIN/$compiler" -shared -fPIC -O2 -fvisibility=hidden \
        -I../c-lib \
        -I"$JAVA_HOME/include" \
        -I"$JAVA_HOME/include/linux" \
        -o "$output_file" \
        gs1encoders_wrap.c \
        "build/native/$platform/libgs1encoders.a" > "build/native/$platform/build.log" 2>&1; then
        
        echo "✓ Successfully built $platform JNI library"
        
        # Android libraries are typically pre-stripped, but strip if available
        if command -v llvm-strip &> /dev/null; then
            llvm-strip "$output_file" 2>/dev/null || true
        fi
        
        # Show library info
        file "$output_file"
    else
        echo "✗ Failed to build $platform JNI library (see build/native/$platform/build.log)"
        continue
    fi
    
    cd ../c-lib
done

cd ../java

echo
echo "=== Android Build Summary ==="
echo "Built libraries:"
find build/native -name "*.so" -path "*/android_*/*" | while read lib; do
    echo "  $lib"
    file "$lib" 2>/dev/null || ls -la "$lib"
done

echo "=== Android Build Complete ==="