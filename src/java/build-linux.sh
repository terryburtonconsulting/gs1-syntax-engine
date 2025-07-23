#!/bin/bash
set -e

echo "=== Building Linux Libraries Natively ==="

# Verify we have the required compilers
echo "=== Checking Cross-Compilers ==="
which gcc && echo "✓ gcc (native x86_64)" || { echo "✗ gcc not found"; exit 1; }
which aarch64-linux-gnu-gcc && echo "✓ aarch64-linux-gnu-gcc (ARM64)" || echo "⚠️  aarch64-linux-gnu-gcc not found, skipping ARM64"
which arm-linux-gnueabihf-gcc && echo "✓ arm-linux-gnueabihf-gcc (ARM32)" || echo "⚠️  arm-linux-gnueabihf-gcc not found, skipping ARM32"

# Build configurations
declare -A PLATFORMS=(
    ["linux_x86_64"]="gcc"
    ["linux_aarch64"]="aarch64-linux-gnu-gcc"
    ["linux_arm"]="arm-linux-gnueabihf-gcc"
)

# Create build directories
mkdir -p build/native

cd ../c-lib

for platform in "${!PLATFORMS[@]}"; do
    compiler="${PLATFORMS[$platform]}"
    
    # Check if compiler is available
    if ! command -v ${compiler%% *} &> /dev/null; then
        echo "⚠️  Compiler ${compiler%% *} not available, skipping $platform"
        continue
    fi
    
    echo "=== Building C library for $platform using $compiler ==="
    
    # Build C library
    make clean > /dev/null 2>&1 || true
    if CC="$compiler" make > "build-$platform.log" 2>&1; then
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
    
    if $compiler -shared -fPIC -O2 -fvisibility=hidden \
        -I../c-lib \
        -I"$JAVA_HOME/include" \
        -I"$JAVA_HOME/include/linux" \
        -Wl,-Bsymbolic-functions -Wl,-z,relro \
        -o "$output_file" \
        gs1encoders_wrap.c \
        "../c-lib/build-$platform/libgs1encoders.a" > "build/native/$platform/build.log" 2>&1; then
        
        echo "✓ Successfully built $platform JNI library"
        
        # Strip debug symbols
        strip "$output_file" 2>/dev/null || true
        
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
echo "=== Linux Build Summary ==="
echo "Built libraries:"
find build/native -name "*.so" -path "*/linux_*/*" | while read lib; do
    echo "  $lib"
    file "$lib" 2>/dev/null || ls -la "$lib"
done

echo "=== Linux Build Complete ==="