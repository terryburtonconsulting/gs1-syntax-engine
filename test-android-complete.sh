#!/bin/bash
set -e

echo '=== Testing Complete Android Build ==='

docker run --rm -v "$(pwd):/workspace" -w /workspace ubuntu:22.04 bash -c '
set -e

# Quick setup
apt-get update -q
apt-get install -y -q wget unzip openjdk-8-jdk make file

# Download NDK if needed
cd /tmp  
if [ ! -d android-ndk-r25c ]; then
    echo "=== Downloading NDK ==="
    wget -q https://dl.google.com/android/repository/android-ndk-r25c-linux.zip
    unzip -q android-ndk-r25c-linux.zip
fi

# Test the full Android build script
cd /workspace/src/java
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export ANDROID_NDK_ROOT=/tmp/android-ndk-r25c

echo "=== Running full Android build script ==="
timeout 300 ./build-android.sh

echo "=== Checking results ==="
echo "Built libraries:"
find build/native -name "*.so" | grep android

echo "=== Verifying library files ==="
for lib in $(find build/native -name "*.so" | grep android | head -3); do
    echo "=== $lib ==="
    file "$lib"
done

echo "=== Android build test completed successfully ==="
'