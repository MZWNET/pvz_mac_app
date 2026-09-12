#!/usr/bin/env bash
#
# Packages out/PvZ Portable.app into a DMG. Neither signed nor notarized.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[[ -d "$APP_OUT" ]] || die "no .app yet. Run:\n  devenv shell -- build-app"

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$APP_OUT/Contents/Info.plist" 2>/dev/null || echo 0.0.0)"
DMG="$OUT_DIR/PvZ-Portable-$VERSION-$(uname -m).dmg"
STAGE="$OUT_DIR/dmg-stage"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "$APP_OUT" "$STAGE/$APP_NAME.app"

# create-dmg lays the window out nicely but drives it through AppleScript, which hangs on a CI machine with no graphical session. Falling back to hdiutil only costs the background image and icon positions.
made=0
if command -v create-dmg >/dev/null 2>&1; then
  info "packaging with create-dmg"
  if create-dmg \
    --volname "PvZ Portable" \
    --window-size 520 320 \
    --icon-size 110 \
    --icon "$APP_NAME.app" 130 150 \
    --app-drop-link 390 150 \
    --no-internet-enable \
    "$DMG" "$STAGE" >/dev/null 2>&1; then
    made=1
  else
    warn "create-dmg failed (expected without a graphical session), falling back to hdiutil"
  fi
fi

if [[ "$made" == 0 ]]; then
  info "packaging with hdiutil"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create \
    -volname "PvZ Portable" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null
fi

rm -rf "$STAGE"

[[ -f "$DMG" ]] || die "no DMG was produced"
info "done → ${DMG#"$ROOT"/} ($(du -h "$DMG" | cut -f1))"
