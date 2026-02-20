{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.zellij;
in
{
  options.${namespace}.zellij = {
    enable = mkEnableOption "Zellij";
  };

  config = mkIf cfg.enable {
    xdg.configFile = {
      "zellij/config.kdl".source = ./config.kdl;
    };

    programs.zellij = {
      enable = true;
      enableFishIntegration = false;
      enableZshIntegration = false;
    };
  };
}
