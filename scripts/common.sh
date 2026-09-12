#!/usr/bin/env bash
# Sourced by the other scripts. Not meant to be run directly.

set -euo pipefail

APP_NAME="PvZ Portable"
UPSTREAM_URL="https://github.com/wszqkzqk/PvZ-Portable.git"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/out"
ENGINE_OUT="$OUT_DIR/engine"
APP_OUT="$OUT_DIR/$APP_NAME.app"
THIRD_PARTY="$ROOT/third_party"

# Only bounds our own code; the real floor comes from the toolchain and is reported by verify-app.sh.
PVZP_DEPLOYMENT_TARGET="${PVZP_DEPLOYMENT_TARGET:-13.0}"

if [[ -t 2 ]]; then
  _c_red=$'\033[31m' _c_yel=$'\033[33m' _c_grn=$'\033[32m' _c_dim=$'\033[2m' _c_off=$'\033[0m'
else
  _c_red='' _c_yel='' _c_grn='' _c_dim='' _c_off=''
fi

info() { printf '%s==>%s %s\n' "$_c_grn" "$_c_off" "$*" >&2; }
warn() { printf '%swarning:%s %s\n' "$_c_yel" "$_c_off" "$*" >&2; }
step() { printf '%s  %s%s\n' "$_c_dim" "$*" "$_c_off" >&2; }
die() {
  printf '%serror:%s %s\n' "$_c_red" "$_c_off" "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found. ${2:-}"
}

# Everything declared in devenv.nix lands in this profile; CMake finds SDL2, libpng, libogg and the rest through it.
require_devenv_profile() {
  [[ -n "${DEVENV_PROFILE:-}" ]] ||
    die "DEVENV_PROFILE is unset. Run inside the devenv shell:\n  devenv shell -- ${0##*/}\nor run direnv allow first."
}

is_macho() {
  [[ -f "$1" ]] && file -b "$1" 2>/dev/null | grep -q 'Mach-O'
}

machos() { # <root>
  local f
  while IFS= read -r -d '' f; do
    is_macho "$f" && printf '%s\0' "$f"
  done < <(find "$1" -type f -print0 2>/dev/null)
}

# The one real risk when bundling is leaving a dependency behind, which makes the package work here and nowhere else. Whitelist approach: outside system libraries and relative references, no absolute path is allowed, which catches /nix/store and build-directory leftovers alike.
no_leaked_paths() { # <root>
  local root="$1" f bad leaked=0
  while IFS= read -r -d '' f; do
    # otool indents dependencies with a tab and leaves its headers flush left, one per architecture
    bad="$(otool -L "$f" 2>/dev/null | grep $'^\t' | awk '{print $1}' |
      grep -vE '^(/usr/lib/|/System/Library/|@executable_path/|@loader_path/|@rpath/)' || true)"
    if [[ -n "$bad" ]]; then
      printf '  %s\n%s\n' "${f#"$root"/}" "$bad" >&2
      leaked=1
    fi
  done < <(machos "$root")

  return "$leaked"
}
