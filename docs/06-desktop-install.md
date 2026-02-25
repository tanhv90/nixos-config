# Install Desktop from Nomad

Install the Desktop host (i7-13700F, RTX 3060, 32GB DDR4) to the internal NVMe drive, booting from the Nomad portable SSD.

## Prerequisites

- Boot into Nomad on the Desktop PC
- Internal NVMe is `/dev/nvme0n1` (verify with `lsblk`)
- Age `keys.txt` backed up somewhere accessible

## Step 1: Identify the disk

```bash
lsblk -o NAME,SIZE,MODEL,TRAN
# Confirm /dev/nvme0n1 is the internal NVMe, NOT the Nomad SSD
```

## Step 2: Partition with disko (DESTROYS ALL DATA on /dev/nvme0n1)

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- --mode disko \
  ~/nixos-config/systems/x86_64-linux/Desktop/disks.nix
```

This creates:
- `/dev/nvme0n1p1` — 512MB ESP (vfat, `/boot`)
- `/dev/nvme0n1p2` — 32GB swap
- `/dev/nvme0n1p3` — rest as btrfs (label: nixos) with `@` → `/` and `@home` → `/home`

Disko automatically mounts everything to `/mnt`.

## Step 5: Setup sops age key

```bash
sudo mkdir -p /mnt/home/kbb/.config/sops/age
sudo cp /home/kbb/.config/sops/age/keys.txt /mnt/home/kbb/.config/sops/age/keys.txt
sudo chmod 600 /mnt/home/kbb/.config/sops/age/keys.txt
```

If running from Nomad with impermanence, the key may be at the persist path instead:

```bash
# Alternative:
sudo cp /persist/system/sops/age/keys.txt /mnt/home/kbb/.config/sops/age/keys.txt
```

## Step 6: Clone repo

```bash
sudo git clone https://github.com/tanhv90/nixos-config.git /mnt/home/kbb/nixos-config
```

## Step 7: Install

```bash
sudo nixos-install --flake /mnt/home/kbb/nixos-config#Desktop --no-root-passwd
```

## Step 8: Fix ownership

```bash
sudo chown -R 1000:100 /mnt/home/kbb
```

## Step 9: Reboot

```bash
sudo reboot
```

Remove the Nomad SSD (or change boot order in BIOS to boot from the internal NVMe).

## Post-install verification

```bash
nvidia-smi                        # NVIDIA driver loaded
systemctl status tailscaled       # Tailscale
systemctl status docker           # Docker
systemctl status sshd             # SSH
sudo tailscale up                 # First-time Tailscale auth
```

## If something goes wrong

Boot back into Nomad, mount the NVMe, and fix:

```bash
sudo mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p3 /mnt
sudo mkdir -p /mnt/boot /mnt/home
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p3 /mnt/home
# Edit files in /mnt/home/kbb/nixos-config/...
sudo nixos-install --flake /mnt/home/kbb/nixos-config#Desktop --no-root-passwd
```
