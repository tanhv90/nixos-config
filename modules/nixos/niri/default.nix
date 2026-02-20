{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.modules.niri;
in
{
  options.modules.niri = {
    enable = lib.mkEnableOption "niri";

    greetd = {
      enable = lib.mkEnableOption "greetd display manager with niri";

      autoLogin = {
        enable = lib.mkEnableOption "auto-login without greeter";

        user = lib.mkOption {
          type = lib.types.str;
          default = "kbb";
          description = "User to auto-login as";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
      package = pkgs.niri;
    };

    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "niri";
    };

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config.common.default = "*";
    };

    # Audio support
    security.rtkit.enable = true;
    services = {
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
      # File manager services
      gvfs.enable = true;
      tumbler.enable = true;
    };

    # Polkit for authentication
    security.polkit.enable = true;
    systemd = {
      user.services.polkit-gnome-authentication-agent-1 = {
        description = "polkit-gnome-authentication-agent-1";
        wantedBy = [ "graphical-session.target" ];
        wants = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
      };
    };

    environment.systemPackages = with pkgs; [
      # XWayland support
      xwayland-satellite

      # Wayland utilities
      swaybg
      swww
      wl-clipboard
      wl-clip-persist
      cliphist
      wlr-randr

      # Screenshot & screen recording
      grim
      slurp
      wf-recorder

      # Notifications
      mako
      libnotify

      # Status bar
      waybar

      # Launchers
      rofi
      fuzzel

      # System utilities
      brightnessctl
      playerctl
      pamixer
      pulsemixer
      pavucontrol
      socat
      swaylock

      # File management
      thunar
      tumbler

      # System monitor
      btop

      # Key press overlay for screencasts
      showmethekey

      # Network & Bluetooth
      blueman

      # Image viewers
      viewnior

      # Qt Wayland support
      qt5.qtwayland
    ];

    # Enable dconf for GTK apps
    programs.dconf.enable = true;

    # Font configuration
    fonts = {
      packages = with pkgs; [
        noto-fonts
        noto-fonts-color-emoji
        font-awesome
      ];
      fontconfig = {
        enable = true;
        defaultFonts = {
          serif = [ "Noto Serif" ];
          sansSerif = [ "Noto Sans" ];
          monospace = [ "JetBrainsMono Nerd Font" ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };

    # Location service
    location.provider = "geoclue2";
    services.geoclue2.enable = true;

    # greetd display manager
    services.greetd = lib.mkIf cfg.greetd.enable {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --user-menu --sessions ${pkgs.niri}/share/wayland-sessions";
          user = "greeter";
        };
      }
      // lib.optionalAttrs cfg.greetd.autoLogin.enable {
        initial_session = {
          command = "${pkgs.niri}/bin/niri-session";
          inherit (cfg.greetd.autoLogin) user;
        };
      };
    };
  };
}
