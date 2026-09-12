#!/usr/bin/env bash
#
# Static checks on an assembled .app; this is what devenv's enterTest runs. Every check corresponds to a way the bundle can break on someone else's machine while looking fine on this one.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

APP="${1:-$APP_OUT}"
[[ -d "$APP" ]] || die "$APP does not exist. Run:\n  devenv shell -- build-app"

MACOS_DIR="$APP/Contents/MacOS"
failures=0

pass() { printf '  %s✓%s %s\n' "$_c_grn" "$_c_off" "$*" >&2; }
fail() {
  printf '  %s✗%s %s\n' "$_c_red" "$_c_off" "$*" >&2
  failures=$((failures + 1))
}
check() { # <label> <command...>
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

info "verifying ${APP##*/}"

check "Info.plist is valid" plutil -lint "$APP/Contents/Info.plist"
check "launcher present" test -x "$MACOS_DIR/$APP_NAME"
check "engine present" test -x "$MACOS_DIR/pvz-portable"
check "build-info.json present" test -f "$APP/Contents/Resources/build-info.json"
check "icon compiled" test -f "$APP/Contents/Resources/AppIcon.icns"
# otool cannot see this one: sdl2-compat reaches SDL3 through dlopen
check "libs/libSDL3.dylib present" test -f "$MACOS_DIR/libs/libSDL3.dylib"
check "en.lproj present" test -f "$APP/Contents/Resources/en.lproj/Localizable.strings"
check "zh-Hans.lproj present" test -f "$APP/Contents/Resources/zh-Hans.lproj/Localizable.strings"

# A broken localization shows up as raw keys in the UI, often only in one language. Checking both directions turns that into a build failure.
EN_SRC="$ROOT/launcher/en.lproj/Localizable.strings"
ZH_SRC="$ROOT/launcher/zh-Hans.lproj/Localizable.strings"
declared_keys() { grep -oE '^"[^"]+"' "$1" | tr -d '"' | sort -u; }
# keys all carry a namespace prefix, which separates UI strings from plain ones like "main.pak"
used_keys() {
  grep -ohE '"(menu|common|home|badge|flag|crash|import|error)\.[a-z0-9_.]+"' \
    "$ROOT"/launcher/*.swift | tr -d '"' | sort -u
}

if diff_out="$(diff <(declared_keys "$EN_SRC") <(declared_keys "$ZH_SRC"))"; then
  pass "key sets match ($(declared_keys "$EN_SRC" | wc -l | tr -d ' ') keys)"
else
  fail "key sets differ (< English only, > Chinese only):"
  printf '%s\n' "$diff_out" >&2
fi

if missing="$(comm -23 <(used_keys) <(declared_keys "$EN_SRC"))" && [[ -z "$missing" ]]; then
  pass "every key used from Swift is declared"
else
  fail "these keys are used from Swift but never declared, so the UI would show raw keys:"
  printf '%s\n' "$missing" >&2
fi

# after the exec the engine is the main executable, so @executable_path is Contents/MacOS
check "engine has the @executable_path/libs rpath" \
  bash -c "otool -l '$MACOS_DIR/pvz-portable' | grep -q '@executable_path/libs/'"

check "launcher is signed" bash -c "codesign -dv '$MACOS_DIR/$APP_NAME' 2>&1 | grep -q Signature"
check "bundle signature is self-consistent" codesign --verify --strict "$APP"

info "checking that dylibs were fully collected"
if no_leaked_paths "$APP"; then
  pass "no leftover absolute paths"
else
  fail "unbundled dependencies, listed above"
fi

# The real floor is set by the toolchain, so this is reported rather than enforced.
MIN="$(otool -l "$MACOS_DIR/pvz-portable" | awk '/LC_BUILD_VERSION/{f=1} f && /^ *minos/{print $2; exit}')"
step "engine min macOS ${MIN:-unknown}"
step "bundle size $(du -sh "$APP" | cut -f1)"

[[ "$failures" == 0 ]] || die "$failures check(s) failed"
info "all checks passed"
