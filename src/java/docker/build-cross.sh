#!/bin/bash

# Simple cross-compilation build script for GS1 Syntax Engine
set -e

echo "=== GS1 Syntax Engine Cross-Compilation Build ==="
echo "JAVA_HOME: $JAVA_HOME"
echo "Working directory: $(pwd)"

# Check available compilers
echo "=== Available Cross-Compilers ==="
which gcc && echo "✓ gcc (native x86_64)"
which aarch64-linux-gnu-gcc && echo "✓ aarch64-linux-gnu-gcc (ARM64 Linux)" || echo "✗ aarch64-linux-gnu-gcc not found"
which arm-linux-gnueabihf-gcc && echo "✓ arm-linux-gnueabihf-gcc (ARM Linux)" || echo "✗ arm-linux-gnueabihf-gcc not found"
which x86_64-w64-mingw32-gcc && echo "✓ x86_64-w64-mingw32-gcc (Windows x64)" || echo "✗ x86_64-w64-mingw32-gcc not found"
which i686-w64-mingw32-gcc && echo "✓ i686-w64-mingw32-gcc (Windows x86)" || echo "✗ i686-w64-mingw32-gcc not found"
echo

# Build configurations
declare -A PLATFORMS=(
    ["linux_x86_64"]="gcc"
    ["linux_aarch64"]="aarch64-linux-gnu-gcc"
    ["linux_arm"]="arm-linux-gnueabihf-gcc"
    ["windows_x86_64"]="x86_64-w64-mingw32-gcc"
    ["windows_x86"]="i686-w64-mingw32-gcc"
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
    
    # Build with cross-compiler - disable fortify source for Windows
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
        cp build/libgs1encoders.a "build-$platform/"
        echo "✓ C library built successfully for $platform"
    else
        echo "✗ Failed to build C library for $platform (see build-$platform.log)"
        continue
    fi
    
    # Return to the original directory
    cd /workspace
    
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
            link_flags="build-$platform/libgs1encoders.a"
            ;;
        windows_*)
            lib_extension="dll"
            lib_prefix=""
            java_include_os="win32"
            compiler_flags="-shared -Wl,--add-stdcall-alias -O2"
            link_flags="build-$platform/libgs1encoders.a"
            ;;
    esac
    
    output_file="build/native/$platform/${lib_prefix}gs1encodersjni.${lib_extension}"
    
    echo "  Building: $output_file"
    if $compiler $compiler_flags \
        -I. \
        -I"$JAVA_HOME/include" \
        -I"$JAVA_HOME/include/$java_include_os" \
        -o "$output_file" \
        java/gs1encoders_wrap.c \
        $link_flags > "build/native/$platform/build.log" 2>&1; then
        
        echo "  ✓ Successfully built $platform JNI library"
        
        # Strip debug symbols for Linux builds
        if [[ $platform == linux_* ]]; then
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
echo "=== Creating Multi-Architecture JAR ==="

# Compile Java classes
mkdir -p build/classes
javac -d build/classes org/gs1/gs1encoders/*.java
javac -cp build/classes -d build/classes Example.java

# Create JAR structure
mkdir -p build/cross-jar
cp -r build/classes/* build/cross-jar/

# Add native libraries to JAR
for platform_dir in build/native/*/; do
    if [ -d "$platform_dir" ]; then
        platform=$(basename "$platform_dir")
        echo "Adding $platform libraries to JAR..."
        mkdir -p "build/cross-jar/META-INF/lib/$platform"
        
        # Copy all libraries from this platform
        for lib in "$platform_dir"*.{so,dll,dylib} 2>/dev/null; do
            if [ -f "$lib" ]; then
                cp "$lib" "build/cross-jar/META-INF/lib/$platform/"
                echo "  Added: META-INF/lib/$platform/$(basename "$lib")"
            fi
        done
    fi
done

# Create the multi-architecture JAR
cd build/cross-jar
jar cf ../gs1-syntax-engine-cross-$(date +%Y%m%d).jar .
cd ../..

echo
echo "✅ Cross-compilation build completed!"
jar_file=$(ls build/gs1-syntax-engine-cross-*.jar | head -1)
echo "📦 Multi-architecture JAR: $jar_file"
echo "📊 JAR size: $(ls -lh "$jar_file" | awk '{print $5}')"

echo
echo "JAR contents:"
jar tf "$jar_file" | grep -E "META-INF/lib/.*\.(so|dll|dylib)$" | sort