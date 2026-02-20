{
  inputs,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  inherit (inputs) pre-commit-hooks-nix;
in
pre-commit-hooks-nix.lib.${pkgs.system}.run {
  src = ./.;
  hooks =
    let
      excludes = [
        "flake.lock"
      ];
      fail_fast = true;
      verbose = true;
    in
    {
      deadnix = {
        enable = true;

        settings = {
          edit = true;
        };
      };

      nixfmt = {
        enable = true;
        package = pkgs.nixfmt;
      };

      pre-commit-hook-ensure-sops.enable = true;

      statix.enable = true;
    };
}
