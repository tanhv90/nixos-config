#!/usr/bin/env bash

## Searchable keybinding viewer for Niri
## Extracts keybindings from config.kdl and displays them in rofi

DIR="$HOME/.config/niri"
RASI="$DIR/rofi/keybinds.rasi"
NIRI_CONF="$DIR/config.kdl"

# Check if config exists
if [[ ! -f "$NIRI_CONF" ]]; then
    notify-send "Niri Keybinds" "Config file not found: $NIRI_CONF"
    exit 1
fi

# Extract keybindings from config.kdl
# Handles both formats:
# - Mod+Key hotkey-overlay-title="Description" { action; }
# - Mod+Key { action; }
BINDINGS=$(grep -E '^\s*(Mod|Alt|Ctrl|Shift|XF86)[A-Za-z0-9+_-]*\s+' "$NIRI_CONF" | \
    sed -E 's/^[[:space:]]+//' | \
    sed -E '
        # Format with description: extract key and description
        s/^([A-Za-z0-9+_-]+)[[:space:]]+hotkey-overlay-title="([^"]+)".*/\1\t\2/
        t done
        # Format without description: extract key and action
        s/^([A-Za-z0-9+_-]+)[[:space:]]+\{[[:space:]]*([^};]+).*/\1\t\2/
        t done
        d
        :done
    ' | \
    awk -F'\t' '{printf "%-28s  %s\n", $1, $2}' | \
    sort -u)

# Check if we found any bindings
if [[ -z "$BINDINGS" ]]; then
    notify-send "Niri Keybinds" "No keybindings found in config"
    exit 1
fi

# Use rofi theme if it exists, otherwise use default
if [[ -f "$RASI" ]]; then
    CHOICE=$(echo "$BINDINGS" | rofi -dmenu -i -p "Niri Keybinds:" -theme "$RASI")
else
    CHOICE=$(echo "$BINDINGS" | rofi -dmenu -i -p "Niri Keybinds:")
fi

# Exit if no selection (ESC pressed)
[[ -z "$CHOICE" ]] && exit 0

# Optional: Show notification with the selected keybinding
notify-send "Keybind" "$CHOICE"
