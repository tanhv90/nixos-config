{
  lib,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.fish;
in
{
  options.${namespace}.fish = {
    enable = mkEnableOption "Fish";
  };

  config = mkIf cfg.enable {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        # ----- Bat (better cat) -----
        set -x BAT_THEME tokyonight_night

        bind yy fish_clipboard_copy
        bind \cp fish_clipboard_paste

        alias cat "bat"

        fish_vi_key_bindings
      '';
      shellAbbrs = {
        # ----- git abbr -----
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gcm = "git commit -m";
        gp = "git push";
        gpl = "git pull";
        gco = "git checkout";
        gb = "git branch";
        gba = "git branch -a";
        gbd = "git branch -d";
        gbm = "git branch -m";
        gl = "git log";
        gll = "git log --oneline";
        gd = "git diff";
        gds = "git diff --staged";
        gdc = "git diff --cached";
        gcl = "git clone";
        gsw = "git switch";
        lg = "lazygit";

        # ----- ls abbr -----
        lsg = "ls | grep";
        llg = "ls -l | grep";
        lag = "ls -la | grep";

        sshref = "rm ~/.ssh/known_hosts";
      };
      shellAliases = {
        vim = "nvim";
        ssha = "ssh-add";
        sshconfig = "nvim ~/.ssh/config";
      };
    };
  };
}
