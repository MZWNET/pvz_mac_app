#!/usr/bin/env bash
#
# Builds the PvZ-Portable engine and collects its dylibs into the layout the .app expects.
# Output: out/engine/{pvz-portable[,-vanilla],libs/*.dylib,build-info.json}

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# No default here: devenv.nix sets PVZP_UPSTREAM_REF and the update workflow rewrites it there, so a second copy of the version would go stale on the first upstream release.
UPSTREAM_REF="${PVZP_UPSTREAM_REF:-}"
SRC_OVERRIDE=""
PVZ_DEBUG=ON
DO_FIX_BUGS=ON
VARIANTS=single
CLEAN=0

usage() {
  cat >&2 <<'EOF'
usage: build-engine.sh [options]

  --ref <tag|branch>   upstream version, default $PVZP_UPSTREAM_REF
  --src <path>         build an existing PvZ-Portable checkout instead of cloning
  --no-cheat           PVZ_DEBUG=OFF, leaving cheat and debug keys out of the binary
  --no-fix-bugs        DO_FIX_BUGS=OFF, keeping the original 1.2.0.1073 behaviour
  --variants both      build both DO_FIX_BUGS variants, switchable in the launcher
  --clean              reconfigure from scratch
  -h, --help           show this
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --ref)
    UPSTREAM_REF="${2:?--ref needs a value}"
    shift 2
    ;;
  --src)
    SRC_OVERRIDE="${2:?--src needs a path}"
    shift 2
    ;;
  --variants)
    VARIANTS="${2:?--variants needs single or both}"
    shift 2
    ;;
  --no-cheat)
    PVZ_DEBUG=OFF
    shift
    ;;
  --no-fix-bugs)
    DO_FIX_BUGS=OFF
    shift
    ;;
  --clean)
    CLEAN=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *) die "unknown argument $1 (-h for usage)" ;;
  esac
done

[[ "$VARIANTS" == single || "$VARIANTS" == both ]] || die "--variants must be single or both"

require_devenv_profile
need_cmd cmake
need_cmd ninja
need_cmd git
need_cmd dylibbundler
need_cmd codesign "Needs the Xcode Command Line Tools."
need_cmd install_name_tool "Needs the Xcode Command Line Tools."

# git rather than a tarball: upstream's CMake derives the version from git describe / rev-list and degrades to "0.1" without a .git directory.
if [[ -n "$SRC_OVERRIDE" ]]; then
  SRC="$(cd "$SRC_OVERRIDE" && pwd)"
  [[ -f "$SRC/CMakeLists.txt" ]] || die "$SRC does not look like a PvZ-Portable checkout"
  info "using existing source at $SRC"
else
  [[ -n "$UPSTREAM_REF" ]] || die "no --ref given and PVZP_UPSTREAM_REF is unset. Run inside the devenv shell."
  SRC="$THIRD_PARTY/PvZ-Portable"
  if [[ ! -d "$SRC/.git" ]]; then
    info "cloning upstream into $SRC"
    mkdir -p "$THIRD_PARTY"
    git clone --filter=blob:none "$UPSTREAM_URL" "$SRC"
  fi
  info "checking out $UPSTREAM_REF"
  git -C "$SRC" fetch --tags --force origin
  git -C "$SRC" -c advice.detachedHead=false checkout --force "$UPSTREAM_REF"
  # a branch, as opposed to a tag, still needs updating
  if git -C "$SRC" symbolic-ref -q HEAD >/dev/null; then
    git -C "$SRC" pull --ff-only
  fi
fi

ENGINE_VERSION_FULL="$(git -C "$SRC" describe --tags --abbrev=12 2>/dev/null || echo 0.1)"
ENGINE_VERSION_FULL="${ENGINE_VERSION_FULL#v}"
# CFBundleShortVersionString only accepts dotted numbers
ENGINE_VERSION="$(printf '%s' "$ENGINE_VERSION_FULL" | grep -oE '^[0-9]+(\.[0-9]+)*' || true)"
[[ -n "$ENGINE_VERSION" ]] || ENGINE_VERSION=0.1
BUILD_NUMBER="$(git -C "$SRC" rev-list --count HEAD 2>/dev/null || echo 1)"
ENGINE_COMMIT="$(git -C "$SRC" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

info "engine $ENGINE_VERSION_FULL (build $BUILD_NUMBER, $ENGINE_COMMIT)"

build_variant() { # <build subdirectory> <DO_FIX_BUGS>
  local name="$1" fix="$2"
  local bdir="$ROOT/build/$name"

  [[ "$CLEAN" == 0 ]] || rm -rf "$bdir"

  info "configuring $name (PVZ_DEBUG=$PVZ_DEBUG DO_FIX_BUGS=$fix)"
  cmake -G Ninja -S "$SRC" -B "$bdir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="$DEVENV_PROFILE" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$PVZP_DEPLOYMENT_TARGET" \
    -DPVZ_DEBUG="$PVZ_DEBUG" \
    -DDO_FIX_BUGS="$fix"

  info "building $name"
  cmake --build "$bdir"

  [[ -f "$bdir/pvz-portable" ]] || die "$bdir/pvz-portable was not produced"
}

