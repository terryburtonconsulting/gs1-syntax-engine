# Multi-Platform Build System

The universal JAR is now built using a **split platform approach** where each platform is built natively using its optimal toolchain, then combined into a single universal JAR.

## Overview

### **Split Platform Architecture**
- **Linux**: Built on Ubuntu with cross-compilation toolchains
- **Android**: Built on Ubuntu with cached Android NDK  
- **Windows**: Built on Windows with MSVC
- **macOS**: Built on macOS with Xcode toolchain

### **Benefits**
- ✅ **Faster builds** - No Docker overhead for most platforms
- ✅ **More reliable** - Each platform uses its optimal toolchain
- ✅ **Better debugging** - Direct access to build processes
- ✅ **Parallel execution** - All platforms build simultaneously in CI
- ✅ **Graceful degradation** - JAR can be built with subset of platforms

## Quick Start

### **Local Development**

```bash
# Build for your current platform
cd src/java

# Linux developers
./build-linux.sh

# Android (requires Android NDK)
export ANDROID_NDK_ROOT=/path/to/android-ndk-r25c
./build-android.sh

# Windows developers (PowerShell)
.\build-windows.ps1

# macOS developers
./build-macos.sh

# Assemble universal JAR from built platforms
./assemble-universal-jar.sh --allow-missing-platforms
```

### **Build All Platforms (if available)**

```bash
# Build everything you can locally
./build-all-platforms.sh
```

## Platform-Specific Setup

### **Linux**
```bash
# Install cross-compilation toolchains
sudo apt-get update
sudo apt-get install -y gcc gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf openjdk-8-jdk make

# Build
cd src/java
./build-linux.sh
```

**Builds:**
- `linux_x86_64` - Intel/AMD 64-bit
- `linux_aarch64` - ARM 64-bit (Raspberry Pi 4, Apple Silicon under emulation)
- `linux_arm` - ARM 32-bit (older Raspberry Pi)

### **Android**
```bash
# Download and extract Android NDK
wget https://dl.google.com/android/repository/android-ndk-r25c-linux.zip
unzip android-ndk-r25c-linux.zip

# Set environment and build
export ANDROID_NDK_ROOT=$PWD/android-ndk-r25c
cd src/java
./build-android.sh
```

**Builds:**
- `android_arm64-v8a` - ARM 64-bit (modern Android devices)
- `android_armeabi-v7a` - ARM 32-bit (older Android devices)  
- `android_x86_64` - Intel 64-bit (emulators, Chromebooks)
- `android_x86` - Intel 32-bit (older emulators)

### **Windows**
```powershell
# Requires Visual Studio or Build Tools
# Run from Developer Command Prompt or PowerShell

cd src\java
.\build-windows.ps1
```

**Builds:**
- `windows_x86_64` - 64-bit Windows
- `windows_x86` - 32-bit Windows

### **macOS**
```bash
# Requires Xcode command line tools
xcode-select --install

# Set JAVA_HOME (adjust path as needed)
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home

cd src/java
./build-macos.sh
```

**Builds:**
- `darwin_x86_64` - Intel Macs (2006-2023)
- `darwin_aarch64` - Apple Silicon M1/M2/M3 (2020+)

**Deployment Target:** macOS 11.0+ (configurable in script)

## CI/CD Pipeline

### **GitHub Actions Workflow**
The `.github/workflows/universal-jar.yml` workflow:

1. **Parallel Platform Builds**
   - `build-linux` - Ubuntu runner with cross-compilers
   - `build-android` - Ubuntu runner with cached NDK (~1GB cache)
   - `build-windows` - Windows runner with MSVC
   - `build-macos` - macOS runner with native tools

2. **Artifact Collection**
   - Each platform uploads its built libraries
   - `assemble-universal-jar` job downloads all artifacts

3. **Universal JAR Assembly**
   - Combines all platform libraries
   - Creates single JAR with all platforms
   - Gracefully handles missing platforms (e.g., if macOS build fails)

### **Performance**
| Platform | Build Time | Cache Benefit |
|----------|------------|---------------|
| Linux    | ~1 min     | N/A (native) |
| Android  | ~2 min     | 1GB NDK cached |
| Windows  | ~2 min     | N/A (native) |
| macOS    | ~3 min     | N/A (native) |
| **Total** | **~3 min** | **Parallel execution** |

## JAR Assembly

### **Automatic Assembly**
```bash
# Assembles JAR from all available platform builds
./assemble-universal-jar.sh
```

### **Flexible Assembly**
```bash  
# Allow missing platforms (useful for development)
./assemble-universal-jar.sh --allow-missing-platforms

# This creates a JAR with only the platforms you've built locally
```

### **JAR Structure**
```
gs1-syntax-engine-multiarch-1.1.0.jar
├── org/gs1/gs1encoders/          # Java classes
├── META-INF/
│   └── lib/
│       ├── linux_x86_64/
│       │   └── libgs1encodersjni.so
│       ├── linux_aarch64/
│       │   └── libgs1encodersjni.so
│       ├── android_arm64-v8a/
│       │   └── libgs1encodersjni.so
│       ├── windows_x86_64/
│       │   └── gs1encodersjni.dll
│       └── darwin_x86_64/
│           └── libgs1encodersjni.dylib
```

## Development Workflows

### **Full Development**
```bash
# Build all platforms you have available
./build-all-platforms.sh

# Creates JAR with all platforms you can build locally
```

### **Single Platform Development**
```bash  
# Just build for your development platform
./build-linux.sh  # or build-macos.sh, etc.

# Create JAR with just your platform (for testing)
./assemble-universal-jar.sh --allow-missing-platforms
```

### **CI/CD Development**
- Push to GitHub triggers full multi-platform build
- All platforms built in parallel
- Universal JAR artifact available for download

## Troubleshooting

### **Missing Compilers**
```bash
# Linux
sudo apt-get install gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf

# macOS  
xcode-select --install

# Windows
# Install Visual Studio or Build Tools for Visual Studio
```

### **Android NDK Issues**
```bash
# Verify NDK setup
export ANDROID_NDK_ROOT=/path/to/android-ndk-r25c
ls $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/

# Should show clang compilers for each architecture
```

### **Java Issues**
```bash
# Verify JAVA_HOME
echo $JAVA_HOME
ls $JAVA_HOME/include/

# Should show jni.h and platform-specific jni_md.h
```

### **Assembly Issues**
```bash
# Check what platforms were built
ls build/native/

# Show detailed assembly process  
./assemble-universal-jar.sh --allow-missing-platforms
```

## Build Architecture

The build system uses **platform-specific builds** where each platform is built using its optimal toolchain:

```bash
./build-linux.sh           # Fast build with cross-compilers
./build-android.sh   # With cached NDK  
./build-windows.ps1         # On Windows with MSVC
./build-macos.sh           # On macOS with Xcode
./assemble-universal-jar.sh # Combine everything
```

This approach is **faster, more reliable, and easier to debug** than cross-compilation alternatives.