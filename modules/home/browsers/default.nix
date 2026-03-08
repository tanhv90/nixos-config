{
  lib,
  config,
  pkgs,
  inputs,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.browsers;
in
{
  options.${namespace}.browsers = {
    enable = mkEnableOption "Web browsers (Edge, Chrome, Zen)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.microsoft-edge
      pkgs.google-chrome
      inputs.zen-browser.packages.${pkgs.system}.default
    ];
  };
}
