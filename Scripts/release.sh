#!/usr/bin/env bash
# Build, sign, notarize, staple and package UIMole as a DMG for out-of-MAS distribution.
#
# Requires:
#   - Developer ID Application certificate in the Keychain
#   - App Store Connect API key for notarytool, provided via env:
#       ASC_API_KEY_PATH     path to the .p8 file
#       ASC_API_KEY_ID       key id
#       ASC_API_ISSUER_ID    issuer id
#   - Tools: xcodegen, xcodebuild, notarytool (bundled with Xcode), create-dmg (brew install create-dmg)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/UIMole.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/UIMole.app"
ZIP_PATH="$BUILD_DIR/UIMole.zip"
DMG_PATH="$BUILD_DIR/UIMole.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Fetching Mole CLI"
"$REPO_ROOT/Scripts/fetch-mole.sh"

echo "==> Generating Xcode project"
( cd "$REPO_ROOT" && xcodegen generate )

echo "==> Archiving"
xcodebuild \
    -project "$REPO_ROOT/UIMole.xcodeproj" \
    -scheme UIMole \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    archive

echo "==> Exporting archive"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$REPO_ROOT/Scripts/ExportOptions.plist"

echo "==> Verifying local signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH" || echo "  (spctl will only accept after stapling)"

if [[ -z "${ASC_API_KEY_PATH:-}" || -z "${ASC_API_KEY_ID:-}" || -z "${ASC_API_ISSUER_ID:-}" ]]; then
    echo ""
    echo "!! ASC_API_KEY_PATH / ASC_API_KEY_ID / ASC_API_ISSUER_ID not set — skipping notarization."
    echo "   To notarize, re-run with those env vars set."
    exit 0
fi

echo "==> Notarizing"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" \
    --key "$ASC_API_KEY_PATH" \
    --key-id "$ASC_API_KEY_ID" \
    --issuer "$ASC_API_ISSUER_ID" \
    --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "==> Building DMG"
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg not found; falling back to hdiutil."
    hdiutil create -volname UIMole -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
else
    create-dmg \
        --volname "UIMole" \
        --window-size 540 380 \
        --icon-size 100 \
        --icon "UIMole.app" 140 190 \
        --app-drop-link 400 190 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_PATH"
fi

echo "==> Stapling DMG"
xcrun stapler staple "$DMG_PATH"

echo "==> Final verification"
spctl --assess --type execute --verbose=4 "$APP_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

echo ""
echo "Done. Artifacts:"
echo "  $APP_PATH"
echo "  $DMG_PATH"
