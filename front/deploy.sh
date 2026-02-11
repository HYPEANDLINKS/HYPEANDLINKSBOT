#!/bin/bash

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed or not in PATH"
    echo ""
    echo "Please install Flutter first:"
    echo "1. Download Flutter from: https://flutter.dev/docs/get-started/install/windows"
    echo "2. Extract it to a location (e.g., C:\\src\\flutter)"
    echo "3. Add Flutter to your PATH:"
    echo "   - Add C:\\src\\flutter\\bin to your system PATH"
    echo "   - Or in Git Bash, add this to your ~/.bashrc:"
    echo "     export PATH=\"\$PATH:/c/src/flutter/bin\""
    echo ""
    echo "After installing, restart your terminal and try again."
    exit 1
fi

# Regenerate favicon from current logo SVG before build/deploy
echo "Generating favicon from assets/HyperlinksSpace.svg..."
if command -v python3 &> /dev/null; then
    python3 scripts/svg_to_favicon.py || exit 1
elif command -v python &> /dev/null; then
    python scripts/svg_to_favicon.py || exit 1
else
    echo "Error: Python is required to generate favicon."
    echo "Install Python and dependency: pip install Pillow"
    exit 1
fi

# Build Flutter web app
echo "Building Flutter web app..."
flutter build web --release --base-href "//" --no-wasm-dry-run

# Check if build was successful
if [ ! -d "build/web" ]; then
    echo "Error: Build failed or build/web directory not found"
    exit 1
fi

# Copy vercel.json and API functions to build directory
echo "Copying Vercel configuration and API functions..."
cp vercel.json build/web/vercel.json

# Copy API serverless function
if [ -d "api" ]; then
    mkdir -p build/web/api
    cp -r api/* build/web/api/
    echo "API functions copied"
fi

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "Error: Vercel CLI is not installed or not in PATH"
    echo ""
    echo "Please install Vercel CLI:"
    echo "  npm i -g vercel"
    echo ""
    exit 1
fi

# Deploy to Vercel
echo "Deploying to Vercel..."
cd build/web
vercel --prod

