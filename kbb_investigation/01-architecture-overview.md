# Architecture Overview

## What This Repo Is

A multi-host NixOS configuration for a user named "sinh", managing 4 machines from a single flake using **Snowfall Lib** as the organizational framework on top of NixOS + home-manager.

## Key Architecture Concepts

### Snowfall Lib — The Glue

Snowfall Lib (`flake.nix:103-116`) is the central piece. Instead of manually wiring up modules, hosts, overlays, etc., Snowfall **auto-discovers** everything based on directory conventions:

- `systems/x86_64-linux/<hostname>/` — NixOS system configurations
- `modules/nixos/` — NixOS modules (auto-loaded for all hosts)
- `modules/home/` — Home-manager modules (auto-loaded)
- `packages/` — Custom packages (exposed as overlays)
- `overlays/` — Nixpkgs overlays
- `lib/` — Custom library functions
- `checks/` — Flake checks (pre-commit hooks)
- `shells/` — Dev shells

The namespace is set to `sinh-x`, which means all home modules are accessed via `sinh-x.*` and NixOS modules via `modules.*`.

### Two-Layer Module System

The config splits into **system-level** and **user-level**:

**NixOS modules** (`modules/nixos/`) — system-wide concerns:
- Window managers, Docker, networking, audio, secrets
- Accessed as `modules.<name>.enable`
- Example: `modules.wm.niri.enable = true` in Emberroot's system config

**Home modules** (`modules/home/`) — user-level, per-application:
- Terminal emulators, editors, browsers, dev tools
- Accessed as `sinh-x.<category>.<name>.enable`
- Example: `sinh-x.cli-apps.terminal.ghostty.enable = true`

Each module follows the same pattern (see ghostty as an example):
```nix
cfg = config.${namespace}.cli-apps.terminal.ghostty;
options.${namespace}.cli-apps.terminal.ghostty = {
  enable = mkEnableOption "Ghostty";
};
config = mkIf cfg.enable { /* actual config */ };
```

### Per-Host Composition

Each host picks what it needs by toggling options:

| | Emberroot | Elderwood | Drgnfly | FireFly |
|---|-----------|-----------|---------|---------|
| **WM** | niri | BSPWM | BSPWM | niri |
| **Role** | Primary desktop | Secondary desktop | Laptop | Portable USB |
| **GPU** | NVIDIA + Intel | DisplayLink | DisplayLink | Generic (modesetting) |
| **Encryption** | None | None | None | LUKS |

**System config** (`systems/x86_64-linux/<hostname>/default.nix`): hardware, boot, networking, which NixOS modules to enable.

**Home config** (`home/sinh/<hostname>.nix`): imports `./global` (shared base), then enables specific apps/tools per host.

### External Projects via Overlays

The user maintains several personal Rust/Nix projects (`sinh-x-*`), brought in as flake inputs and exposed through `overlays/sinh-x/default.nix`. This makes them available as regular `pkgs.*` packages:
- `pkgs.sinh-x-pomodoro`, `pkgs.sinh-x-wallpaper`, `pkgs.nixvim`, `pkgs.zjstatus`, etc.

### Custom Lib Helpers

`lib/module/default.nix` provides shortcuts used throughout:
- `enabled` / `disabled` — shorthand for `{ enable = true/false; }`
- `mkBoolOpt` — quick boolean option creation
- `mkOpt` / `mkOpt'` — option creation helpers

These are available as `lib.sinh-x.enabled`, `lib.sinh-x.mkBoolOpt`, etc. throughout the config.

## Directory Structure

```
systems/x86_64-linux/<hostname>/
  ├── default.nix              # System configuration
  ├── hardware-configuration.nix
  └── disks.nix (disko)

home/sinh/
  ├── global/                   # Shared home config
  └── <hostname>.nix           # Per-host home config

modules/
  ├── nixos/                    # System modules (modules.*)
  │   ├── wm/{bspwm,hyprland,niri}
  │   ├── default-desktop
  │   ├── impermanence
  │   ├── system/security/sops
  │   └── users/sinh
  └── home/                     # Home modules (sinh-x.*)
      ├── apps/
      ├── cli-apps/
      ├── coding/
      ├── wm/
      ├── impermanence/
      └── security/

lib/module/                     # Helper functions
overlays/sinh-x/               # External flake inputs as pkgs
packages/                       # Custom derivations
```

## Data Flow Summary

```
flake.nix
  └── Snowfall auto-discovers everything
       ├── systems/<host>/default.nix     ← enables modules.* options
       ├── home/sinh/<host>.nix           ← enables sinh-x.* options
       ├── modules/nixos/*                ← define modules.* options
       ├── modules/home/*                 ← define sinh-x.* options
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
