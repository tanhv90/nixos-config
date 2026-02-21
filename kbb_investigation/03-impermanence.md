# Impermanence: Ephemeral Root Filesystem

## The Problem

Over time, NixOS systems accumulate state in `/`, `/var`, `/etc`, `/home` — config files, caches, stale services, leftover packages. Even though NixOS is "declarative", the root filesystem collects drift. You can never be sure your system matches your config alone.

## The Concept

**Wipe `/` on every boot.** Only explicitly listed paths survive. If it's not in your config and not on the persist list, it's gone. This guarantees your system is *exactly* what your Nix config declares.

## Three Layers Working Together

### Layer 1: Disk Layout (disko) — Emberroot Example

`systems/x86_64-linux/Emberroot/disks.nix`

The btrfs partition has 4 subvolumes:

```
@root        -> /        (the root filesystem — gets wiped)
@nix         -> /nix     (the nix store — preserved, it's pure)
@persist     -> /persist (your explicitly saved state)
@root-blank  ->          (a snapshot of a clean root, for the wipe)
```

The wipe mechanism: on boot, `@root` is rolled back to the `@root-blank` snapshot — a pristine, empty root. Everything not mounted from another subvolume starts fresh.

### Layer 2: System Persistence — `modules/nixos/impermanence/default.nix`

Declares what system-level paths survive reboots:

```nix
environment.persistence."/persist/system" = {
  directories = [
    "/var/log"              # system logs
    "/var/lib/docker"       # docker data
    "/var/lib/nixos"        # nix daemon state
    "/var/lib/bluetooth"    # bluetooth pairings
    "/var/lib/NetworkManager"
    # ...
  ];
  files = [
    "/etc/machine-id"       # unique host ID
    "/etc/adjtime"          # hardware clock offset
  ];
};
```

These are bind-mounted from `/persist/system/var/log` -> `/var/log`, etc.

Special handling:
- **SSH host keys** (line 76-86): stored in `/persist/system/etc/ssh/` so host identity survives reboots
- **Home directories** (line 62-73): entire `/home/sinh` is bind-mounted from `/persist/home/sinh`

### Layer 3: Home Persistence (optional) — `modules/home/impermanence/default.nix`

A more selective approach — instead of persisting all of `/home`, list exactly which dotfiles survive:

```nix
home.persistence."/persist" = {
  directories = [
    ".ssh"                    # SSH keys
    ".config/sops/age"        # age private key
    ".mozilla/firefox"        # browser profile
    ".cargo"                  # rust toolchain
    "Documents"
    "git-repos"
    # ...
  ];
};
```

Currently **disabled** for Emberroot — it uses the simpler whole-home bind mount from Layer 2.

## The Wipe Script — `hardware-configuration.nix`

This is the initrd script that runs before NixOS mounts anything:

```bash
# 1. Mount the raw btrfs partition (no subvolume filter)
mkdir -p /mnt
mount -t btrfs -o subvol=/ /dev/disk/by-label/emberroot /mnt

# 2. If the blank snapshot exists...
if [[ -e /mnt/@root-blank ]]; then

  # 3. Delete any nested subvolumes inside @root
  btrfs subvolume list -o /mnt/@root |
    cut -f9 -d' ' |
    while read subvolume; do
      btrfs subvolume delete "/mnt/$subvolume"
    done

  # 4. Delete the entire @root subvolume
  btrfs subvolume delete /mnt/@root

  # 5. Create a fresh @root as a snapshot of @root-blank (which is empty)
  btrfs subvolume snapshot /mnt/@root-blank /mnt/@root
fi

umount /mnt
```

After this, `@root` is empty. NixOS's activation scripts populate `/` from `/nix/store`.

## Boot Timeline

