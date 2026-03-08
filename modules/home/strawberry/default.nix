{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.strawberry;
in
{
  options.${namespace}.strawberry = {
    enable = mkEnableOption "Strawberry music player";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      strawberry
    ];
  };
}
