# Sops-nix: Secrets Management

## The Problem

NixOS configs live in a git repo and get copied to `/nix/store`, which is **world-readable**. You can't put passwords, API tokens, or WiFi credentials directly in your `.nix` files — anyone on the system (or anyone who clones the repo) can read them.

## How sops-nix Solves It

**SOPS** (Secrets OPerationS) encrypts secrets in a YAML file. Only someone with the matching **age** private key can decrypt them. sops-nix integrates this into NixOS so secrets are decrypted at **system activation time** (during boot/rebuild) into a tmpfs at `/run/secrets/`.

## The Flow in This Repo

### 1. The Age Keypair

- **Public key** is in `.sops.yaml`: `age1u0h8j45ym4jq...`
- **Private key** lives on the machine at `/home/sinh/.config/sops/age/keys.txt` (or `/persist/system/sops/age/keys.txt` with impermanence)
- The private key is **never** committed to git

### 2. The Encrypted File — `secrets/secrets.yaml`

```yaml
nix:
    github_access_token: ENC[AES256_GCM,data:ii40/32o...,type:str]
wifi:
    credentials: ENC[AES256_GCM,data:yvd/qDpS...,type:str]
users:
    sinh:
        hashedPassword: ENC[AES256_GCM,data:2fpIPgq4...,type:str]
```

The YAML structure is readable (you can see the key names), but every value is AES-256 encrypted. Only the age private key can decrypt them.

### 3. The NixOS Module — `modules/nixos/system/security/sops/default.nix`

```nix
sops = {
  defaultSopsFile = ../../../../../secrets/secrets.yaml;  # where encrypted file is
  age.keyFile = "/persist/system/sops/age/keys.txt";      # where private key is

  secrets = {
    "nix/github_access_token" = { owner = "sinh"; };      # decrypt as user sinh
    "wifi/credentials" = { owner = "wpa_supplicant"; };    # decrypt for wifi daemon
    "users/sinh/hashedPassword" = { neededForUsers = true; }; # needed before login
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

- **WiFi module** (`modules/nixos/wifi/default.nix`):
  ```nix
  secretsFile = config.sops.secrets."wifi/credentials".path;
  ```
  wpa_supplicant reads passwords from the decrypted file at runtime.
  The `ext:vuonnha` syntax in the WiFi config references named entries inside that credentials file.

- **User module** (`modules/nixos/users/sinh/default.nix`):
  ```nix
  hashedPasswordFile = config.sops.secrets."users/sinh/hashedPassword".path;
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
# outputs: Public key: age1u0h8j45ym4jqffhc6jlr8metcl4czylv7ct7ngusrxrklnfsgvmsd8qzvs
```

**Copy to the machine:**
- Normal system: `/home/sinh/.config/sops/age/keys.txt`
- Impermanence system: `/persist/system/sops/age/keys.txt`

**The sops module auto-detects** (`modules/nixos/system/security/sops/default.nix:27-30`):
```nix
age.keyFile =
  if config.modules.impermanence.enable or false then
    "/persist/system/sops/age/keys.txt"
  else
    "/home/sinh/.config/sops/age/keys.txt";
```

### What `keys.txt` Looks Like

```
# created: 2024-01-15T10:30:00Z
# public key: age1u0h8j45ym4jqffhc6jlr8metcl4czylv7ct7ngusrxrklnfsgvmsd8qzvs
AGE-SECRET-KEY-1QFWK... (the actual private key)
```

### How to Get It Onto the Machine

| Method | When |
|--------|------|
| `age-keygen -o keys.txt` on the installer | Fresh install, new key |
| USB drive | Carry the key physically |
| `scp` from another machine | Over network during install |
| Password manager | Copy-paste into the file |

The impermanence module's `systemd.tmpfiles.rules` pre-creates the directory:
```nix
"d ${cfg.persistPath}/system/sops/age 0700 root root -"
```

### Summary

- Generated once manually with `age-keygen`
- Copied to the machine by hand (USB, SSH, etc.)
- Never committed to git, never managed by Nix
- Stored in `/persist/` so impermanence doesn't wipe it
- Everything else is encrypted to this key and safely lives in git
