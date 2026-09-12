# PvZ Portable for macOS

Packages [wszqkzqk/PvZ-Portable](https://github.com/wszqkzqk/PvZ-Portable) as a `.app` you can double-click, with a launcher that supplies what double-clicking can't: `-resdir` for assets kept outside the bundle, the engine's runtime flags as checkboxes, and an importer for your own game assets. It also rebuilds the engine with `PVZ_DEBUG` and `DO_FIX_BUGS` on, which the official releases ship disabled.

> Like upstream, this repo contains **no PopCap / EA game assets**. You supply `main.pak` and `properties/` from your own copy of Plants vs. Zombies: GOTY Edition; the launcher imports a folder or a zip on first run. UI is English and Simplified Chinese.

## Install

Grab a DMG from [Releases](../../releases), drag it to Applications, then run this once — the build is not signed or notarized, so Gatekeeper blocks it otherwise:

```sh
xattr -dr com.apple.quarantine "/Applications/PvZ Portable.app"
```

## Build

Every tool is in `devenv.nix`; the engine is compiled with the clang and Apple SDK that come with it. Xcode is needed on top of that for the launcher, which xcodebuild builds with Xcode's own Swift toolchain.

```sh
direnv allow                # or prefix each command with `devenv shell --`

build-engine                # cmake + ninja, collect dylibs  → out/engine/
build-app                   # xcodegen + xcodebuild          → out/PvZ Portable.app
build-dmg                   # package                        → out/*.dmg
```

`devenv test` runs `scripts/verify-app.sh`, which statically checks the assembled bundle. `lint` runs swift-format and swiftlint over `launcher/`. `make-appicon` regenerates the (checked-in) icon catalog.

`build-engine` takes `--ref <tag|branch>`, `--src <checkout>`, `--no-cheat`, `--no-fix-bugs`, `--clean`, and `--variants both`. The last one builds two binaries the launcher can switch between, because `DO_FIX_BUGS` has no runtime switch and plenty of players consider the original bugs to be features.

## Notes

- The engine and `libs/` live in `Contents/MacOS/` because upstream's rpath is already `@executable_path/libs/`. The launcher `execv`s the engine over itself, so the PID is unchanged, the Dock icon doesn't bounce twice, and it can drop the argv LaunchServices handed it — the engine exits on any argument it doesn't recognise.
- Assets go to `~/Library/Application Support/io.github.wszqkzqk/PvZPortable/`, not into the bundle, so the `.app` stays replaceable and its signature intact.
- arm64 only, not sandboxed, macOS 13.3 or newer. That floor is set by `std::to_chars`, which the engine reaches through `std::format` and Apple's libc++ marks unavailable before 13.3; `verify-app.sh` prints the engine's actual `minos`.

## Licence

LGPL-3.0-or-later
