#!/usr/bin/env bash
# Picks a macOS SDK the Command Line Tools can actually compile SwiftUI against.
#
# Command Line Tools 27.x ship SDKs whose SwiftUI declares @State and friends as
# macros, but not the SwiftUIMacros compiler plugin (that comes with Xcode). When
# only the Command Line Tools are installed and that plugin is missing, fall back
# to the newest bundled macOS 26.x SDK. With full Xcode (or a pre-set SDKROOT)
# nothing changes.
if [ -z "${SDKROOT:-}" ]; then
    DEV_DIR="$(xcode-select -p 2>/dev/null)"
    if [[ "$DEV_DIR" == *CommandLineTools* ]] && \
       ! find "$DEV_DIR" -iname "*SwiftUIMacros*" -print -quit 2>/dev/null | grep -q .; then
        FALLBACK="$(ls -d "$DEV_DIR"/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -n 1)"
        if [ -n "$FALLBACK" ]; then
            export SDKROOT="$FALLBACK"
            echo "==> Using $(basename "$SDKROOT") (SwiftUI macro plugin not available in Command Line Tools)"
        fi
    fi
fi
