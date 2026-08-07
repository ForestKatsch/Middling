#!/bin/zsh
# Builds, signs with Developer ID, notarizes, staples, and zips a release.
#
# One-time setup:
#   1. Xcode -> Settings -> Accounts -> Manage Certificates
#      -> add "Developer ID Application"
#   2. xcrun notarytool store-credentials middling \
#          --apple-id <apple-id> --team-id <team-id> \
#          --password <app-specific-password>
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

IDENTITY=$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application[^"]*\)".*/\1/p' | head -1)
if [ -z "$IDENTITY" ]; then
    echo "No Developer ID Application identity found." >&2
    exit 1
fi

APP=dist/Middling.app

# Notarization requires the hardened runtime and a secure timestamp.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"

VERSION=$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleShortVersionString)
ZIP=dist/Middling-$VERSION.zip

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile middling --wait

xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

spctl -a -vv "$APP"
echo "Release ready: $ZIP"
