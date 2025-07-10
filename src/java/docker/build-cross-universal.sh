#!/bin/bash

# Enhanced cross-compilation build script with Android support
set -e

echo "=== GS1 Syntax Engine Cross-Compilation Build (with Android) ==="
echo "JAVA_HOME: $JAVA_HOME"
echo "ANDROID_NDK_ROOT: $ANDROID_NDK_ROOT"
echo "Working directory: $(pwd)"

# Check available compilers
echo "=== Available Cross-Compilers ==="
which gcc && echo "✓ gcc (native x86_64)"
which aarch64-linux-gnu-gcc && echo "✓ aarch64-linux-gnu-gcc (ARM64 Linux)" || echo "✗ aarch64-linux-gnu-gcc not found"
which arm-linux-gnueabihf-gcc && echo "✓ arm-linux-gnueabihf-gcc (ARM Linux)" || echo "✗ arm-linux-gnueabihf-gcc not found"
which x86_64-w64-mingw32-gcc && echo "✓ x86_64-w64-mingw32-gcc (Windows x64)" || echo "✗ x86_64-w64-mingw32-gcc not found"
which i686-w64-mingw32-gcc && echo "✓ i686-w64-mingw32-gcc (Windows x86)" || echo "✗ i686-w64-mingw32-gcc not found"

# Check Android NDK compilers
if [ -n "$ANDROID_NDK_ROOT" ]; then
    echo "=== Android NDK Compilers ==="
    [ -f "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang" ] && echo "✓ Android ARM64 (arm64-v8a)" || echo "✗ Android ARM64 not found"
    [ -f "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang" ] && echo "✓ Android ARM32 (armeabi-v7a)" || echo "✗ Android ARM32 not found"
    [ -f "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android21-clang" ] && echo "✓ Android x86_64" || echo "✗ Android x86_64 not found"
    [ -f "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/i686-linux-android21-clang" ] && echo "✓ Android x86" || echo "✗ Android x86 not found"
fi
echo

# Build configurations
declare -A PLATFORMS=(
    # Desktop/Server platforms
    ["linux_x86_64"]="gcc"
    ["linux_aarch64"]="aarch64-linux-gnu-gcc"
    ["linux_arm"]="arm-linux-gnueabihf-gcc"
    ["windows_x86_64"]="x86_64-w64-mingw32-gcc"
    ["windows_x86"]="i686-w64-mingw32-gcc"
    
    # Android platforms (using NDK)
    ["android_arm64"]="aarch64-linux-android21-clang"
    ["android_arm"]="armv7a-linux-androideabi21-clang"
    ["android_x86_64"]="x86_64-linux-android21-clang"
    ["android_x86"]="i686-linux-android21-clang"
)

# Create build directories
mkdir -p build/native

