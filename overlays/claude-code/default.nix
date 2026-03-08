# Overlay to get latest Claude Code version
# The npm tarball bundles all deps, so we build from scratch instead of
# fighting buildNpmPackage's npmConfigHook lockfile validation.
{ lib, ... }:
_final: prev:
let
  version = "2.1.71";
in
{
  claude-code = prev.stdenv.mkDerivation {
    pname = "claude-code";
    inherit version;

    src = prev.fetchurl {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-b8sMU9ptGv9lKlU4PN4NA/C//ANvSR/QBSluBqJu99E=";
    };

    nativeBuildInputs = [ prev.makeWrapper ];

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/@anthropic-ai/claude-code
      cp -r . $out/lib/node_modules/@anthropic-ai/claude-code

      mkdir -p $out/bin
      makeWrapper ${prev.nodejs}/bin/node $out/bin/claude \
        --add-flags "$out/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
        --set DISABLE_AUTOUPDATER 1 \
        --set DISABLE_INSTALLATION_CHECKS 1 \
        --unset DEV \
        --prefix PATH : ${
          lib.makeBinPath (
            with prev;
            [
              procps
              bubblewrap
              socat
            ]
          )
        }

      runHook postInstall
    '';

    meta = with lib; {
      description = "CLI for Claude AI assistant";
      homepage = "https://github.com/anthropics/claude-code";
      license = licenses.unfree;
      mainProgram = "claude";
    };
  };
}