rm -rf "$ENGINE_OUT"
mkdir -p "$ENGINE_OUT/libs"

# DO_FIX_BUGS has no runtime switch at all, so offering both behaviours means shipping two binaries.
HAS_VANILLA=false
if [[ "$VARIANTS" == both ]]; then
  build_variant fixed ON
  build_variant vanilla OFF
  install -m 755 "$ROOT/build/fixed/pvz-portable" "$ENGINE_OUT/pvz-portable"
  install -m 755 "$ROOT/build/vanilla/pvz-portable" "$ENGINE_OUT/pvz-portable-vanilla"
  HAS_VANILLA=true
  DO_FIX_BUGS=ON # the main binary is always the fixed one
else
  build_variant main "$DO_FIX_BUGS"
  install -m 755 "$ROOT/build/main/pvz-portable" "$ENGINE_OUT/pvz-portable"
fi

for bin in "$ENGINE_OUT"/pvz-portable*; do
  strip -x "$bin"
done

info "collecting dylibs into libs/"
dylibbundler_args=(-of -cd -b -d "$ENGINE_OUT/libs" -p '@executable_path/libs/')
for bin in "$ENGINE_OUT"/pvz-portable*; do
  dylibbundler_args+=(-x "$bin")
done
# </dev/null makes a missing library an error instead of an interactive prompt in CI
dylibbundler "${dylibbundler_args[@]}" </dev/null

# copies out of the nix store are read-only, and they still need signing below
chmod -R u+w "$ENGINE_OUT/libs"

# sdl2-compat reaches SDL3 through dlopen, which otool cannot see and dylibbundler therefore misses.
SDL3_SRC="$DEVENV_PROFILE/lib/libSDL3.dylib"
[[ -f "$SDL3_SRC" ]] || die "$SDL3_SRC missing — is sdl3 still in devenv.nix?"
install -m 755 "$SDL3_SRC" "$ENGINE_OUT/libs/libSDL3.dylib"
# It is dlopened by path, so its id does not affect loading, but rewriting it lets the leak check below treat every Mach-O alike.
install_name_tool -id '@executable_path/libs/libSDL3.dylib' "$ENGINE_OUT/libs/libSDL3.dylib"

# Not optional: rewriting an install_name invalidates the signature, and arm64 dyld refuses to load such a binary. -s - is ad-hoc and needs no certificate.
info "re-signing ad-hoc"
while IFS= read -r -d '' f; do
  codesign --force --sign - "$f" 2>/dev/null || die "failed to sign ${f#"$ENGINE_OUT"/}"
done < <(machos "$ENGINE_OUT")

info "verifying output"
no_leaked_paths "$ENGINE_OUT" || die "dylibs were not fully collected; this build would not run elsewhere"
[[ -f "$ENGINE_OUT/libs/libSDL3.dylib" ]] || die "libs/libSDL3.dylib is gone — sdl2-compat would fail to load"
otool -l "$ENGINE_OUT/pvz-portable" | grep -q '@executable_path/libs/' ||
  die "pvz-portable has no @executable_path/libs/ rpath"

MIN_MACOS="$(otool -l "$ENGINE_OUT/pvz-portable" | awk '/LC_BUILD_VERSION/{f=1} f && /^ *minos/{print $2; exit}')"

# The launcher reads this to decide whether -cheat is usable and whether to offer the engine picker.
cat >"$ENGINE_OUT/build-info.json" <<EOF
{
  "engineVersion": "$ENGINE_VERSION",
  "engineVersionFull": "$ENGINE_VERSION_FULL",
  "engineRef": "$UPSTREAM_REF",
  "engineCommit": "$ENGINE_COMMIT",
  "buildNumber": "$BUILD_NUMBER",
  "pvzDebug": $([[ "$PVZ_DEBUG" == ON ]] && echo true || echo false),
  "doFixBugs": $([[ "$DO_FIX_BUGS" == ON ]] && echo true || echo false),
  "hasVanilla": $HAS_VANILLA,
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "arch": "$(uname -m)",
  "minMacOS": "${MIN_MACOS:-unknown}"
}
EOF

info "done → ${ENGINE_OUT#"$ROOT"/}"
step "version     $ENGINE_VERSION_FULL"
step "PVZ_DEBUG   $PVZ_DEBUG"
step "DO_FIX_BUGS $DO_FIX_BUGS$([[ "$HAS_VANILLA" == true ]] && echo ' (+ vanilla binary)')"
step "dylibs      $(find "$ENGINE_OUT/libs" -name '*.dylib' | wc -l | tr -d ' ')"
step "min macOS   ${MIN_MACOS:-unknown}"
