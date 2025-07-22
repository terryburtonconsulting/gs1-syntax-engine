#!/bin/bash

# Script to help users extract macOS SDK from Xcode for OSXCross
# This must be run on a macOS system with Xcode installed

set -e

echo "=== macOS SDK Extraction Helper ==="
echo "This script helps extract macOS SDK from Xcode for cross-compilation."
echo "Run this on a macOS system with Xcode installed."
echo

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script must be run on macOS with Xcode installed."
    echo "Please run this on a Mac, then copy the resulting SDK file to your Linux build system."
    exit 1
fi

# Find Xcode installation
XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "")
if [ -z "$XCODE_PATH" ]; then
    echo "❌ Xcode not found. Please install Xcode and run 'xcode-select --install'"
    exit 1
fi

echo "✅ Found Xcode at: $XCODE_PATH"

# Find available SDKs
SDK_PATH="$XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs"
if [ ! -d "$SDK_PATH" ]; then
    echo "❌ macOS SDKs not found at $SDK_PATH"
    exit 1
fi

echo "📁 Available macOS SDKs:"
ls -la "$SDK_PATH" | grep MacOSX

# Get the latest SDK
LATEST_SDK=$(ls "$SDK_PATH" | grep "MacOSX.*\.sdk$" | sort -V | tail -1)
if [ -z "$LATEST_SDK" ]; then
    echo "❌ No macOS SDK found"
    exit 1
fi

echo "🎯 Using latest SDK: $LATEST_SDK"

# Create tarball
OUTPUT_FILE="$(pwd)/${LATEST_SDK}.tar.xz"
echo "📦 Creating SDK tarball: $OUTPUT_FILE"

cd "$SDK_PATH"
tar -czf "$OUTPUT_FILE" "$LATEST_SDK"

cd - > /dev/null

echo "✅ macOS SDK extracted successfully!"
echo "📁 Location: $OUTPUT_FILE"
echo "📊 Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo
echo "🚀 Next steps:"
echo "1. Copy this file to your Linux build system"
echo "2. Place it in the docker/ directory of your project"
echo "3. The Docker build will automatically detect and use it"
echo
echo "Example:"
echo "  scp '$OUTPUT_FILE' user@linux-system:/path/to/gs1-syntax-engine/src/java/docker/"