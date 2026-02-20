{
  disko.devices = {
    disk.sda = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot/efi";
              mountOptions = [
                "fmask=0022"
                "dmask=0022"
              ];
            };
          };
          swap = {
            priority = 2;
            size = "8G";
            content = {
              type = "swap";
              resumeDevice = false;
            };
          };
          root = {
            priority = 3;
            size = "100%";
            content = {
              type = "luks";
              name = "nomad-crypt";
              settings = {
                allowDiscards = true;
              };
              content = {
                type = "lvm_pv";
                vg = "nomad-vg";
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      "nomad-vg" = {
        type = "lvm_vg";
        lvs = {
          "nomad-lv" = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = [
                "-f"
                "--label"
                "nomad"
              ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "subvol=@root"
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "subvol=@nix"
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "subvol=@persist"
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@root-blank" = { };
              };
            };
          };
        };
      };
    };
  };
}
