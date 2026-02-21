#!/usr/bin/env bash
# kbb_setup — Nomad portable NixOS installation guide
# Reference: ~/nixos-config
#
# Prerequisites: Arch Linux host, external SSD at /dev/sda

set -euo pipefail

cat <<'EOF'
=== Nomad — Portable NixOS Setup ===

IMPORTANT: On Arch, `sudo` cannot find nix commands. Use:
  sudo $(which nix) --extra-experimental-features "nix-command flakes" ...
  sudo PATH="$PATH" $(which nix) ...

───────────────────────────────────────
 FRESH INSTALL
───────────────────────────────────────

1. INIT REPO
   cd ~/nixos-config
   git init && git add -A && git commit -m "Initial commit"

2. GENERATE AGE KEY
   nix shell nixpkgs#age -c age-keygen -o /tmp/age-keys.txt
   # Copy the public key (age1...) from the output

3. CONFIGURE SOPS
   # Edit .sops.yaml — replace the placeholder key with your public key
   nvim .sops.yaml

4. CREATE SECRETS
   # Generate password hash first:
   nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512

   # Delete the placeholder and create encrypted secrets:
   rm secrets/secrets.yaml
   SOPS_AGE_KEY_FILE=/tmp/age-keys.txt nix run nixpkgs#sops -- secrets/secrets.yaml
   # In the editor, write:
   #   users:
   #     kbb:
   #       hashedPassword: "$6$..."

5. VERIFY BUILD (before touching the disk)
   cd ~/nixos-config && git add -A
   nix build .#nixosConfigurations.Nomad.config.system.build.toplevel

6. IDENTIFY DISK
   lsblk -o NAME,SIZE,MODEL,TRAN
   # Confirm /dev/sda is the external SSD, NOT your main drive!

7. PARTITION DISK (/dev/sda — DESTROYS ALL DATA)
   # On Arch, nix isn't in root's PATH:
   cp systems/x86_64-linux/Nomad/disks.nix /tmp/disks.nix
   sudo $(which nix) --extra-experimental-features "nix-command flakes" \
     run github:nix-community/disko -- --mode disko /tmp/disks.nix
   # Sets LUKS passphrase — choose something strong, typed every boot

8. POPULATE PERSIST
   sudo mkdir -p /mnt/persist/system/sops/age
   sudo cp /tmp/age-keys.txt /mnt/persist/system/sops/age/keys.txt
   sudo chmod 600 /mnt/persist/system/sops/age/keys.txt

   sudo mkdir -p /mnt/persist/system/etc/ssh
   sudo ssh-keygen -t ed25519 -f /mnt/persist/system/etc/ssh/ssh_host_ed25519_key -N ""
   sudo ssh-keygen -t rsa -b 4096 -f /mnt/persist/system/etc/ssh/ssh_host_rsa_key -N ""

   sudo mkdir -p /mnt/persist/home/kbb
   sudo chown -R 1000:100 /mnt/persist/home/kbb

9. INSTALL
   sudo PATH="$PATH" $(which nix) --extra-experimental-features "nix-command flakes" \
     shell nixpkgs#nixos-install-tools -c nixos-install \
     --flake /home/kbb/nixos-config#Nomad --root /mnt

10. COPY CONFIG TO INSTALLED SYSTEM
    sudo cp -r /home/kbb/nixos-config/. /mnt/persist/home/kbb/nixos-config/
    sudo chown -R 1000:100 /mnt/persist/home/kbb/nixos-config

11. REBOOT
    Boot into external SSD via BIOS boot menu (F12/F2/Del).
    LUKS passphrase → SDDM login → kbb → KDE Plasma starts.

───────────────────────────────────────
 REINSTALL (from Arch, after config changes)
───────────────────────────────────────

# Rebuild first
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
  --flake /home/kbb/nixos-config#Nomad --root /mnt

# Copy updated config
sudo cp -r /home/kbb/nixos-config/. /mnt/persist/home/kbb/nixos-config/
sudo chown -R 1000:100 /mnt/persist/home/kbb/nixos-config

───────────────────────────────────────
 POST-INSTALL (from Nomad itself)
───────────────────────────────────────

# Rebuild after config changes (no reinstall needed!)
cd ~/nixos-config
sudo sys rebuild       # Apply changes permanently
sudo sys test          # Ephemeral test build (faster)

