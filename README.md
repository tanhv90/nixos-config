# kbb's Portable NixOS (Nomad)

Portable NixOS on an external SSD with LUKS encryption, ephemeral root (impermanence), and declarative config via Snowfall Lib.

## Disk Layout

```
/dev/sda1  512MB  ESP (vfat, /boot/efi)
/dev/sda2  16GB   swap
/dev/sda3  rest   LUKS "nomad-crypt"
                  └─ LVM VG "nomad-vg"
                     └─ LV "nomad-lv" (btrfs, label: nomad)
                        ├─ @root        → /        (wiped every boot)
                        ├─ @nix         → /nix     (persistent)
                        ├─ @persist     → /persist (persistent)
                        └─ @root-blank  (rollback snapshot)
```

## Fresh Install (from Arch Linux)

Prerequisites: Arch Linux with Nix installed (multi-user), external SSD at `/dev/sda`.

### 1. Clone and verify build

```bash
git clone https://github.com/tanhv90/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

### 2. Generate age key

```bash
nix shell nixpkgs#age -c age-keygen -o /tmp/age-keys.txt
# Copy the public key (age1...) from the output
```

### 3. Configure sops

Edit `.sops.yaml` — replace the age public key with yours.

### 4. Create encrypted secrets

```bash
# Generate password hash
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512

# Create secrets file
rm -f secrets/secrets.yaml
SOPS_AGE_KEY_FILE=/tmp/age-keys.txt nix run nixpkgs#sops -- secrets/secrets.yaml
# In the editor, add:
#   users:
#     kbb:
#       hashedPassword: "$6$..."
```

### 5. Verify build

```bash
git add -A
nix build .#nixosConfigurations.Nomad.config.system.build.toplevel
```

### 6. Partition disk (DESTROYS ALL DATA on /dev/sda)

```bash
lsblk -o NAME,SIZE,MODEL,TRAN   # Confirm /dev/sda is your SSD

cp systems/x86_64-linux/Nomad/disks.nix /tmp/disks.nix
sudo $(which nix) --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- --mode disko /tmp/disks.nix
# You'll set a LUKS passphrase — typed every boot
```

### 7. Populate persistent storage

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

### 8. Install

```bash
sudo PATH="$PATH" $(which nix) --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#nixos-install-tools -c nixos-install \
  --flake ~/nixos-config#Nomad --root /mnt
```

### 9. Copy config and reboot

```bash
sudo cp -r ~/nixos-config/. /mnt/persist/home/kbb/nixos-config/
sudo chown -R 1000:100 /mnt/persist/home/kbb/nixos-config
```

Reboot → BIOS boot menu → select external SSD → LUKS passphrase → SDDM login.

## Reinstall (from Arch, after config changes)

```bash
# Build
cd ~/nixos-config && git add -A
nix build .#nixosConfigurations.Nomad.config.system.build.toplevel

# Mount partitions
sudo cryptsetup open /dev/sda3 nomad-crypt
sudo vgchange -ay nomad-vg
sudo mount -t btrfs -o subvol=@root,compress=zstd,noatime /dev/nomad-vg/nomad-lv /mnt
sudo mount -t btrfs -o subvol=@nix,compress=zstd,noatime /dev/nomad-vg/nomad-lv /mnt/nix
sudo mount -t btrfs -o subvol=@persist,compress=zstd,noatime /dev/nomad-vg/nomad-lv /mnt/persist
sudo mount /dev/sda1 /mnt/boot/efi

# Reinstall
sudo PATH="$PATH" $(which nix) --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#nixos-install-tools -c nixos-install \
  --flake ~/nixos-config#Nomad --root /mnt

# Copy updated config
sudo cp -r ~/nixos-config/. /mnt/persist/home/kbb/nixos-config/
sudo chown -R 1000:100 /mnt/persist/home/kbb/nixos-config
```

## Rebuild (from Nomad itself)

```bash
cd ~/nixos-config
sudo sys rebuild       # Apply changes permanently
sudo sys test          # Ephemeral test build
sudo sys update        # Update flake inputs
sys clean              # Clean nix store
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Home dir "Permission denied" | `sudo chown -R kbb:users /home/kbb` |
| No terminal | TTY: `Ctrl+Alt+F2`, check `which ghostty` |
| sops "metadata not found" | Delete and recreate: `rm secrets/secrets.yaml && SOPS_AGE_KEY_FILE=... nix run nixpkgs#sops -- secrets/secrets.yaml` |
| EFI not mounted | `sudo mount /dev/sda1 /mnt/boot/efi` |
| Docker not starting | `sudo systemctl start docker` |
| Tailscale | `sudo tailscale up` |

## Docs

See [docs/](docs/) for architecture details:
- [Architecture overview](docs/01-architecture-overview.md)
- [Sops-nix secrets](docs/02-sops-nix-secrets.md)
- [Impermanence](docs/03-impermanence.md)
- [Portable USB reference](docs/04-firefly-portable-usb.md)
- [Setting up your own](docs/05-setting-up-your-own.md)
- [Setup script](docs/setup.sh)
