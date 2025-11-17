#!/bin/bash

# Build Lambda deployment package with dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_DIR="$SCRIPT_DIR/../lambda"
BUILD_DIR="$SCRIPT_DIR/../build"

echo "Building Lambda deployment package..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Detect available pip command
PIP_CMD=""
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
elif command -v python3 &> /dev/null; then
    PIP_CMD="python3 -m pip"
elif command -v python &> /dev/null; then
    PIP_CMD="python -m pip"
else
    echo "ERROR: No pip or python command found"
    echo "Please install Python 3 and pip"
    exit 1
fi

echo "Using pip command: $PIP_CMD"

# Install dependencies to build directory
echo "Installing Python dependencies..."
$PIP_CMD install -r "$LAMBDA_DIR/requirements.txt" -t "$BUILD_DIR" --quiet

# Copy Lambda function code
echo "Copying Lambda function code..."
cp "$LAMBDA_DIR/collector.py" "$BUILD_DIR/"
cp "$LAMBDA_DIR/api.py" "$BUILD_DIR/"

echo "✓ Lambda package built successfully in $BUILD_DIR"
echo ""
echo "Files in package:"
ls -lh "$BUILD_DIR"/*.py 2>/dev/null || true
echo ""
echo "Dependencies installed:"
ls -d "$BUILD_DIR"/*/ 2>/dev/null | head -5 || true
