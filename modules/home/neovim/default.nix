{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.neovim;
in
{
  options.${namespace}.neovim = {
    enable = mkEnableOption "Neovim";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nixvim

      # Dev tools / LSPs
      nil
      nixfmt
      lua-language-server
      ripgrep
      fd
      tree-sitter
    ];
  };
}
