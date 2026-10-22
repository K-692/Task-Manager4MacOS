#!/usr/bin/env bash
set -euo pipefail

# Build Universal Binary (Apple Silicon + Intel)
echo "==> Building arm64 and x86_64 universal slices..."

swift build -c release --triple arm64-apple-macosx13.0
swift build -c release --triple x86_64-apple-macosx13.0

mkdir -p dist/universal
lipo -create \
    .build/arm64-apple-macosx13.0/release/TaskManager \
    .build/x86_64-apple-macosx13.0/release/TaskManager \
    -output dist/universal/TaskManager

echo "==> Universal binary created at dist/universal/TaskManager"
lipo -info dist/universal/TaskManager
