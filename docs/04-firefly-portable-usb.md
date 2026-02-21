# FireFly: Portable Encrypted NixOS on USB

## The Idea

Carry a 128GB USB drive, plug it into **any** x86_64 PC, boot from it, and get a full NixOS desktop with all data encrypted. If someone steals the USB, they can't read anything.

## Disk Layout: LUKS + LVM + btrfs

### Compared to Emberroot (plain btrfs)

**Emberroot:**
```
/dev/sda
├── ESP (512MB)
├── btrfs partition -> @root, @nix, @persist, @root-blank
└── swap (32GB)
```

**FireFly:**
```
/dev/sda  (128GB USB)
├── ESP (512MB, unencrypted)     <- bootloader must be readable
├── swap (8GB, unencrypted)
└── LUKS partition "mobi-crypt"  <- everything below is encrypted
    └── LVM VG "mobi-vg"
        └── LV "mobi-lv"
            └── btrfs (label: "mobi")
                ├── @root        -> /         (wiped every boot)
                ├── @nix         -> /nix      (persistent)
                ├── @persist     -> /persist  (persistent)
                └── @root-blank  (empty snapshot)
```

### Three Layers Stacked

| Layer | Purpose |
|-------|---------|
| **LUKS** | Full-disk encryption. On boot, type a passphrase to unlock `mobi-crypt`. Without it, the entire partition is random noise. |
| **LVM** | Logical Volume Manager. Flexible abstraction over the encrypted block device. One VG (`mobi-vg`), one LV (`mobi-lv`). |
| **btrfs** | Same subvolume layout as Emberroot — `@root` gets wiped, `@persist` and `@nix` survive. |

## How disko Declares This — `disks.nix`

The nesting is literal in the disko config:

```nix
# The partition
root = {
  size = "100%";
  content = {
    type = "luks";              # <- Layer 1: encrypt the partition
    name = "mobi-crypt";
    settings.allowDiscards = true;
    content = {
      type = "lvm_pv";          # <- Layer 2: make it an LVM physical volume
      vg = "mobi-vg";
    };
  };
};

# The LVM volume group
lvm_vg."mobi-vg" = {
  lvs."mobi-lv" = {
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

The key difference from Emberroot: LUKS decryption happens before the wipe.

```
Power on, select USB in BIOS boot menu
  |
  v
UEFI loads systemd-boot from ESP (unencrypted, /dev/sda1)
  |
  v
Kernel + initrd load
  |
  v
initrd prompts: "Enter passphrase for mobi-crypt: ________"
  |  (LUKS decrypts /dev/sda3 -> /dev/mapper/mobi-crypt)
  |
  v
LVM activates: /dev/mapper/mobi-crypt -> /dev/mobi-vg/mobi-lv
  |
  v
initrd postDeviceCommands (the wipe):
  |  mount /dev/mobi-vg/mobi-lv -> /mnt     <- LVM device, not disk label
  |  delete @root
  |  snapshot @root-blank -> @root
  |  unmount
  |
  v
Normal NixOS boot (same as Emberroot from here)
  |  mount subvolumes, bind-mount from /persist, decrypt sops secrets
  |
  v
System ready
```

### The Mount Difference

Emberroot mounts btrfs from a partition label:
```bash
mount -t btrfs -o subvol=/ /dev/disk/by-label/emberroot /mnt
```

FireFly mounts from the LVM device (only exists after LUKS unlock):
```bash
mount -t btrfs -o subvol=/ /dev/mobi-vg/mobi-lv /mnt
```

## What Makes It "Hardware-Generic"

| | Emberroot | FireFly |
|---|---|---|
| GPU driver | `nvidia` (specific) | `modesetting` (generic, works on any GPU) |
| CPU microcode | Intel only | Both Intel and AMD (`kvm-intel` + `kvm-amd`) |
| `greetd.autoLogin` | `true` | `false` (need login — shared machines) |
| Docker | enabled | disabled (save space on 128GB) |
| VSCode, Flutter, etc. | enabled | disabled (lighter footprint) |
| NVIDIA packages | yes | none |

The `modesetting` video driver is the kernel's built-in generic driver — it works with Intel, AMD, and even basic NVIDIA without proprietary drivers.

## Why LUKS Matters for a USB

A portable USB can be lost or stolen. Without LUKS:
- Plug the USB into any Linux machine
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

## Home Config Differences

`home/sinh/FireFly.nix` is based on Emberroot but lighter:
- `office.enable = false` — no LibreOffice suite
- `coding.editor.vscode.enable = false` — no VSCode
- `coding.docker.enable = false` — no Docker
- `coding.super-productivity.enable = false`
- `coding.devbox.enable = false`
- `coding.flutter.enable = false`
- `multimedia.tools.kdenlive.enable = false` — no video editing

Core tools kept: Neovim, Ghostty, Zellij, Claude Code, browsers, chat apps.
