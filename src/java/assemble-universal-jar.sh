#!/bin/bash
set -e

echo "=== Assembling Universal JAR from Platform Artifacts ==="

# Parse command line arguments
ALLOW_MISSING=false
for arg in "$@"; do
    case $arg in
        --allow-missing-platforms)
            ALLOW_MISSING=true
            shift
            ;;
        *)
            # Unknown option
            ;;
    esac
done

# Create JAR structure
mkdir -p build/multiarch-jar/META-INF/lib
PLATFORMS_INCLUDED=""

# Function to copy platform artifacts if they exist
copy_platform_artifacts() {
    local platform_pattern="$1"
    local platform_name="$2"
    
    if find build/native -path "*/$platform_pattern/*" -name "*.so" -o -name "*.dll" -o -name "*.dylib" 2>/dev/null | grep -q .; then
        echo "✅ Including $platform_name libraries"
        
        # Copy platform libraries to JAR structure
        for platform_dir in build/native/$platform_pattern*/; do
            if [ -d "$platform_dir" ]; then
                platform=$(basename "$platform_dir")
                echo "  Adding $platform libraries to JAR..."
                
                # Map platform names to Android-compatible names in JAR
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
                
                # Copy all native libraries from this platform
                find "$platform_dir" -name '*.so' -o -name '*.dll' -o -name '*.dylib' | while read lib; do
                    if [ -f "$lib" ]; then
                        cp "$lib" "build/multiarch-jar/META-INF/lib/$jar_platform/"
                        echo "    Added: META-INF/lib/$jar_platform/$(basename "$lib")"
                    fi
                done
            fi
        done
        
        PLATFORMS_INCLUDED="$PLATFORMS_INCLUDED $platform_name"
        return 0
    else
        if [ "$ALLOW_MISSING" = true ]; then
            echo "⚠️  $platform_name libraries not found, skipping"
            return 1
        else
            echo "❌ $platform_name libraries not found (use --allow-missing-platforms to continue)"
            return 1
        fi
    fi
}

# Check for artifacts from CI download (GitHub Actions downloads to artifacts/)
if [ -d "../../artifacts" ]; then
    echo "Found CI artifacts directory, copying to build/native..."
    mkdir -p build/native
    cp -r ../../artifacts/* build/native/ 2>/dev/null || true
fi

# Copy platform artifacts
echo "=== Checking for Platform Artifacts ==="

copy_platform_artifacts "linux_*" "Linux" || true
copy_platform_artifacts "windows_*" "Windows" || true  
copy_platform_artifacts "android_*" "Android" || true
copy_platform_artifacts "darwin_*" "macOS" || true

# Check if we have any libraries at all
if [ -z "$PLATFORMS_INCLUDED" ]; then
    echo "❌ No platform libraries found to include in JAR"
    echo "   Make sure to run platform build scripts first:"
    echo "   - ./build-linux-native.sh"
    echo "   - ./build-android-native.sh (requires Android NDK)"
    echo "   - ./build-windows.ps1 (on Windows)"
    echo "   - ./build-macos.sh (on macOS)"
    exit 1
fi

echo "📦 Platforms to include in JAR:$PLATFORMS_INCLUDED"

# Compile Java classes if not already compiled
if [ ! -d "build/classes" ] || [ ! -f "build/classes/org/gs1/gs1encoders/GS1Encoders.class" ]; then
    echo "=== Compiling Java Classes ==="
    mkdir -p build/classes
    if javac -d build/classes org/gs1/gs1encoders/*.java; then
        echo "✓ Java classes compiled successfully"
    else
        echo "❌ Failed to compile Java classes"
        exit 1
    fi
else
    echo "✅ Using existing compiled Java classes"
fi

# Copy Java classes to JAR structure
echo "=== Adding Java Classes to JAR ==="
cp -r build/classes/* build/multiarch-jar/

# Get version from build.gradle or use default
VERSION="1.1.0"
if [ -f "build.gradle" ] && command -v grep &> /dev/null; then
    GRADLE_VERSION=$(grep "version = " build.gradle | sed "s/version = '\(.*\)'/\1/" | tr -d "'\"")
    if [ ! -z "$GRADLE_VERSION" ]; then
        VERSION="$GRADLE_VERSION"
    fi
fi

# Create the universal multi-architecture JAR
echo "=== Creating Universal JAR ==="
JAR_NAME="gs1-syntax-engine-multiarch-$VERSION.jar"

cd build/multiarch-jar
if jar cf "../$JAR_NAME" .; then
    echo "✅ Universal JAR created successfully!"
else
    echo "❌ Failed to create JAR"
    exit 1
fi
cd ../..

# Show results
echo
echo "📦 Universal JAR: build/$JAR_NAME"
if [ -f "build/$JAR_NAME" ]; then
    JAR_SIZE=$(ls -lh "build/$JAR_NAME" | awk '{print $5}')
    echo "📊 JAR size: $JAR_SIZE"
    
    echo
    echo "📋 JAR contents (native libraries):"
    jar tf "build/$JAR_NAME" | grep -E "META-INF/lib/.*\.(so|dll|dylib)$" | sort
    
    # Count libraries per platform
    echo
    echo "📈 Library count by platform:"
    jar tf "build/$JAR_NAME" | grep -E "META-INF/lib/.*\.(so|dll|dylib)$" | \
    sed 's|META-INF/lib/\([^/]*\)/.*|\1|' | sort | uniq -c | \
    while read count platform; do
        echo "  $platform: $count libraries"
    done
    
    echo
    echo "✅ Universal multi-architecture JAR assembly complete!"
    echo "🎯 Platforms included:$PLATFORMS_INCLUDED"
else
    echo "❌ JAR file was not created"
    exit 1
fi