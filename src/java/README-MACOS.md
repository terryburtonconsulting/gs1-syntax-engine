# macOS Library Build

The universal JAR includes libraries for macOS (both Intel and Apple Silicon) built on macOS using Xcode toolchain.

## Prerequisites

1. **macOS**: Requires macOS system for builds
2. **Xcode Command Line Tools**: `xcode-select --install`
3. **Java 8+**: Set `JAVA_HOME` environment variable

## Quick Setup

### Install Xcode Command Line Tools
```bash
xcode-select --install
```

### Set JAVA_HOME
```bash
# For Temurin/AdoptOpenJDK
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home

# For Oracle JDK
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_XXX.jdk/Contents/Home

# Add to ~/.zshrc or ~/.bash_profile to make permanent
echo 'export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home' >> ~/.zshrc
```

## Build Process

### macOS Build
```bash
cd src/java
./build-macos.sh
```

This builds:
- **darwin_x86_64**: Intel Macs (2006-2023)
- **darwin_aarch64**: Apple Silicon M1/M2/M3/M4 (2020+)

### Build Configuration

The build script automatically:
1. Detects available architectures (x86_64 and/or arm64)
2. Sets deployment target to macOS 11.0 (configurable)
3. Cross-compiles from Intel to Apple Silicon if needed
4. Creates universal dylib files when both architectures available

## Integration with Universal JAR

### Local Development
```bash
# After building macOS libraries
./assemble-universal-jar.sh --allow-missing-platforms
```

### CI/CD Integration
The GitHub Actions workflow includes a dedicated macOS runner:

```yaml
build-macos:
  runs-on: macos-latest
  steps:
    - uses: actions/checkout@v3
    - name: Set up JDK 8
      uses: actions/setup-java@v3
      with:
        java-version: '8'
        distribution: 'temurin'
    - name: Build macOS libraries
      run: |
        cd src/java
        ./build-macos.sh
```

## Build Output

### Library Structure
```
build/native/
├── darwin_x86_64/
│   ├── libgs1encoders.a
│   └── libgs1encodersjni.dylib
└── darwin_aarch64/
    ├── libgs1encoders.a
    └── libgs1encodersjni.dylib
```

### JAR Integration
Libraries are embedded in the universal JAR as:
```
META-INF/lib/
├── darwin_x86_64/libgs1encodersjni.dylib
└── darwin_aarch64/libgs1encodersjni.dylib
```

## Performance

| Architecture | Build Time | Notes |
|--------------|------------|-------|
| darwin_x86_64 | ~30 sec | Build on Intel Mac |
| darwin_aarch64 | ~30 sec | Build on Apple Silicon Mac |
| Cross-compile | ~45 sec | Building both archs on single machine |

## Troubleshooting

### "Command line tools not found"
```bash
xcode-select --install
# If already installed, try:
sudo xcode-select --reset
```

### "JAVA_HOME not set"
```bash
# Find Java installations
/usr/libexec/java_home -V

# Set JAVA_HOME to Java 8
export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
```

### "Cannot find jni.h"
```bash
# Verify JAVA_HOME includes headers
ls $JAVA_HOME/include/
# Should show: jni.h jni_md.h

# If missing, install JDK (not just JRE)
```

### Architecture Issues
```bash
# Check what architectures your Mac supports
uname -m
# x86_64 = Intel Mac
# arm64 = Apple Silicon Mac

# Check built libraries
file build/native/darwin_*/libgs1encodersjni.dylib
```

### Build Fails on Apple Silicon
Some issues with mixed architectures:
```bash
# Clear any cached builds
make clean -C ../c-lib

# Ensure consistent architecture
arch -arm64 ./build-macos.sh  # Force ARM64
arch -x86_64 ./build-macos.sh # Force Intel (under Rosetta)
```

## Development Notes

### Deployment Target
The build targets macOS 11.0+ by default. To change:

```bash
# Edit build-macos.sh
export MACOSX_DEPLOYMENT_TARGET=10.15  # For older macOS support
```

### Universal Libraries
If you need single universal libraries (fat binaries):
```bash
# After building both architectures
lipo -create \
  build/native/darwin_x86_64/libgs1encodersjni.dylib \
  build/native/darwin_aarch64/libgs1encodersjni.dylib \
  -output libgs1encodersjni-universal.dylib
```

### Debugging
```bash
# Check library dependencies
otool -L build/native/darwin_*/libgs1encodersjni.dylib

# Check symbols
nm -D build/native/darwin_*/libgs1encodersjni.dylib | grep Java

# Verify architecture
lipo -info build/native/darwin_*/libgs1encodersjni.dylib
```

The macOS build approach provides faster, more reliable builds compared to cross-compilation alternatives, while maintaining full compatibility with both Intel and Apple Silicon Macs.