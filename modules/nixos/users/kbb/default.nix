{ config, pkgs, ... }:
{
  programs.fish.enable = true;

  users = {
    mutableUsers = true;

    users.kbb = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "network"
        "power"
        "video"
        "audio"
        "tty"
        "docker"
        "dialout"
        "networkmanager"
      ];

      shell = pkgs.fish;

      # Use SOPS-managed password hash when available
      hashedPasswordFile =
        if config.sops.secrets ? "users/kbb/hashedPassword" then
          config.sops.secrets."users/kbb/hashedPassword".path
        else
          null;

      packages = [ pkgs.home-manager ];
    };
  };

  home-manager.users.kbb = import ../../../../home/kbb/${config.networking.hostName}.nix;

  security.pam.services = {
    swaylock = { };
  };
}
