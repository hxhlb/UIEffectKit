#!/bin/zsh

set -euo pipefail
cd "$(dirname "$0")"

DERIVED="$(pwd)/derived"
mkdir -p "$DERIVED"

if command -v swiftformat >/dev/null 2>&1; then
    swiftformat --swiftversion 6.0 . --indent 4 || true
else
    echo "swiftformat not found; skipping formatting" >&2
fi

# Build the Example app workspace
WORKSPACE="Example/UIEffectKitExample.xcworkspace"
SCHEME="UIEffectKitExample"

CMD=(xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED" \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)

if command -v xcbeautify >/dev/null 2>&1; then
    "${CMD[@]}" | xcbeautify -q --is-ci --disable-colored-output --disable-logging
else
    echo "xcbeautify not found; showing raw xcodebuild output" >&2
    "${CMD[@]}"
fi
