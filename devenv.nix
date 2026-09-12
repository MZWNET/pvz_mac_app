{
  lib,
  pkgs,
  ...
}: let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in {
  # The upstream-release check runs this same shell on a Linux runner, where none of the build tooling applies and several of these have no Linux build at all.
  packages = with pkgs;
    [
      alejandra
      nvchecker # for .github/workflows/update.yml
    ]
    ++ lib.optionals isDarwin [
      cmake
      ninja
      pkg-config
      macdylibbundler

      sdl2-compat
      sdl3
      libpng
      libjpeg_turbo
      libogg
      libvorbis
      libopenmpt
      mpg123
      zlib

      xcodegen
      create-dmg
      xcbeautify
      swift-format
      swiftlint
    ];

  env.PVZP_UPSTREAM_REF = "0.2.3";

  scripts.build-engine.exec = ''exec "$DEVENV_ROOT/scripts/build-engine.sh" "$@"'';
  scripts.build-app.exec = ''exec "$DEVENV_ROOT/scripts/build-app.sh" "$@"'';
  scripts.build-dmg.exec = ''exec "$DEVENV_ROOT/scripts/make-dmg.sh" "$@"'';
  scripts.make-appicon.exec = ''exec "$DEVENV_ROOT/scripts/make-appicon.sh" "$@"'';
  scripts.lint.exec = ''
    set -euo pipefail
    cd "$DEVENV_ROOT"
    swift-format lint --strict --recursive launcher
    swiftlint lint --quiet --strict
  '';

  enterTest = ''"$DEVENV_ROOT/scripts/verify-app.sh"'';
}