```
Power on
  |
  v
UEFI loads systemd-boot from /boot/efi (ESP, untouched)
  |
  v
Kernel + initrd load into RAM
  |
  v
initrd runs postDeviceCommands:              <-- THE WIPE
  |  mount raw btrfs
  |  delete @root
  |  snapshot @root-blank -> @root           (root is now empty)
  |  unmount
  |
  v
NixOS mounts filesystems:
  |  @root    -> /          (empty)
  |  @nix     -> /nix       (all packages, configs, system closure)
  |  @persist -> /persist   (your saved state)
  |
  v
NixOS activation script runs:
  |  - Populates /etc, /run, /bin/sh from /nix/store
  |  - Creates symlinks
  |  - Starts systemd
  |
  v
impermanence bind-mounts kick in:
  |  /persist/system/var/log       -> /var/log
  |  /persist/system/var/lib/docker -> /var/lib/docker
  |  /persist/system/etc/ssh       -> (SSH host keys)
  |  /persist/home/sinh            -> /home/sinh
  |
  v
sops-nix decrypts secrets:
  |  reads /persist/system/sops/age/keys.txt
  |  decrypts secrets.yaml
  |  writes plaintext to /run/secrets/ (tmpfs, RAM only)
  |
  v
System is ready
```

## What Lives Where

| Path | Subvolume | Survives reboot? | Why |
|------|-----------|-----------------|-----|
| `/` | `@root` | No | Wiped and re-created from blank snapshot |
| `/nix` | `@nix` | Yes | Contains the Nix store — all packages, system config |
| `/persist` | `@persist` | Yes | Explicitly saved state |
| `/boot/efi` | ESP partition | Yes | Separate FAT32 partition entirely |
| `/home/sinh` | bind mount from `@persist` | Yes | impermanence module bind-mounts it |
| `/var/log` | bind mount from `@persist` | Yes | Listed in `environment.persistence` |
| `/run/secrets` | tmpfs (RAM) | No | Decrypted secrets, gone on power off |
| `/tmp` | tmpfs (RAM) | No | `boot.tmp.useTmpfs = true` |

## Why `/nix` Doesn't Need to Be in `/persist`

`/nix` has its own subvolume because it's **pure and reproducible**. Everything in `/nix/store` is derived from your flake — you can always rebuild it. But you don't want to rebuild it every boot, so it gets its own persistent subvolume. It's not "state" — it's deterministic build output.

## Initial Setup: Populating `/persist`

### Fresh Install (from NixOS installer)

```bash
# 1. Partition the disk with disko
nix run github:nix-community/disko -- --mode disko ./disks.nix

# 2. Subvolumes are now mounted:
#    @root -> /mnt, @nix -> /mnt/nix, @persist -> /mnt/persist

# 3. Create directory structure on /persist
mkdir -p /mnt/persist/system/sops/age
mkdir -p /mnt/persist/system/etc/ssh
mkdir -p /mnt/persist/system/var/log
mkdir -p /mnt/persist/system/var/lib/nixos
mkdir -p /mnt/persist/home/sinh

# 4. Copy age private key (from USB, scp, etc.)
cp /path/to/keys.txt /mnt/persist/system/sops/age/keys.txt
chmod 600 /mnt/persist/system/sops/age/keys.txt

# 5. Generate SSH host keys in persist location
ssh-keygen -t ed25519 -f /mnt/persist/system/etc/ssh/ssh_host_ed25519_key -N ""
ssh-keygen -t rsa -b 4096 -f /mnt/persist/system/etc/ssh/ssh_host_rsa_key -N ""

# 6. Install
nixos-install --flake .#Emberroot

# 7. Reboot — impermanence wipes @root, bind-mounts from /persist
```

### Migrating an Existing System

```bash
# Copy state while system is live:
sudo mkdir -p /persist/system/sops/age
sudo cp /home/sinh/.config/sops/age/keys.txt /persist/system/sops/age/keys.txt
sudo mkdir -p /persist/system/etc/ssh
sudo cp /etc/ssh/ssh_host_* /persist/system/etc/ssh/
sudo cp -a /var/lib/nixos /persist/system/var/lib/
sudo cp -a /var/log /persist/system/
sudo cp -a /home/sinh /persist/home/
sudo cp /etc/machine-id /persist/system/etc/machine-id

# Enable impermanence, add wipe script, rebuild, reboot
```

## The Discipline

If you forget to persist something, you find out on the next reboot when it's gone. That's the tradeoff impermanence enforces — but it guarantees your system is exactly what your Nix config declares.

## Benefits

| Benefit | Explanation |
|---|---|
| **Reproducibility** | If it's not in your Nix config or persist list, it doesn't exist |
| **No state drift** | No mystery files accumulating over months |
| **Forces discipline** | Hidden dependencies are surfaced |
| **Clean debugging** | "Works on a fresh boot" is every boot |
| **Security** | Temporary files and stale credentials vanish automatically |
