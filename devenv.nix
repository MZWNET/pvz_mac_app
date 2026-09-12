{
  lib,
  pkgs,
  ...
}: let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in {
  # Declares the clang and Apple SDK the engine is compiled with, which CMake would otherwise just pick up off PATH by accident. Brings cmake along with it.
  languages.cplusplus = {
    enable = isDarwin;
    # the only C++ here is upstream's clone under third_party, which we never edit
    lsp.enable = false;
  };

  # The upstream-release check runs this same shell on a Linux runner, where none of the build tooling applies and several of these have no Linux build at all.
  packages = with pkgs;
    [
      alejandra
      nvchecker # for .github/workflows/update.yml
    ]
    ++ lib.optionals isDarwin [
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

  # Not lower than 13.3: the engine formats floating point through std::format, which calls std::to_chars, and Apple's libc++ marks that unavailable before 13.3. build-engine.sh passes it to CMake, project.yml reads it through XcodeGen's ${...} substitution.
  env.PVZP_DEPLOYMENT_TARGET = "13.3";

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
