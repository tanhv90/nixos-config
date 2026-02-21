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

    # Network
    stubby.enable = true;
    wifi.enable = false;

    sops.enable = true;

    # Impermanence - btrfs root rollback with persistent storage
    impermanence = {
      enable = true;
      users = [ "kbb" ];
    };
  };

  # KDE Plasma
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # Tailscale
  services.tailscale.enable = true;

  # Cloudflared
  services.cloudflared.enable = true;

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

    firefox
    _1password-gui
    vscode
    lazydocker
    cloudflared
  ];

  networking = {
    hostName = "Nomad";
    networkmanager.enable = true;
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
