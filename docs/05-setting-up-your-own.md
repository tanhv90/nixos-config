# Setting Up a Similar Configuration

Step-by-step guide to creating a Snowfall Lib NixOS config.

## 1. Initialize the Flake

```bash
mkdir ~/nixos-config && cd ~/nixos-config
git init
```

Create `flake.nix`:

```nix
{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;
        snowfall = {
          meta.name = "my-config";
          meta.title = "My NixOS Config";
          namespace = "my";  # your option prefix: my.apps.foo.enable
        };
      };
    in
    lib.mkFlake {
      inherit inputs;
      src = ./.;
      channels-config.allowUnfree = true;
    };
}
```

The `namespace` becomes the prefix for all home module options.

## 2. Create the Directory Skeleton

```
mkdir -p systems/x86_64-linux/<your-hostname>
mkdir -p home/<your-username>/global
mkdir -p modules/nixos
mkdir -p modules/home
mkdir -p lib/module
mkdir -p overlays
mkdir -p packages
```

Snowfall discovers everything by directory name — no manual imports needed.

## 3. System Config

`systems/x86_64-linux/<hostname>/default.nix`:

```nix
{ inputs, lib, config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Enable your modules (from modules/nixos/)
  modules = {
    # docker.enable = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "<hostname>";
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.<your-username> = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" ];
  };

  # Wire home-manager to the right per-host file
  home-manager.useGlobalPkgs = true;
  home-manager.extraSpecialArgs = { inherit inputs; };
  home-manager.users.<your-username> =
    import ../../../home/<your-username>/${config.networking.hostName}.nix;

  system.stateVersion = "24.11";
}
```

Copy your existing `hardware-configuration.nix` into the same directory:
```bash
nixos-generate-config --show-hardware-config > systems/x86_64-linux/<hostname>/hardware-configuration.nix
```

## 4. Home Config

**`home/<username>/global/default.nix`** — shared across all hosts:

```nix
{ lib, pkgs, ... }:
{
  home.username = "<your-username>";
  home.homeDirectory = "/home/<your-username>";

  programs.home-manager.enable = true;
  programs.git.enable = true;

  home.stateVersion = "24.05";
}
```

**`home/<username>/<hostname>.nix`** — per-host toggles:

```nix
{ pkgs, ... }:
{
  imports = [ ./global ];

  home.packages = with pkgs; [ firefox ];

  my = {
    # ghostty.enable = true;
    # neovim.enable = true;
  };
}
```

## 5. Create Your First Home Module

`modules/home/ghostty/default.nix`:

```nix
{ lib, config, namespace, ... }:
with lib;
let
  cfg = config.${namespace}.ghostty;
in
{
  options.${namespace}.ghostty = {
    enable = mkEnableOption "Ghostty terminal";
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      settings = {
        font-size = 12;
      };
    };
  };
}
```

The pattern:
1. `cfg = config.${namespace}.module-name` — reference
2. `options.${namespace}.module-name` — declare the enable option
3. `config = mkIf cfg.enable { ... }` — only apply when enabled

`namespace` is a special argument Snowfall passes to every module.

## 6. Create Your First NixOS Module

`modules/nixos/docker/default.nix`:

```nix
{ lib, config, ... }:
with lib;
let
  cfg = config.modules.docker;
in
{
  options.modules.docker = {
    enable = mkEnableOption "Docker";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
  };
}
```

NixOS modules use `modules.*` as the namespace (convention, not enforced by Snowfall).

## 7. Optional Helper Lib

`lib/module/default.nix`:

```nix
{ lib, ... }:
with lib;
rec {
  mkOpt = type: default: description:
    mkOption { inherit type default description; };
  mkBoolOpt = mkOpt types.bool;
  enabled = { enable = true; };
  disabled = { enable = false; };
}
```

Available as `lib.my.enabled`, `lib.my.mkBoolOpt`, etc.

## 8. Build It

```bash
# Test (ephemeral)
sudo nixos-rebuild test --flake .#<hostname>

# Apply permanently
sudo nixos-rebuild switch --flake .#<hostname>
```

## Adding a Second Host

1. Create `systems/x86_64-linux/<new-host>/default.nix` + `hardware-configuration.nix`
2. Create `home/<username>/<new-host>.nix`
3. Toggle different options per host

No duplication — both hosts share the same module definitions.

---

## Nomad: Build & Install on External SSD (from Arch Linux)

This section covers installing the **Nomad** host to an external SSD from an Arch Linux machine.

### Prerequisites

- Arch Linux with Nix installed (multi-user)
- External SSD connected (appears as `/dev/sda`)
- On Arch, `sudo` can't find nix — always use: `sudo $(which nix) --extra-experimental-features "nix-command flakes" ...`

### Step 1: Setup Secrets

```bash
cd ~/nixos-config

# Generate age encryption key
nix shell nixpkgs#age -c age-keygen -o /tmp/age-keys.txt
# Copy the public key (age1...) and put it in .sops.yaml

# Generate login password hash
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512

# Create encrypted secrets file
rm -f secrets/secrets.yaml
SOPS_AGE_KEY_FILE=/tmp/age-keys.txt nix run nixpkgs#sops -- secrets/secrets.yaml
# Add in editor:
#   users:
#     kbb:
#       hashedPassword: "$6$..."
```

