{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.onlyoffice;
in
{
  options.${namespace}.onlyoffice = {
    enable = mkEnableOption "OnlyOffice";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      onlyoffice-desktopeditors
    ];
  };
}
