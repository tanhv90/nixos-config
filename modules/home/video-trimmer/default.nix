{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.video-trimmer;
in
{
  options.${namespace}.video-trimmer = {
    enable = mkEnableOption "GNOME Video Trimmer";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      video-trimmer
    ];
  };
}
