# Nomad: Portable Encrypted NixOS on External SSD

## The Idea

Carry an external SSD, plug it into **any** x86_64 PC, boot from it, and get a full NixOS desktop with all data encrypted. If someone steals the SSD, they can't read anything.

## Disk Layout: LUKS + LVM + btrfs

```
/dev/sda  (external SSD)
├── ESP (512MB, unencrypted)     <- bootloader must be readable
├── swap (16GB, unencrypted)
└── LUKS partition "nomad-crypt" <- everything below is encrypted
    └── LVM VG "nomad-vg"
        └── LV "nomad-lv"
            └── btrfs (label: "nomad")
                ├── @root        -> /         (wiped every boot)
                ├── @nix         -> /nix      (persistent)
                ├── @persist     -> /persist  (persistent)
                └── @root-blank  (empty snapshot)
```

### Three Layers Stacked

| Layer | Purpose |
|-------|---------|
| **LUKS** | Full-disk encryption. On boot, type a passphrase to unlock `nomad-crypt`. Without it, the entire partition is random noise. |
| **LVM** | Logical Volume Manager. Flexible abstraction over the encrypted block device. One VG (`nomad-vg`), one LV (`nomad-lv`). |
| **btrfs** | Subvolume layout — `@root` gets wiped, `@persist` and `@nix` survive. |

## How disko Declares This — `disks.nix`

The nesting is literal in the disko config:

```nix
# The partition
root = {
  size = "100%";
  content = {
    type = "luks";              # <- Layer 1: encrypt the partition
    name = "nomad-crypt";
    settings.allowDiscards = true;
    content = {
      type = "lvm_pv";          # <- Layer 2: make it an LVM physical volume
      vg = "nomad-vg";
    };
  };
};

# The LVM volume group
lvm_vg."nomad-vg" = {
  lvs."nomad-lv" = {
    size = "100%FREE";
    content = {
      type = "btrfs";           # <- Layer 3: btrfs inside the LV
      subvolumes = {
        "@root"       = { mountpoint = "/"; };
        "@nix"        = { mountpoint = "/nix"; };
        "@persist"    = { mountpoint = "/persist"; };
        "@root-blank" = { };     # empty snapshot
      };
    };
  };
};
```

## Boot Sequence

```
Power on, select external SSD in BIOS boot menu
  |
  v
UEFI loads systemd-boot from ESP (unencrypted, /dev/sda1)
  |
  v
Kernel + initrd load
  |
  v
initrd prompts: "Enter passphrase for nomad-crypt: ________"
  |  (LUKS decrypts /dev/sda3 -> /dev/mapper/nomad-crypt)
  |
  v
LVM activates: /dev/mapper/nomad-crypt -> /dev/nomad-vg/nomad-lv
  |
  v
initrd postDeviceCommands (the wipe):
  |  mount /dev/nomad-vg/nomad-lv -> /mnt     <- LVM device, not disk label
  |  delete @root
  |  snapshot @root-blank -> @root
  |  unmount
  |
  v
Normal NixOS boot
  |  mount subvolumes, bind-mount from /persist, decrypt sops secrets
  |
  v
System ready
```

## What Makes It "Hardware-Generic"

| Setting | Why |
|---|---|
| GPU driver: `modesetting` | Generic, works on any GPU (Intel, AMD, basic NVIDIA) |
| CPU: both `kvm-intel` + `kvm-amd` | Boots on any x86_64 processor |
| Impermanence | LUKS + btrfs wipe ensures clean state every boot |

## Why LUKS Matters for a Portable SSD

A portable SSD can be lost or stolen. Without LUKS:
- Plug the SSD into any Linux machine
- Mount the btrfs partition
- Read everything: `@persist` has the age private key, SSH keys, browser profiles, all of `/home`

With LUKS: without the passphrase, the partition is indistinguishable from random data.

Note: The ESP is unencrypted (bootloader only, no secrets). The swap is also unencrypted — a potential leak vector if sensitive data gets swapped to disk (tradeoff for simplicity).

## Why LVM Between LUKS and btrfs

You might wonder why not just LUKS -> btrfs directly. LVM adds flexibility:
- Could add more logical volumes later (e.g., shared data partition)
- Can resize volumes without repartitioning
- Standard convention for encrypted Linux installs

In practice for a single-LV setup like this, it adds minimal overhead. Mainly future-proofing and following the common LUKS+LVM pattern.
