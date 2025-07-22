#!/usr/bin/env pwsh

Write-Host "=== Building Windows Libraries with MSVC ==="

# Verify we're on Windows
if ($IsLinux -or $IsMacOS) {
    Write-Error "This script must be run on Windows with MSVC"
    exit 1
}

# Verify JAVA_HOME is set
if (-not $env:JAVA_HOME) {
    Write-Error "JAVA_HOME environment variable not set"
    Write-Host "Please set JAVA_HOME to your JDK 8 installation path"
    Write-Host "Example: `$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-8.0.412.8-hotspot'"
    exit 1
}

if (-not (Test-Path $env:JAVA_HOME)) {
    Write-Error "JAVA_HOME path does not exist: $env:JAVA_HOME"
    exit 1
}

Write-Host "✅ Using JAVA_HOME: $env:JAVA_HOME"

# Verify MSVC is available
try {
    $null = Get-Command cl -ErrorAction Stop
    Write-Host "✅ Microsoft C/C++ Compiler (cl.exe) found"
} catch {
    Write-Error "Microsoft C/C++ Compiler (cl.exe) not found"
    Write-Host "Please run this script from a Visual Studio Developer Command Prompt"
    Write-Host "Or run: Import-Module 'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Microsoft.VisualStudio.DevShell.dll'"
    exit 1
}

# Build configurations
$platforms = @{
    "windows_x86_64" = @{
        "arch" = "x64"
        "target" = "x64"
    }
    "windows_x86" = @{
        "arch" = "x86" 
        "target" = "x86"
    }
}

# Create build directories
New-Item -ItemType Directory -Force -Path "build\native" | Out-Null

# Change to C library directory
Push-Location ..\c-lib

foreach ($platform in $platforms.Keys) {
    $config = $platforms[$platform]
    $arch = $config.arch
    $target = $config.target
    
    Write-Host "=== Building C library for $platform ($arch) ==="
    
    # Clean previous build
    if (Test-Path "build") {
        Remove-Item -Recurse -Force build
    }
    
    # Create build directory
    New-Item -ItemType Directory -Force -Path "build" | Out-Null
    
    # Build C library
    $cFiles = Get-ChildItem -Filter "*.c" | ForEach-Object { $_.Name }
    $clArgs = @("/O2", "/c") + $cFiles
    
    try {
        & cl @clArgs 2>&1 | Tee-Object -FilePath "build-$platform.log"
        if ($LASTEXITCODE -ne 0) { throw "C compilation failed" }
        
        # Create static library
        $objFiles = Get-ChildItem -Filter "*.obj" | ForEach-Object { $_.Name }
        & lib "/out:build\gs1encoders.lib" @objFiles 2>&1 | Tee-Object -Append -FilePath "build-$platform.log"
        if ($LASTEXITCODE -ne 0) { throw "Library creation failed" }
        
        # Copy to platform-specific directory
        New-Item -ItemType Directory -Force -Path "..\java\build\native\$platform" | Out-Null
        Copy-Item "build\gs1encoders.lib" "..\java\build\native\$platform\"
        
        Write-Host "✓ C library built for $platform"
        
        # Clean up object files
        Remove-Item -Force *.obj -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "✗ Failed to build C library for $platform (see ..\c-lib\build-$platform.log)"
        continue
    }
    
    # Build JNI library
    Pop-Location
    Push-Location .
    
    Write-Host "Building JNI library for $platform..."
    
    New-Item -ItemType Directory -Force -Path "build\native\$platform" | Out-Null
    $outputFile = "build\native\$platform\gs1encodersjni.dll"
    
    # JNI compilation
    $jniArgs = @(
        "/O2", "/LD", "/MD"
        "gs1encoders_wrap.c"
        "/I..\c-lib"
        "/I$env:JAVA_HOME\include"
        "/I$env:JAVA_HOME\include\win32" 
        "/Fe:$outputFile"
        "..\c-lib\build\gs1encoders.lib"
    )
    
    try {
        & cl @jniArgs 2>&1 | Tee-Object -FilePath "build\native\$platform\build.log"
        if ($LASTEXITCODE -ne 0) { throw "JNI compilation failed" }
        
        Write-Host "✓ Successfully built $platform JNI library"
        
        # Clean up intermediate files
        Remove-Item -Force "gs1encoders_wrap.obj" -ErrorAction SilentlyContinue
        Remove-Item -Force "gs1encodersjni.exp" -ErrorAction SilentlyContinue
        Remove-Item -Force "gs1encodersjni.lib" -ErrorAction SilentlyContinue
        
        # Show library info
        if (Test-Path $outputFile) {
            $fileInfo = Get-Item $outputFile
            Write-Host "  $outputFile ($([math]::Round($fileInfo.Length/1KB, 1)) KB)"
        }
        
    } catch {
        Write-Host "✗ Failed to build $platform JNI library (see build\native\$platform\build.log)"
        continue
    }
    
    Push-Location ..\c-lib
}

Pop-Location

Write-Host ""
Write-Host "=== Windows Build Summary ==="
Write-Host "Built libraries:"
Get-ChildItem -Path "build\native" -Filter "*.dll" -Recurse | Where-Object { $_.Directory.Name -like "windows_*" } | ForEach-Object {
    $size = [math]::Round($_.Length/1KB, 1)
    Write-Host "  $($_.FullName) ($size KB)"
}

Write-Host "=== Windows Build Complete ==="