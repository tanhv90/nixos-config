# Architecture Overview

## What This Repo Is

A multi-host NixOS configuration managing machines from a single flake using **Snowfall Lib** as the organizational framework on top of NixOS + home-manager.

## Key Architecture Concepts

### Snowfall Lib — The Glue

Snowfall Lib is the central piece. Instead of manually wiring up modules, hosts, overlays, etc., Snowfall **auto-discovers** everything based on directory conventions:

- `systems/x86_64-linux/<hostname>/` — NixOS system configurations
- `modules/nixos/` — NixOS modules (auto-loaded for all hosts)
- `modules/home/` — Home-manager modules (auto-loaded)
- `packages/` — Custom packages (exposed as overlays)
- `overlays/` — Nixpkgs overlays
- `lib/` — Custom library functions
- `checks/` — Flake checks (pre-commit hooks)
- `shells/` — Dev shells

The namespace is set to `kbb`, which means all home modules are accessed via `kbb.*` and NixOS modules via `modules.*`.

### Two-Layer Module System

The config splits into **system-level** and **user-level**:

**NixOS modules** (`modules/nixos/`) — system-wide concerns:
- Desktop environment, Docker, networking, audio, secrets
- Accessed as `modules.<name>.enable`
- Example: `modules.stubby.enable = true`

**Home modules** (`modules/home/`) — user-level, per-application:
- Terminal emulators, editors, shell config, dev tools
- Accessed as `kbb.<name>.enable`
- Example: `kbb.ghostty.enable = true`

Each module follows the same pattern:
```nix
cfg = config.${namespace}.ghostty;
options.${namespace}.ghostty = {
  enable = mkEnableOption "Ghostty";
};
config = mkIf cfg.enable { /* actual config */ };
```

### Per-Host Composition

Each host picks what it needs by toggling options:

| | Nomad | Desktop |
|---|---|---|
| **Role** | Portable SSD | Stationary desktop PC |
| **GPU** | Generic (modesetting) | NVIDIA RTX 3060 (proprietary) |
| **Encryption** | LUKS + impermanence | None (persistent root) |
| **Root FS** | btrfs (wiped every boot) | btrfs (traditional persistent) |

**System config** (`systems/x86_64-linux/<hostname>/default.nix`): hardware, boot, networking, which NixOS modules to enable.

**Home config** (`home/kbb/<hostname>.nix`): imports `./global` (shared base), then enables specific apps/tools per host.

### Custom Lib Helpers

`lib/module/default.nix` provides shortcuts used throughout:
- `enabled` / `disabled` — shorthand for `{ enable = true/false; }`
- `mkBoolOpt` — quick boolean option creation
- `mkOpt` / `mkOpt'` — option creation helpers

These are available as `lib.kbb.enabled`, `lib.kbb.mkBoolOpt`, etc. throughout the config.

## Directory Structure

```
systems/x86_64-linux/<hostname>/
  ├── default.nix              # System configuration
  ├── hardware-configuration.nix
  └── disks.nix                # disko partition layout

home/kbb/
  ├── global/                   # Shared home config
  └── <hostname>.nix           # Per-host home config

modules/
  ├── nixos/                    # System modules (modules.*)
  │   ├── default-desktop/
  │   ├── fcitx5/
  │   ├── fish/
  │   ├── impermanence/
  │   ├── niri/
  │   ├── sops/
  │   ├── fcitx5/
  │   ├── stubby/
  │   ├── users/kbb/
  │   └── wifi/
  └── home/                     # Home modules (kbb.*)
      ├── ai-tools/
      ├── fish/
      ├── ghostty/
      ├── neovim/
      ├── onlyoffice/
      ├── starship/
      ├── zellij/
      └── niri/

lib/module/                     # Helper functions
overlays/
  ├── claude-code/              # Claude Code version overlay
  └── neve/                     # Neve nixvim overlay
packages/sys/                   # sys rebuild/test/update/clean
```

## Data Flow Summary

```
flake.nix
  └── Snowfall auto-discovers everything
       ├── systems/<host>/default.nix     ← enables modules.* options
       ├── home/kbb/<host>.nix            ← enables kbb.* options
       ├── modules/nixos/*                ← define modules.* options
       ├── modules/home/*                 ← define kbb.* options
       ├── overlays/                      ← inject external packages
       └── lib/                           ← shared helpers
```

The pattern is: **modules declare options -> hosts toggle them on/off -> Snowfall wires it all together automatically**.

## What Snowfall Gives You

| Without Snowfall | With Snowfall |
|---|---|
| Manual imports in flake outputs | Auto-discovery by directory |
| Wire up overlays, modules, packages yourself | All automatic |
| Home-manager integration boilerplate | Handled by the framework |
| Custom lib needs manual plumbing | `lib/` directory auto-loaded |

The tradeoff is that Snowfall is somewhat opinionated about directory structure and adds a layer of abstraction. If a NixOS option isn't working, you sometimes have to debug through Snowfall's wiring. But for multi-host setups, the reduction in boilerplate is significant.
