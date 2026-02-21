# kbb's Portable NixOS (Nomad)

## Quick Reinstall (from Arch, after config changes)

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
  --flake /home/kbb/nixos-config#Nomad --root /mnt

# Copy updated config
sudo cp -r /home/kbb/nixos-config/. /mnt/persist/home/kbb/nixos-config/
sudo chown -R 1000:100 /mnt/persist/home/kbb/nixos-config
```

## Rebuild (from Nomad itself)

```bash
cd ~/nixos-config
sudo sys rebuild       # Apply changes permanently
sudo sys test          # Ephemeral test build
```
