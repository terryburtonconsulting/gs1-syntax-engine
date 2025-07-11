#!/bin/bash

# Simple script to build universal multi-architecture JAR without Gradle dependency

set -e
set -x

IMAGE_TAG=gs1-cross-compiler-universal
DOCKERFILE=docker/Dockerfile.universal

# Check if Docker image exists
if [ -z "$(docker images -q gs1-cross-compiler-universal)" ]; then
    echo "Building universal Docker cross-compilation image..."
    docker build -t "$IMAGE_TAG" -f "$DOCKERFILE" .
fi

echo "Building universal multi-architecture JAR..."

# Create build directory
mkdir -p build

# Run the Docker cross-compilation
docker run --rm \
    -v "$(pwd)/..:/workspace" \
    -w /workspace/java \
    "$IMAGE_TAG" \
    build-cross-universal.sh

echo "JAR build completed!"
echo "JAR location: build/gs1-syntax-engine-multiarch-1.1.0.jar"
