# Nomad - Portable NixOS on external SSD
# Hardware-generic: boots on any x86_64 PC (no GPU-specific drivers)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disks.nix
    ./hardware-configuration.nix
  ];

  kbb.default-desktop.enable = true;

  modules = {
    fish.enable = true;

    # Window manager
    niri = {
      enable = true;
      greetd.enable = true;
      greetd.autoLogin.enable = false;
    };

    # Network
    stubby.enable = true;
    wifi.enable = false; # Enable after adding networks to wifi module

    sops.enable = true;

    # Impermanence - btrfs root rollback with persistent storage
    impermanence = {
      enable = true;
      users = [ "kbb" ];
    };
  };

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
          "ca-derivations"
        ];
        flake-registry = "";
        nix-path = config.nix.nixPath;
        trusted-users = [
          "root"
          "kbb"
        ];
        auto-optimise-store = true;
      };
      channel.enable = false;
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      gc = {
        automatic = false;
        dates = "weekly";
        options = "--delete-older-than 28d";
      };
    };

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot/efi";
    };
  };

  services = {
    # Monthly btrfs scrub to detect data corruption
    btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = [ "/" ];
    };

    xserver.videoDrivers = [ "modesetting" ];
  };

  services.xserver.xkb.layout = "us";
  services.libinput.enable = true;

  hardware = {
    acpilight.enable = true;
    bluetooth.enable = true;

    graphics = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    parted
    gptfdisk
    lm_sensors
    nix-tree
    ntfs3g
    compsize

    usbutils
    smartmontools
    pciutils
    libva
    libva-utils
  ];

  networking = {
    hostName = "Nomad";
    networkmanager.enable = false;
    firewall = {
      allowedTCPPorts = [ 22 ];
    };
  };

  services = {
    flatpak.enable = true;
    upower.enable = true;
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };

  system.stateVersion = "24.11";
}