# First, build the C library for each platform
for platform in "${!PLATFORMS[@]}"; do
    compiler="${PLATFORMS[$platform]}"
    echo "=== Building C library for $platform using $compiler ==="
    
    # Check if compiler is available
    if ! command -v ${compiler%% *} &> /dev/null; then
        echo "⚠️  Compiler ${compiler%% *} not available, skipping $platform"
        continue
    fi
    
    # Create platform-specific C library build
    mkdir -p "build-$platform"
    cd_dir="."
    
    # Check if we're in the c-lib directory or java directory
    if [ -f "gs1encoders.h" ]; then
        # We're in c-lib directory
        cd_dir="."
    elif [ -f "../c-lib/gs1encoders.h" ]; then
        # We're in java directory
        cd_dir="../c-lib"
    else
        echo "Error: Cannot find c-lib directory"
        exit 1
    fi
    
    cd "$cd_dir"
    
    # Clean and build C library for this platform
    echo "Building C library with $compiler..."
    make clean > /dev/null 2>&1 || true
    
    # Build with cross-compiler - special handling for different platforms
    if [[ $platform == windows_* ]]; then
        # For Windows, disable FORTIFY_SOURCE to avoid MinGW compatibility issues
        echo "Building C library for Windows with disabled FORTIFY_SOURCE..."
        echo "Debug: Using compiler $compiler and DISABLE_FORTIFY_SOURCE=1"
        make clean > /dev/null 2>&1 || true
        echo "Running: make CC=$compiler DISABLE_FORTIFY_SOURCE=1"
        if make CC="$compiler" DISABLE_FORTIFY_SOURCE=1 > "build-$platform.log" 2>&1; then
            build_success=true
        else
            build_success=false
        fi
    elif [[ $platform == android_* ]]; then
        # For Android, use NDK toolchain
        echo "Building C library for Android with NDK..."
        echo "Debug: Using NDK compiler $compiler"
        make clean > /dev/null 2>&1 || true
        echo "Running: make CC=$compiler"
        if CC="$compiler" make > "build-$platform.log" 2>&1; then
            build_success=true
        else
            build_success=false
        fi
    else
        # For Linux, use default flags
        if CC="$compiler" make > "build-$platform.log" 2>&1; then
            build_success=true
        else
            build_success=false
        fi
    fi
    
    if $build_success; then
        # Copy the static library to platform-specific directory
        mkdir -p "build-$platform"
        cp build/libgs1encoders.a "build-$platform/"
        echo "✓ C library built successfully for $platform"
    else
        echo "✗ Failed to build C library for $platform (see build-$platform.log)"
        continue
    fi
    
    # Return to the original directory
    cd /workspace/java
    
    # Now build JNI library for this platform
    echo "Building JNI library for $platform..."
    mkdir -p "build/native/$platform"
    
    # Set platform-specific variables
    case $platform in
        linux_*)
            lib_extension="so"
            lib_prefix="lib"
            java_include_os="linux"
            compiler_flags="-shared -fPIC -O2 -fvisibility=hidden"
            link_flags="../c-lib/build-$platform/libgs1encoders.a"
            ;;
        windows_*)
            lib_extension="dll"
            lib_prefix=""
            java_include_os="win32"
            compiler_flags="-shared -Wl,--add-stdcall-alias -O2"
            link_flags="../c-lib/build-$platform/libgs1encoders.a"
            ;;
        android_*)
            lib_extension="so"
            lib_prefix="lib"
            java_include_os="android"
            compiler_flags="-shared -fPIC -O2 -fvisibility=hidden"
            link_flags="../c-lib/build-$platform/libgs1encoders.a"
            ;;
    esac
    
    output_file="build/native/$platform/${lib_prefix}gs1encodersjni.${lib_extension}"
    
    echo "  Building: $output_file"
    if $compiler $compiler_flags \
        -I../c-lib \
        -I"$JAVA_HOME/include" \
        -I"$JAVA_HOME/include/$java_include_os" \
        -o "$output_file" \
        gs1encoders_wrap.c \
        $link_flags > "build/native/$platform/build.log" 2>&1; then
        
        echo "  ✓ Successfully built $platform JNI library"
        
        # Strip debug symbols for release builds
        if [[ $platform == linux_* ]] || [[ $platform == android_* ]]; then
            strip "$output_file" 2>/dev/null || true
        fi
        
        # Show library info
        file "$output_file" || ls -la "$output_file"
    else
        echo "  ✗ Failed to build $platform JNI library (see build/native/$platform/build.log)"
        continue
    fi
done

echo
echo "=== Cross-Compilation Build Summary ==="
echo "Built libraries:"
find build/native -name "*.so" -o -name "*.dll" | while read lib; do
    echo "  $lib"
    file "$lib" 2>/dev/null || ls -la "$lib"
done

echo
echo "=== Creating Universal Multi-Architecture JAR ==="

# Compile Java classes
mkdir -p build/classes
javac -d build/classes org/gs1/gs1encoders/*.java

# Create JAR structure
mkdir -p build/multiarch-jar
cp -r build/classes/* build/multiarch-jar/

# Add native libraries to JAR with Android-compatible naming
for platform_dir in build/native/*/; do
    if [ -d "$platform_dir" ]; then
        platform=$(basename "$platform_dir")
        echo "Adding $platform libraries to JAR..."
        
        # Map platform names to Android-compatible names
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
            *)
                jar_platform="$platform"
                ;;
        esac
        
        mkdir -p "build/multiarch-jar/META-INF/lib/$jar_platform"
        
        # Copy all libraries from this platform
        find "$platform_dir" -name '*.so' -o -name '*.dll' -o -name '*.dylib' | while read lib; do
            if [ -f "$lib" ]; then
                cp "$lib" "build/multiarch-jar/META-INF/lib/$jar_platform/"
                echo "  Added: META-INF/lib/$jar_platform/$(basename "$lib")"
            fi
        done
    fi
done

# Create the universal multi-architecture JAR
cd build/multiarch-jar
jar cf ../gs1-syntax-engine-multiarch-1.1.0.jar .
cd ../..

echo
echo "✅ Universal multi-architecture JAR completed!"
jar_file="build/gs1-syntax-engine-multiarch-1.1.0.jar"
echo "📦 Universal multi-architecture JAR: $jar_file"
echo "📊 JAR size: $(ls -lh "$jar_file" | awk '{print $5}')"

echo
echo "JAR contents (all platforms):"
jar tf "$jar_file" | grep -E "META-INF/lib/.*\.(so|dll|dylib)$" | sort