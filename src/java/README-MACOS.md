# macOS Support for Universal Multi-Architecture JAR

The universal JAR can include native libraries for macOS (both Intel and Apple Silicon) using OSXCross for cross-compilation from Linux.

## Prerequisites

1. **Legal macOS SDK**: You must legally obtain a macOS SDK from Xcode on a Mac system
2. **Docker**: Required for the cross-compilation environment

## Quick Start

### Step 1: Extract macOS SDK (on macOS)

On a Mac with Xcode installed, run the SDK extraction helper:

```bash
cd src/java/docker
./setup-macos-sdk.sh
```

This will create a file like `MacOSX14.2.sdk.tar.xz` (~2-3 GB).

### Step 2: Copy SDK to Build System

Copy the SDK file to your Linux build system:

```bash
# Copy to the docker directory
cp MacOSX*.sdk.tar.xz /path/to/gs1-syntax-engine/src/java/docker/
```

### Step 3: Build Universal JAR with macOS Support

```bash
cd src/java
./build-multiarch.sh
```

The build script will automatically detect the macOS SDK and include macOS libraries in the JAR.

## Supported macOS Architectures

- **darwin_x86_64**: Intel Macs (2006-2023)
- **darwin_aarch64**: Apple Silicon M1/M2/M3 (2020+)

## How It Works

1. **OSXCross Installation**: Docker image includes OSXCross cross-compilation toolchain
2. **SDK Detection**: Build automatically detects and uses provided macOS SDK
3. **Cross-Compilation**: Compiles native libraries for both Intel and Apple Silicon
4. **JAR Integration**: Includes `.dylib` files in universal JAR alongside other platforms

## Total Platform Support

With macOS support enabled, the universal JAR supports **11 platforms**:

### Desktop/Server (7 platforms)
- Linux: x86_64, ARM64, ARM32
- Windows: x86_64, x86
- **macOS: x86_64, ARM64** ← New!

### Mobile (4 platforms)
- Android: arm64-v8a, armeabi-v7a, x86_64, x86

## Legal Considerations

⚠️ **Important**: The macOS SDK is subject to Apple's licensing terms:

- You must legally obtain the SDK from your own Xcode installation
- The SDK cannot be redistributed
- Each developer must extract their own SDK

## Without macOS SDK

If no macOS SDK is provided:
- Build continues normally
- JAR includes 9 platforms (Linux, Windows, Android)
- macOS platforms are gracefully skipped
- No impact on other platform support

## File Sizes

- **Docker image**: ~6-8 GB (with OSXCross + SDK)
- **Universal JAR**: ~1.4-1.6 MB (with macOS libraries)
- **macOS SDK**: ~2-3 GB (not included in final JAR)

## Troubleshooting

### "No macOS SDK provided"
```
Warning: No macOS SDK provided. macOS compilation will be skipped.
To enable macOS support, provide MacOSX*.sdk.tar.xz in build context.
```
**Solution**: Extract SDK using `setup-macos-sdk.sh` on macOS and copy to `docker/` directory.

### "OSXCross compilers not found"
```
✗ macOS x86_64 not found
✗ macOS ARM64 not found
```
**Solution**: Ensure macOS SDK was properly provided during Docker build.

### Docker build fails with OSXCross
**Solution**: Make sure you have sufficient disk space (~10 GB) for the larger Docker image.

## Manual SDK Extraction

If the helper script doesn't work, manually extract the SDK:

```bash
# On macOS with Xcode installed
cd /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
tar -czf ~/MacOSX.sdk.tar.xz MacOSX.sdk
```

Then copy the tarball to your Linux build system's `docker/` directory.