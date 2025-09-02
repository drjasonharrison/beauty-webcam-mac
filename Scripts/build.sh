#!/bin/bash

# BeautyWebcam Build Script
# Builds and tests the BeautyWebcam application

set -e  # Exit on any error

echo "🚀 Building BeautyWebcam..."

# Clean build directory
echo "🧹 Cleaning build directory..."
rm -rf build/

# Build the project
echo "🔨 Building project..."
xcodebuild -project BeautyWebcam.xcodeproj \
           -scheme BeautyWebcam \
           -configuration Debug \
           -derivedDataPath build/ \
           clean build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📦 Application built at: build/Build/Products/Debug/BeautyWebcam.app"
    
    # Show app info
    echo "📋 Application Info:"
    ls -la "build/Build/Products/Debug/BeautyWebcam.app"
    
    echo ""
    echo "🎉 BeautyWebcam is ready to run!"
    echo "💡 You can run it with: open build/Build/Products/Debug/BeautyWebcam.app"
else
    echo "❌ Build failed!"
    exit 1
fi
