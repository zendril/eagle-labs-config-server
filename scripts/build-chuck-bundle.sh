#!/bin/bash
set -e

# Resolve the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ARTIFACTS_DIR="$PROJECT_ROOT/public/artifacts"
SOURCE_DIR="$PROJECT_ROOT/chuck-artifact-bundle"
OUTPUT_FILE="$ARTIFACTS_DIR/chuck-bundle.tar.gz"

# Create artifacts directory
echo "Creating artifacts directory: $ARTIFACTS_DIR"
mkdir -p "$ARTIFACTS_DIR"

# Build the tarball
echo "Packaging contents of $SOURCE_DIR into $OUTPUT_FILE"
tar -czf "$OUTPUT_FILE" -C "$SOURCE_DIR" .

echo "Build complete."
