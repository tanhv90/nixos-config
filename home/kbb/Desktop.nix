# Desktop home config - stationary PC
{ pkgs, ... }:
{
  imports = [ ./global ];

  home = {
    packages = with pkgs; [
      sound-theme-freedesktop
      telegram-desktop
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
    onlyoffice.enable = true;
    ai-tools.enable = true;
  };
}
