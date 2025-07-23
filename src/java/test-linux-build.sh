#\!/bin/bash
set -e

echo '=== Testing Linux x86_64 Native Build ==='

# Build C library first
cd ../c-lib
echo 'Building C library...'
make clean > /dev/null 2>&1 || true
if make libstatic > build.log 2>&1; then
    echo '✓ C library built successfully'
else
    echo '✗ C library build failed:'
    tail -10 build.log
    exit 1
fi

# Build JNI wrapper
cd ../java  
echo 'Building JNI wrapper...'
mkdir -p build/native/linux_x86_64

if gcc -shared -fPIC -O2 -fvisibility=hidden     -I../c-lib     -I"$JAVA_HOME/include"     -I"$JAVA_HOME/include/linux"     -o "build/native/linux_x86_64/libgs1encodersjni.so"     gs1encoders_wrap.c     ../c-lib/build/libgs1encoders.a > build/native/linux_x86_64/build.log 2>&1; then
    
    echo '✓ JNI library built successfully'
    file build/native/linux_x86_64/libgs1encodersjni.so
    echo '✓ Linux x86_64 build test complete\!'
else
    echo '✗ JNI library build failed:'
    cat build/native/linux_x86_64/build.log
    exit 1
fi
