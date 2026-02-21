{
  config,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.modules.impermanence;
in
{
  # Import the impermanence module at the top level (outside config)
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.modules.impermanence = {
    enable = mkEnableOption "impermanence with tmpfs root";

    persistPath = mkOption {
      type = types.str;
      default = "/persist";
      description = "Base path for persistent storage";
    };

    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Users whose entire home directories should be persisted";
    };
  };

  config = mkIf cfg.enable {
    # System-level persistence
    environment.persistence."${cfg.persistPath}/system" = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/docker"
        "/var/lib/flatpak"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/NetworkManager"
        "/etc/NetworkManager/system-connections"
        "/var/lib/libvirt"
        "/var/lib/cups"
        "/var/lib/tailscale"
        "/var/lib/sddm"
      ];
      files = [
        "/etc/machine-id"
        "/etc/adjtime"
      ];
    };

    # Ensure /persist is mounted early and bind mount home directories
    fileSystems = {
      "${cfg.persistPath}".neededForBoot = true;
    }
    // builtins.listToAttrs (
      map (user: {
        name = "/home/${user}";
        value = {
          device = "${cfg.persistPath}/home/${user}";
          fsType = "none";
          options = [ "bind" ];
          depends = [ cfg.persistPath ];
        };
      }) cfg.users
    );

    # SSH host keys persistence
    services.openssh.hostKeys = [
      {
        path = "${cfg.persistPath}/system/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "${cfg.persistPath}/system/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];

    # Ensure critical directories exist
    systemd.tmpfiles.rules = [
      "d ${cfg.persistPath}/system 0755 root root -"
      "d ${cfg.persistPath}/system/var/log 0755 root root -"
      "d ${cfg.persistPath}/system/var/lib 0755 root root -"
      "d ${cfg.persistPath}/system/etc/ssh 0755 root root -"
      "d ${cfg.persistPath}/system/sops/age 0700 root root -"
      "d ${cfg.persistPath}/home 0755 root root -"
    ]
    ++ (map (user: "d ${cfg.persistPath}/home/${user} 0700 ${user} users -") cfg.users);

    # Use tmpfs for /tmp
    boot.tmp.useTmpfs = true;
  };
}
