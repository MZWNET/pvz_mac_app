#!/usr/bin/env bash
#
# Generates the Xcode project, builds the launcher and assembles out/PvZ Portable.app. Requires out/engine/, produced by build-engine.sh.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CONFIGURATION=Release
while [[ $# -gt 0 ]]; do
  case "$1" in
  --debug)
    CONFIGURATION=Debug
    shift
    ;;
  -h | --help)
    echo "usage: build-app.sh [--debug]" >&2
    exit 0
    ;;
  *) die "unknown argument $1" ;;
  esac
done

need_cmd xcodegen "Run inside the devenv shell."
need_cmd xcbeautify "Run inside the devenv shell."
need_cmd xcodebuild "Needs Xcode, not just the Command Line Tools."

[[ -f "$ENGINE_OUT/build-info.json" ]] ||
  die "no engine output yet. Run:\n  devenv shell -- build-engine"

[[ -f "$ROOT/launcher/Assets.xcassets/AppIcon.appiconset/Contents.json" ]] ||
  die "no app icon yet. Run:\n  devenv shell -- make-appicon"

# plutil reads JSON fine, which saves pulling in jq
json() { plutil -extract "$1" raw -o - "$ENGINE_OUT/build-info.json"; }
MARKETING_VERSION="$(json engineVersion)"
BUILD_NUMBER="$(json buildNumber)"

info "generating the Xcode project"
(cd "$ROOT" && xcodegen generate --quiet)

info "building the launcher ($CONFIGURATION, v$MARKETING_VERSION build $BUILD_NUMBER)"
DERIVED="$ROOT/build/xcode"
# The devenv shell exports LD=ld for nix's toolchain, and xcodebuild takes environment variables as build-setting overrides — Xcode then drives the link with ld instead of clang, and clang's own flags reach ld verbatim. The rest of nix's toolchain variables turn out to be ignored here.
unset LD

xcodebuild \
  -project "$ROOT/PvZPortable.xcodeproj" \
  -scheme PvZPortable \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  build | xcbeautify

BUILT="$DERIVED/Build/Products/$CONFIGURATION/$APP_NAME.app"
[[ -d "$BUILT" ]] || die "build product $BUILT not found"

info "copying to ${APP_OUT#"$ROOT"/}"
rm -rf "$APP_OUT"
mkdir -p "$OUT_DIR"
ditto "$BUILT" "$APP_OUT"

# Re-seal unconditionally so the signature covers the embedded engine, whatever order Xcode ran its signing step and the post-build phase in. No --deep: the engine and its dylibs are already signed individually.
info "re-sealing the ad-hoc signature"
codesign --force --sign - "$APP_OUT"

"$ROOT/scripts/verify-app.sh"
