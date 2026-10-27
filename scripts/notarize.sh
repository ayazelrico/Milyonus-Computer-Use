#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPER_ID:?Set DEVELOPER_ID to the installed Developer ID Application identity.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing notarytool Keychain profile.}"
case "$DEVELOPER_ID" in 'Developer ID Application: '*) ;; *) echo 'A Developer ID Application identity is required.' >&2; exit 64;; esac
./scripts/build-apps.sh release
for name in MilyonusComputerUse ComputerUseFixture; do
    app="build/$name.app"
    codesign --force --sign "$DEVELOPER_ID" --options runtime --timestamp "$app"
    codesign --verify --strict "$app"
    archive="build/$name-notarization.zip"
    ditto -c -k --keepParent "$app" "$archive"
    xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose "$app"
done
printf 'Notarization finished. Release acceptance still requires the documented live tests.\n'
