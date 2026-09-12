#!/usr/bin/env bash
#
# Builds the macOS AppIcon asset catalog from upstream's icon.png. The result is checked in, so a clean clone can build the app without cloning upstream first.
#
# That source image is only 512x512, so the 512@2x slot is upscaled.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SRC=""
# main rather than a pinned version: the icon rarely changes, and a hardcoded one would go stale the first time the update workflow bumps devenv.nix.
REF="${PVZP_UPSTREAM_REF:-main}"
while [[ $# -gt 0 ]]; do
  case "$1" in
  --source)
    SRC="${2:?--source needs a png}"
    shift 2
    ;;
  -h | --help)
    echo "usage: make-appicon.sh [--source <icon.png>]" >&2
    exit 0
    ;;
  *) die "unknown argument $1" ;;
  esac
done

need_cmd sips
need_cmd plutil

if [[ -z "$SRC" ]]; then
  if [[ -f "$THIRD_PARTY/PvZ-Portable/icon.png" ]]; then
    SRC="$THIRD_PARTY/PvZ-Portable/icon.png"
  else
    tmpdir="$(mktemp -d -t pvzp-icon)"
    trap 'rm -rf "$tmpdir"' EXIT
    SRC="$tmpdir/icon.png"
    info "no upstream checkout here, fetching icon.png from $REF"
    curl -fsSL "https://raw.githubusercontent.com/wszqkzqk/PvZ-Portable/$REF/icon.png" -o "$SRC" ||
      die "could not download icon.png"
  fi
fi
[[ -f "$SRC" ]] || die "$SRC not found"

SET="$ROOT/launcher/Assets.xcassets/AppIcon.appiconset"
rm -rf "$SET"
mkdir -p "$SET"

render() { # <filename> <pixels>
  sips -s format png -Z "$2" "$SRC" --out "$SET/$1" >/dev/null
}

info "generating icons from ${SRC##*/}"
entries=()
for size in 16 32 128 256 512; do
  for scale in 1 2; do
    suffix=""
    [[ "$scale" == 1 ]] || suffix="@2x"
    name="icon_${size}x${size}${suffix}.png"
    render "$name" "$((size * scale))"
    entries+=("    { \"idiom\" : \"mac\", \"size\" : \"${size}x${size}\", \"scale\" : \"${scale}x\", \"filename\" : \"$name\" }")
  done
done

{
  echo '{'
  echo '  "images" : ['
  printf '%s,\n' "${entries[@]}" | sed '$ s/,$//'
  echo '  ],'
  echo '  "info" : { "author" : "xcode", "version" : 1 }'
  echo '}'
} >"$SET/Contents.json"

cat >"$ROOT/launcher/Assets.xcassets/Contents.json" <<'EOF'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

# Not plutil -lint: it parses a leading `{` as an OpenStep plist and rejects all JSON. -convert takes the other path.
plutil -convert xml1 -o /dev/null "$SET/Contents.json" || die "generated Contents.json is invalid"
info "done → launcher/Assets.xcassets/AppIcon.appiconset"