# Connect WiFi (NetworkManager — saved connections persist across reboots)
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"

# Update flake inputs
sudo sys update

# Clean nix store
sys clean

───────────────────────────────────────
 TROUBLESHOOTING
───────────────────────────────────────

Home directory "Permission denied":
  # From TTY (Ctrl+Alt+F2), login as kbb:
  sudo chown -R kbb:users /home/kbb

No terminal after login:
  # KDE: open Konsole from app launcher, or Ctrl+Alt+F2 for TTY
  # Check ghostty: which ghostty

sops "metadata not found":
  # Delete and recreate the secrets file:
  rm secrets/secrets.yaml
  SOPS_AGE_KEY_FILE=/tmp/age-keys.txt nix run nixpkgs#sops -- secrets/secrets.yaml

Bootloader "efiSysMountPoint not mounted":
  # EFI partition isn't mounted. Mount it:
  sudo mount /dev/sda1 /mnt/boot/efi

Docker not starting:
  sudo systemctl start docker
  # Verify: docker ps

Tailscale:
  sudo tailscale up

───────────────────────────────────────
 DISK LAYOUT
───────────────────────────────────────

/dev/sda1  512MB  ESP (vfat, /boot/efi)
/dev/sda2  16GB   swap
/dev/sda3  rest   LUKS "nomad-crypt"
                  └─ LVM VG "nomad-vg"
                     └─ LV "nomad-lv" (btrfs, label: nomad)
                        ├─ @root        → /        (wiped every boot)
                        ├─ @nix         → /nix     (persistent)
                        ├─ @persist     → /persist (persistent)
                        └─ @root-blank  (rollback snapshot)

───────────────────────────────────────
 FILE STRUCTURE
───────────────────────────────────────

flake.nix                              # Inputs + Snowfall (namespace: kbb)
lib/module/default.nix                 # mkOpt, enabled/disabled helpers
checks/pre-commit-hooks/default.nix    # deadnix, nixfmt, statix, sops
shells/default/default.nix             # Dev shell
.sops.yaml                             # Age key config
secrets/secrets.yaml                   # Encrypted secrets

modules/nixos/
  default-desktop/  # kbb.default-desktop — fonts, locale, base packages
  impermanence/     # modules.impermanence — tmpfs root + persist
  sops/             # modules.sops — age-encrypted secrets
  users/kbb/        # User definition, fish shell, home-manager link
  fish/             # modules.fish — fish plugins
  wifi/             # modules.wifi — wpa_supplicant (disabled, using NetworkManager)
  niri/             # modules.niri — Wayland WM (available but not active)
  stubby/           # modules.stubby — DNS-over-TLS (Cloudflare)

modules/home/
  ghostty/          # kbb.ghostty — terminal emulator
  fish/             # kbb.fish — shell config, abbreviations
  starship/         # kbb.starship — prompt
  neovim/           # kbb.neovim — editor + treesitter, telescope, LSP, completion
  zellij/           # kbb.zellij — multiplexer
  ai-tools/         # kbb.ai-tools — Claude Code
  onlyoffice/       # kbb.onlyoffice — office suite
  niri/             # kbb.niri — niri home config (available but not active)

overlays/
  claude-code/      # Claude Code version overlay
  neve/             # Neve nixvim overlay

systems/x86_64-linux/Nomad/
  default.nix                # System config — KDE Plasma, Docker, Tailscale, Cloudflared
  hardware-configuration.nix # Generic x86_64, LUKS+LVM, initrd rollback
  disks.nix                  # Disko partition layout

home/kbb/
  global/default.nix         # Base home config
  Nomad.nix                  # Per-host: enables home modules

packages/sys/default.nix     # sys rebuild/test/update/clean

───────────────────────────────────────
 INSTALLED SOFTWARE
───────────────────────────────────────

Desktop:      KDE Plasma 6 (Wayland) + SDDM
Terminal:     Ghostty
Shell:        Fish + Starship prompt
Editor:       Neovim (treesitter, telescope, LSP, completion)
Multiplexer:  Zellij
Browser:      Firefox
AI:           Claude Code
Passwords:    1Password
Code:         VS Code
Containers:   Docker + lazydocker
VPN:          Tailscale
Tunnel:       Cloudflared
DNS:          Stubby (DNS-over-TLS, Cloudflare)
Secrets:      SOPS + age encryption
EOF
