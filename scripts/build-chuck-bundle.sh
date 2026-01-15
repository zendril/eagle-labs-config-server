#!/bin/bash
set -e

# Resolve the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Accept version parameter (default: 1.0.0)
VERSION="${1:-1.0.0}"

# Validate semantic versioning format (X.Y.Z)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in semantic format (X.Y.Z), got: $VERSION"
    exit 1
fi

ARTIFACTS_DIR="$PROJECT_ROOT/public/artifacts"
SOURCE_DIR="$PROJECT_ROOT/chuck-artifact-bundle"
OUTPUT_FILE="$ARTIFACTS_DIR/chuck-bundle-${VERSION}.tar.gz"

# Create artifacts directory
echo "Creating artifacts directory: $ARTIFACTS_DIR"
mkdir -p "$ARTIFACTS_DIR"

# Build the tarball with version
echo "Packaging contents of $SOURCE_DIR into $OUTPUT_FILE"
tar -czf "$OUTPUT_FILE" -C "$SOURCE_DIR" .

echo "Build complete: $OUTPUT_FILE"
echo ""
echo "CI/CD Integration Notes:"
echo "- Manual: Use: build-chuck-bundle.sh 1.0.1"
echo "- CI/CD: Read version from VERSION file: build-chuck-bundle.sh \$(cat VERSION)"
echo "- GitHub Actions: Use git tags: build-chuck-bundle.sh \${GITHUB_REF#refs/tags/v}"