### Step 2: Verify Build

```bash
cd ~/nixos-config && git add -A
nix build .#nixosConfigurations.Nomad.config.system.build.toplevel
```

### Step 3: Identify & Partition Disk

```bash
# Confirm /dev/sda is your external SSD
lsblk -o NAME,SIZE,MODEL,TRAN

# Partition (DESTROYS ALL DATA on /dev/sda)
cp systems/x86_64-linux/Nomad/disks.nix /tmp/disks.nix
sudo $(which nix) --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- --mode disko /tmp/disks.nix
# You'll set a LUKS passphrase — choose something strong, typed every boot
```

### Step 4: Populate Persistent Storage

```bash
# Age key for sops
sudo mkdir -p /mnt/persist/system/sops/age
sudo cp /tmp/age-keys.txt /mnt/persist/system/sops/age/keys.txt
sudo chmod 600 /mnt/persist/system/sops/age/keys.txt

# SSH host keys
sudo mkdir -p /mnt/persist/system/etc/ssh
sudo ssh-keygen -t ed25519 -f /mnt/persist/system/etc/ssh/ssh_host_ed25519_key -N ""
sudo ssh-keygen -t rsa -b 4096 -f /mnt/persist/system/etc/ssh/ssh_host_rsa_key -N ""

# Home directory
sudo mkdir -p /mnt/persist/home/kbb
sudo chown -R 1000:100 /mnt/persist/home/kbb
```

### Step 5: Install

```bash
sudo PATH="$PATH" $(which nix) --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#nixos-install-tools -c nixos-install \
  --flake /home/kbb/nixos-config#Nomad --root /mnt
```

### Step 6: Copy Config & Reboot

```bash
sudo cp -r /home/kbb/nixos-config/. /mnt/persist/home/kbb/nixos-config/
sudo chown -R 1000:100 /mnt/persist/home/kbb/nixos-config
```

Reboot -> BIOS boot menu -> select external SSD -> LUKS passphrase -> SDDM login -> KDE Plasma.

### Reinstalling (after config changes, from Arch)

```bash
# Rebuild
cd ~/nixos-config && git add -A
nix build .#nixosConfigurations.Nomad.config.system.build.toplevel

# Mount
sudo cryptsetup open /dev/sda4 nomad-crypt
sudo vgchange -ay nomad-vg
sudo mount -t btrfs -o subvol=@root,compress=zstd,noatime /dev/nomad-vg/nomad-lv /mnt
sudo mount -t btrfs -o subvol=@nix,compress=zstd,noatime /dev/nomad-vg/nomad-lv /mnt/nix
sudo mount -t btrfs -o subvol=@persist,compress=zstd,noatime /dev/nomad-vg/nomad-lv /mnt/persist
sudo mount /dev/sda1 /mnt/boot/efi

# Install + copy config
sudo PATH="$PATH" $(which nix) --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#nixos-install-tools -c nixos-install \
  --flake /home/kbb/nixos-config#Nomad --root /mnt
sudo cp -r /home/kbb/nixos-config/. /mnt/persist/home/kbb/nixos-config/
sudo chown -R 1000:100 /mnt/persist/home/kbb/nixos-config
```

### Updating from Nomad Itself (no reinstall needed)

Once booted into Nomad, just edit config and rebuild:

```bash
cd ~/nixos-config
# Edit files...
sudo sys rebuild    # Apply permanently
sudo sys test       # Ephemeral test (faster)
```

### Disk Layout

```
/dev/sda1  512MB  ESP (vfat, /boot/efi)
/dev/sda2  128GB  NTFS data (/mnt/data, noauto) — accessible as normal USB on any OS
/dev/sda3  16GB   swap
/dev/sda4  rest   LUKS "nomad-crypt"
                  └─ LVM VG "nomad-vg"
                     └─ LV "nomad-lv" (btrfs, label: nomad)
                        ├─ @root        -> /        (wiped every boot)
                        ├─ @nix         -> /nix     (persistent)
                        ├─ @persist     -> /persist (persistent)
                        └─ @root-blank  (rollback snapshot)
```

### Troubleshooting

| Problem | Fix |
|---------|-----|
| Home dir "Permission denied" | `sudo chown -R kbb:users /home/kbb` |
| No terminal | TTY: `Ctrl+Alt+F2`, check `which ghostty` |
| sops "metadata not found" | Delete and recreate: `rm secrets/secrets.yaml && SOPS_AGE_KEY_FILE=... nix run nixpkgs#sops -- secrets/secrets.yaml` |
| EFI not mounted | `sudo mount /dev/sda1 /mnt/boot/efi` |
| WiFi not persisting | Should persist via `/etc/NetworkManager/system-connections` in impermanence |
| Docker not starting | `sudo systemctl start docker` |
| Tailscale | `sudo tailscale up` |
