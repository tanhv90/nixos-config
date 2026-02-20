{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.sops;
in
{
  imports = with inputs; [ sops-nix.nixosModules.sops ];

  options = {
    modules.sops.enable = lib.mkEnableOption "SOPs secret management";
  };

  config = lib.mkIf cfg.enable {
    sops = {
      defaultSopsFile = ../../../secrets/secrets.yaml;
      defaultSopsFormat = "yaml";

      # Use system-level path for impermanence compatibility (available during early boot)
      age.keyFile =
        if config.modules.impermanence.enable or false then
          "/persist/system/sops/age/keys.txt"
        else
          "/home/kbb/.config/sops/age/keys.txt";

      secrets = {
        # User password hash
        "users/kbb/hashedPassword" = {
          neededForUsers = true;
        };
      };
    };

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "sops" ''
        EDITOR=${config.environment.variables.EDITOR} ${pkgs.sops}/bin/sops $@
      '')
      age
    ];
  };
}
