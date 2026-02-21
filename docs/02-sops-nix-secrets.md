# Sops-nix: Secrets Management

## The Problem

NixOS configs live in a git repo and get copied to `/nix/store`, which is **world-readable**. You can't put passwords, API tokens, or WiFi credentials directly in your `.nix` files — anyone on the system (or anyone who clones the repo) can read them.

## How sops-nix Solves It

**SOPS** (Secrets OPerationS) encrypts secrets in a YAML file. Only someone with the matching **age** private key can decrypt them. sops-nix integrates this into NixOS so secrets are decrypted at **system activation time** (during boot/rebuild) into a tmpfs at `/run/secrets/`.

## The Flow in This Repo

### 1. The Age Keypair

- **Public key** is in `.sops.yaml`
- **Private key** lives on the machine at `/home/kbb/.config/sops/age/keys.txt` (or `/persist/system/sops/age/keys.txt` with impermanence)
- The private key is **never** committed to git

### 2. The Encrypted File — `secrets/secrets.yaml`

```yaml
nix:
    github_access_token: ENC[AES256_GCM,data:ii40/32o...,type:str]
wifi:
    credentials: ENC[AES256_GCM,data:yvd/qDpS...,type:str]
users:
    kbb:
        hashedPassword: ENC[AES256_GCM,data:2fpIPgq4...,type:str]
```

The YAML structure is readable (you can see the key names), but every value is AES-256 encrypted. Only the age private key can decrypt them.

### 3. The NixOS Module — `modules/nixos/sops/default.nix`

```nix
sops = {
  defaultSopsFile = ../../../../../secrets/secrets.yaml;  # where encrypted file is
  age.keyFile = "/home/kbb/.config/sops/age/keys.txt";    # where private key is

  secrets = {
    "nix/github_access_token" = { owner = "kbb"; };
    "users/kbb/hashedPassword" = { neededForUsers = true; };
  };
};
```

### 4. At Boot/Rebuild

sops-nix:
1. Reads the age private key from `age.keyFile`
2. Decrypts each secret from `secrets.yaml`
3. Places them as files under `/run/secrets/` (a tmpfs — never touches disk)
4. Sets ownership/permissions per the config

### 5. Other Modules Reference the Decrypted Paths

- **User module** (`modules/nixos/users/kbb/default.nix`):
  ```nix
  hashedPasswordFile = config.sops.secrets."users/kbb/hashedPassword".path;
  ```
  The user's login password hash comes from the encrypted file, never hardcoded.

### To Edit Secrets

```bash
sops secrets/secrets.yaml  # opens in $EDITOR with decrypted values, re-encrypts on save
```

## How `keys.txt` Is Stored

The age private key is the **trust anchor** — it's the one piece that can't be declarative.

### The Bootstrap Problem

1. sops-nix needs the age private key to decrypt secrets
2. The private key is itself a secret
3. You can't encrypt the key with sops because you need the key to decrypt sops

So `keys.txt` is **manually placed** on the machine.

### The Process

**Generate the keypair (once, on any machine):**
```bash
age-keygen -o keys.txt
# outputs: Public key: age1...
```

**Copy to the machine:**
- Normal system (Desktop): `/home/kbb/.config/sops/age/keys.txt`
- Impermanence system (Nomad): `/persist/system/sops/age/keys.txt`

**The sops module auto-detects** (`modules/nixos/sops/default.nix`):
```nix
age.keyFile =
  if config.modules.impermanence.enable or false then
    "/persist/system/sops/age/keys.txt"
  else
    "/home/kbb/.config/sops/age/keys.txt";
```

### What `keys.txt` Looks Like

```
# created: 2024-01-15T10:30:00Z
# public key: age1...
AGE-SECRET-KEY-1QFWK... (the actual private key)
```

### How to Get It Onto the Machine

| Method | When |
|--------|------|
| `age-keygen -o keys.txt` on the installer | Fresh install, new key |
| USB drive | Carry the key physically |
| `scp` from another machine | Over network during install |
| Password manager | Copy-paste into the file |

### Summary

- Generated once manually with `age-keygen`
- Copied to the machine by hand (USB, SSH, etc.)
- Never committed to git, never managed by Nix
- On Nomad: stored in `/persist/` so impermanence doesn't wipe it
- On Desktop: stored in `~/.config/sops/age/` (persistent root, no special handling needed)
- Everything else is encrypted to this key and safely lives in git
