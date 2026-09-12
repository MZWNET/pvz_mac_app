#!/usr/bin/env bash
#
# Copies out/engine/ into a .app. Called both as an Xcode post-build phase and manually:
#   embed-engine.sh "/path/to/PvZ Portable.app"
#
# The engine and libs/ have to land in Contents/MacOS: after the launcher execs, the engine is the main executable, and its rpath is @executable_path/libs/.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

APP="${1:-}"
if [[ -z "$APP" ]]; then
  [[ -n "${BUILT_PRODUCTS_DIR:-}" && -n "${WRAPPER_NAME:-}" ]] ||
    die "no .app path given, and not running inside an Xcode build"
  APP="$BUILT_PRODUCTS_DIR/$WRAPPER_NAME"
fi

[[ -d "$APP" ]] || die "$APP does not exist"
[[ -x "$ENGINE_OUT/pvz-portable" ]] ||
  die "no engine output yet. Run:\n  devenv shell -- build-engine"

MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# wipe first, so a vanilla binary or stale dylib from an earlier --variants both cannot linger
rm -f "$MACOS_DIR"/pvz-portable "$MACOS_DIR"/pvz-portable-vanilla
rm -rf "$MACOS_DIR/libs"

# ditto rather than cp: it carries extended attributes across, leaving the ad-hoc signatures intact
for bin in "$ENGINE_OUT"/pvz-portable*; do
  ditto "$bin" "$MACOS_DIR/$(basename "$bin")"
done
ditto "$ENGINE_OUT/libs" "$MACOS_DIR/libs"
ditto "$ENGINE_OUT/build-info.json" "$RES_DIR/build-info.json"

# sdl2-compat dlopens SDL3, so otool cannot catch this one; without the file the game dies on launch
[[ -f "$MACOS_DIR/libs/libSDL3.dylib" ]] ||
  die "libs/libSDL3.dylib did not make it into the bundle — sdl2-compat could not load SDL3"

info "engine embedded into ${APP##*/}"
