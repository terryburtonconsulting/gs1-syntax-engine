# GS1 Syntax Engine - Multi-Architecture Java JAR

This directory contains the Java wrapper for the GS1 Syntax Engine, packaged as a single multi-architecture JAR that supports multiple operating systems and architectures.

## Features

- **Multi-Architecture Support**: Single JAR works on Linux, macOS, and Windows
- **Cross-Platform**: Supports x86, x86_64, ARM, and ARM64 architectures
- **Android Compatible**: Optimized for Android APK integration
- **Automatic Library Loading**: Runtime detection and loading of native libraries
- **Maven Central Ready**: Configured for publishing to Maven Central

## Supported Platforms

| Platform | Architecture | Library File |
|----------|--------------|--------------|
| Linux | x86_64 | `libgs1encodersjni.so` |
| Linux | x86 | `libgs1encodersjni.so` |
| Linux | ARM64 | `libgs1encodersjni.so` |
| Linux | ARM | `libgs1encodersjni.so` |
| macOS | x86_64 | `libgs1encodersjni.dylib` |
| macOS | ARM64 | `libgs1encodersjni.dylib` |
| Windows | x86_64 | `gs1encodersjni.dll` |
| Windows | x86 | `gs1encodersjni.dll` |

## Building

### Prerequisites

- Java 8 or later
- GCC/Clang compiler
- Cross-compilation toolchains (for multi-platform builds)

### Build Current Platform

```bash
# Build for current platform only
./gradlew buildNativeCurrent

# Build JAR with current platform
./gradlew jar
```

### Build All Platforms

```bash
# Build native libraries for all platforms
./gradlew buildNativeLinux_x86_64 buildNativeLinux_x86 buildNativeLinux_aarch64 buildNativeLinux_arm
./gradlew buildNativeDarwin_x86_64 buildNativeDarwin_aarch64
./gradlew buildNativeWindows_x86_64 buildNativeWindows_x86

# Build multi-architecture JAR
./gradlew jar
```

### Multi-Platform Builds

```bash
# Build all available platforms natively
./build-all-platforms.sh

# Or build specific platforms:
./build-linux.sh           # Linux (with cross-compilation)
./build-android.sh         # Android (requires ANDROID_NDK_ROOT)
./build-macos.sh            # macOS (native)
./build-windows.ps1         # Windows (native)

# Assemble universal JAR
./assemble-universal-jar.sh
```

## Usage

### Maven Dependency

```xml
<dependency>
    <groupId>org.gs1</groupId>
    <artifactId>gs1-syntax-engine</artifactId>
    <version>1.1.0</version>
</dependency>
```

### Gradle Dependency

```gradle
implementation 'org.gs1:gs1-syntax-engine:1.1.0'
```

### Java Code

```java
import org.gs1.gs1encoders.GS1Encoder;

public class Example {
    public static void main(String[] args) {
        try {
            GS1Encoder encoder = new GS1Encoder();
            System.out.println("GS1 Encoder version: " + encoder.getVersion());
            encoder.free();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

## Android Integration

The multi-architecture JAR is designed to work seamlessly with Android projects:

### Android Gradle Configuration

```gradle
dependencies {
    implementation 'org.gs1:gs1-syntax-engine:1.1.0'
}
```

### ProGuard Rules

```proguard
# Keep GS1 Encoders native methods
-keep class org.gs1.gs1encoders.** { *; }
-keepclassmembers class org.gs1.gs1encoders.** {
    native <methods>;
}

# Keep native library loader
-keep class org.gs1.gs1encoders.NativeLibraryLoader { *; }
```

## Architecture

### Native Library Loading

The `NativeLibraryLoader` class handles automatic platform detection and native library loading:

1. **Platform Detection**: Automatically detects OS and architecture
2. **Resource Extraction**: Extracts appropriate native library from JAR
3. **Android Support**: Special handling for Android APK environment
4. **Fallback Strategy**: Falls back to system libraries if available

### JAR Structure

```
gs1-syntax-engine-1.1.0.jar
├── org/gs1/gs1encoders/
│   ├── GS1Encoder.class
│   ├── NativeLibraryLoader.class
│   └── ...
└── META-INF/
    └── lib/
        ├── linux_x86_64/
        │   └── libgs1encodersjni.so
        ├── linux_x86/
        │   └── libgs1encodersjni.so
        ├── linux_aarch64/
        │   └── libgs1encodersjni.so
        ├── linux_arm/
        │   └── libgs1encodersjni.so
        ├── darwin_x86_64/
        │   └── libgs1encodersjni.dylib
        ├── darwin_aarch64/
        │   └── libgs1encodersjni.dylib
        ├── windows_x86_64/
        │   └── gs1encodersjni.dll
        └── windows_x86/
            └── gs1encodersjni.dll
```

## Development

### Testing

```bash
# Run tests (requires current platform native library)
./gradlew test

# Run example
./gradlew example
```

### Publishing

```bash
# Build all artifacts
./gradlew build

# Publish to Maven Local
./gradlew publishToMavenLocal

# Publish to Maven Central (requires credentials)
./gradlew publishToSonatype closeAndReleaseSonatypeStagingRepository
```

## Migration from Single-Platform JAR

If you're migrating from the previous single-platform JAR:

1. **No Code Changes Required**: The API remains the same
2. **Remove Platform-Specific Dependencies**: No need for separate JARs per platform
3. **Update Build Configuration**: Use the new multi-architecture JAR dependency
4. **Android Projects**: Remove native build configuration, use JAR dependency

## Troubleshooting

### Library Loading Issues

If you encounter `UnsatisfiedLinkError`:

1. Check that your platform is supported
2. Verify JVM architecture matches available libraries
3. For Android, ensure ProGuard rules are configured correctly
4. Try setting system property: `-Djava.library.path=/path/to/native/libs`

### Build Issues

- Ensure C library is built first: `cd ../c-lib && make`
- Check cross-compilation toolchains are installed
- For Android builds, ensure ANDROID_NDK_ROOT is set correctly

## License

Licensed under the Apache License, Version 2.0. See the LICENSE file for details.