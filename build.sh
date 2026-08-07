#!/bin/zsh
# Builds Middling and assembles Middling.app in ./dist
set -euo pipefail

cd "$(dirname "$0")"

swift build -c release

APP=dist/Middling.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp Support/Info.plist "$APP/Contents/Info.plist"
cp .build/release/Middling "$APP/Contents/MacOS/Middling"

mkdir -p "$APP/Contents/Resources"

# Menu bar glyph.
if [ -f Assets/middling.svg ]; then
    cp Assets/middling.svg "$APP/Contents/Resources/middling.svg"
fi

# App icon, compiled from the Icon Composer document.
if [ -d Assets/Middling.icon ]; then
    ICON_OUT=$(mktemp -d)
    xcrun actool "$PWD/Assets/Middling.icon" --compile "$ICON_OUT" \
        --platform macosx --minimum-deployment-target 15.0 \
        --app-icon Middling \
        --output-partial-info-plist "$ICON_OUT/partial.plist" > /dev/null
    cp "$ICON_OUT/Assets.car" "$ICON_OUT/Middling.icns" "$APP/Contents/Resources/"
fi

# Prefer a real signing identity: its designated requirement is stable, so
# the Accessibility grant survives rebuilds. With ad-hoc signing, embed an
# explicit identifier-based designated requirement instead of the default
# cdhash one, which would invalidate the grant on every rebuild.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(.*\)".*/\1/p' | head -1)
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
    echo "Signed with: $IDENTITY"
else
    codesign --force --sign - \
        --identifier com.forestkatsch.Middling \
        -r='designated => identifier "com.forestkatsch.Middling"' \
        "$APP"
    echo "Signed with: ad-hoc (stable identifier requirement)"
fi

echo "Built $APP"
