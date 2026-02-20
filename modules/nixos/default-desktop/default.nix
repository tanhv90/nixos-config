{
  lib,
  pkgs,
  inputs,
  namespace,
  config,
  ...
}:
with lib;
let
  cfg = config.${namespace}.default-desktop;
in
{
  options.${namespace}.default-desktop = {
    enable = mkEnableOption "Enable default desktop.";
  };

  config = mkIf cfg.enable {

    home-manager.useGlobalPkgs = true;
    home-manager.extraSpecialArgs = {
      inherit inputs;
    };

    # Increase open file limit for sudoers
    security.pam.loginLimits = [
      {
        domain = "@wheel";
        item = "nofile";
        type = "soft";
        value = "524288";
      }
      {
        domain = "@wheel";
        item = "nofile";
        type = "hard";
        value = "1048576";
      }
    ];

    networking.nameservers = mkDefault [
      "1.1.1.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    # UTC for a portable system used across timezones
    time.timeZone = "UTC";

    i18n.defaultLocale = "en_US.UTF-8";

    fonts.packages = with pkgs; [
      corefonts
      lato
      meslo-lgs-nf
      powerline-fonts
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.iosevka
      nerd-fonts.iosevka-term
      nerd-fonts.jetbrains-mono
    ];

    environment.systemPackages = with pkgs; [
      vim
      wget
      curl
      openssl
      kbb.sys
    ];

    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
