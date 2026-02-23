{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.fcitx5;
in
{
  options.modules.fcitx5 = {
    enable = lib.mkEnableOption "fcitx5 input method with Vietnamese (Lotus)";
  };

  config = lib.mkIf cfg.enable {
    # Enable fcitx5 input method framework
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          kdePackages.fcitx5-qt
        ];
      };
    };

    # fcitx5-lotus service (provides fcitx5 + Vietnamese Lotus engine)
    services.fcitx5-lotus = {
      enable = true;
      user = "kbb";
    };
  };
}
