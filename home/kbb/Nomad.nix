# Nomad home config - portable NixOS on external SSD
{ pkgs, ... }:
{
  imports = [ ./global ];

  home = {
    packages = with pkgs; [
      light
      acpilight
      sct
      sound-theme-freedesktop
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };

    sessionPath = [
      "$HOME/.cargo/bin"
    ];
  };

  kbb = {
    ghostty.enable = true;
    fish.enable = true;
    starship.enable = true;
    zellij.enable = true;
    neovim.enable = true;
    niri = {
      enable = true;
    };
  };
}
