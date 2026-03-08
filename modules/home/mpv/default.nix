{
  lib,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.mpv;
in
{
  options.${namespace}.mpv = {
    enable = mkEnableOption "mpv media player";
  };

  config = mkIf cfg.enable {
    programs.mpv = {
      enable = true;
    };
  };
}
