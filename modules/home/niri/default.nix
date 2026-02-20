{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.niri;
in
{
  options.${namespace}.niri = {
    enable = mkEnableOption "Niri config using hm";

    monitors = {
      primary = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Primary monitor name (e.g., eDP-1). Auto-detected if null.";
        example = "eDP-1";
      };
    };
  };

  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        jq
        socat
        inotify-tools
        wl-clipboard
        libnotify
        hyprpicker
      ];

      file = {
        ".config/niri/config.kdl".source = ./niri_config/config.kdl;
        ".config/niri/scripts" = {
          source = ./niri_config/scripts;
          recursive = true;
        };
        ".config/mako" = {
          source = ./niri_config/mako;
          recursive = true;
        };
        ".config/niri/rofi" = {
          source = ./niri_config/rofi;
          recursive = true;
        };
        ".config/niri/theme" = {
          source = ./niri_config/theme;
          recursive = true;
        };
        ".config/niri/wallpapers" = {
          source = ./niri_config/wallpapers;
          recursive = true;
        };
        ".config/waybar" = {
          source = ./niri_config/waybar;
          recursive = true;
        };
      };
    };

    # Screenshot watcher service - copies both image + path to clipboard
    systemd.user.services.screenshot-watcher = {
      Unit = {
        Description = "Watch for new screenshots and copy to clipboard";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "screenshot-watcher" ''
          WATCH_DIR="$HOME/Pictures/Screenshots"
          ICON_DIR="$HOME/.config/mako/icons"

          mkdir -p "$WATCH_DIR"

          ${pkgs.inotify-tools}/bin/inotifywait -m -e close_write --format '%w%f' "$WATCH_DIR" | while read -r filepath; do
            [[ "$filepath" != *.png ]] && continue
            sleep 0.2
            [[ ! -s "$filepath" ]] && continue

            # Copy path to clipboard (clipboard manager saves this)
            echo -n "$filepath" | ${pkgs.wl-clipboard}/bin/wl-copy
            sleep 0.1
            # Copy image to clipboard (becomes active item)
            ${pkgs.wl-clipboard}/bin/wl-copy < "$filepath"

            ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:screenshot \
              -u low -i "''${ICON_DIR}/picture.png" \
              "Screenshot Saved" \
              "Clipboard: image + path"
          done
        ''}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
