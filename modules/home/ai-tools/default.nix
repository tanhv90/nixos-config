{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.ai-tools;
in
{
  options.${namespace}.ai-tools = {
    enable = mkEnableOption "AI tools (Claude Code, OpenCode)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      claude-code
      opencode
    ];
  };
}
