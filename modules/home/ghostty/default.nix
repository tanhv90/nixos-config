{
  lib,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.ghostty;
in
{
  options.${namespace}.ghostty = {
    enable = mkEnableOption "Ghostty";
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        # Colors
        background = "#391b0b";
        foreground = "#f3ecdf";
        selection-background = "#f3ecdf";
        selection-foreground = "#391b0b";
        cursor-color = "#f3ecdf";
        palette = [
          "0=#391b0b"
          "8=#aaa59c"
          "1=#E4A85F"
          "9=#E4A85F"
          "2=#F3AF71"
          "10=#F3AF71"
          "3=#BDA089"
          "11=#BDA089"
          "4=#EEB48A"
          "12=#EEB48A"
          "5=#F7CC92"
          "13=#F7CC92"
          "6=#F7D9AD"
          "14=#F7D9AD"
          "7=#f3ecdf"
          "15=#f3ecdf"
        ];

        # Fonts
        font-family = "JetBrainsMono Nerd Font";
        font-size = 10;

        # Cursor
        cursor-style = "block";

        # Scrollback
        scrollback-limit = 2000;

        # Mouse
        copy-on-select = "clipboard";
        app-notifications = "no-clipboard-copy";

        # Window layout
        window-padding-x = 12;
        window-padding-y = 12;
        window-decoration = false;

        # Background
        background-opacity = 0.90;

        # Misc
        confirm-close-surface = false;
        shell-integration = "none";

        # Keybindings
        keybind = "ctrl+shift+x=close_surface";
      };
    };

    xdg.mimeApps = {
      associations.added = {
        "x-scheme-handler/terminal" = "com.mitchellh.ghostty.desktop";
      };
      defaultApplications = {
        "x-scheme-handler/terminal" = "com.mitchellh.ghostty.desktop";
      };
    };
  };
}
