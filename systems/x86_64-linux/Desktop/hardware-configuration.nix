# Hardware configuration for Desktop - stationary PC
# Intel i7-13700F, NVIDIA RTX 3060, ASUS TUF B660M, 32GB DDR4
#
# Partition layout on /dev/nvme0n1:
#   /dev/nvme0n1p1  512MB   ESP   -> /boot
#   /dev/nvme0n1p2  32GB    swap
#   /dev/nvme0n1p3  rest    btrfs -> /  (subvols: @, @home)
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  # Filesystems and swap are managed by disko (see disks.nix)

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
}
