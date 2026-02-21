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

## Step 2: Partition (DESTROYS ALL DATA on /dev/nvme0n1)

```bash
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 513MiB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart swap linux-swap 513MiB 32.5GiB
sudo parted /dev/nvme0n1 -- mkpart primary ext4 32.5GiB 100%
```

## Step 3: Format

```bash
sudo mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
sudo mkswap -L swap /dev/nvme0n1p2
sudo mkfs.ext4 -L nixos /dev/nvme0n1p3
```

## Step 4: Mount

```bash
sudo mount /dev/nvme0n1p3 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo swapon /dev/nvme0n1p2
```

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
sudo mount /dev/nvme0n1p3 /mnt
sudo mount /dev/nvme0n1p1 /mnt/boot
# Edit files in /mnt/home/kbb/nixos-config/...
sudo nixos-install --flake /mnt/home/kbb/nixos-config#Desktop --no-root-passwd
```
