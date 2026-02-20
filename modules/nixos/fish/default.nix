{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.modules.fish;
in
{
  options = {
    modules.fish.enable = lib.mkEnableOption "fish shell";
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      fishPlugins.z
      fishPlugins.fzf-fish
      fishPlugins.puffer
      fishPlugins.done
    ];

    programs = {
      fish = {
        enable = true;
      };
    };
  };
}
