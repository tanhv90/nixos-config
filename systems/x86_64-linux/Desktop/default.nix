# Desktop - Stationary PC (i7-13700F, RTX 3060, 32GB DDR4)
# Traditional persistent root on internal NVMe, NVIDIA proprietary drivers
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    inputs.fcitx5-lotus.nixosModules.fcitx5-lotus
  ];

  kbb.default-desktop.enable = true;

  modules = {
    fish.enable = true;

    # Network
    stubby.enable = true;
    wifi.enable = false;

    sops.enable = true;

    fcitx5.enable = true;
  };

  # Timezone
  time.timeZone = lib.mkForce "Asia/Ho_Chi_Minh";

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
      efi.efiSysMountPoint = "/boot";
    };
  };

  # NVIDIA proprietary drivers
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    bluetooth.enable = true;

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
    };
  };

  services.xserver.xkb.layout = "us";
  services.libinput.enable = true;

  environment.systemPackages = with pkgs; [
    parted
    gptfdisk
    lm_sensors
    nix-tree
    ntfs3g

    usbutils
    smartmontools
    pciutils
    libva
    libva-utils

    nvtopPackages.nvidia

    firefox
    _1password-gui
    vscode
    lazydocker
    cloudflared
  ];

  networking = {
    hostName = "Desktop";
    networkmanager.enable = true;
    firewall = {
      allowedTCPPorts = [ 22 ];
    };
  };

  services = {
    flatpak.enable = true;
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
