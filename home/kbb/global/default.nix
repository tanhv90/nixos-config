# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  nix = {
    package = lib.mkDefault pkgs.nix;
  };

  systemd.user.startServices = "sd-switch";

  home = {
    username = "kbb";
    homeDirectory = "/home/kbb";
  };

  fonts.fontconfig = {
    enable = true;
  };

  programs = {
    home-manager.enable = true;
    git.enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
