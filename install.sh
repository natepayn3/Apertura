#!/usr/bin/env bash

set -e

# Target paths and directory structures
QUICKSHELL_DIR="$HOME/.config/quickshell/Apertura"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# ANSI color escape codes for terminal feedback
BLUE='\033;0;34m'
WHITE='\033;0;37m'
GRAY='\033;1;30m'
GREEN='\033;0;32m'
RED='\033;0;31m'
RESET='\033[0m'

clear
echo -e "${BLUE}    _   ____  _____ ____ _____ _   _ ____    _   "
echo -e "   / \  |  _ \| ____|  _ \_  _\| | | |  _ \  / \  "
echo -e "  / _ \ | |_) |  _| | |_) || | | | | | |_) |/ _ \ "
echo -e " / ___ \|  __/| |___|  _ < | | | |_| |  _<___  |"
echo -e "/_/   \_\_|   |_____|_| \_\|_|  \___/|_| \_\  |_| ${RESET}"
echo -e "${GRAY}────────────────────────────────────────────────────────────${RESET}"
echo ""

echo -e "${BLUE}[*]${RESET} Updating system repositories and checking dependencies..."
DEPENDENCIES=(
    "qt6-5compat"
    "grim"
    "slurp"
    "satty"
    "matugen"
    "awww"
    "bluez"
    "bluez-utils"
    "networkmanager"
    "python"
    "wireplumber"
    "pipewire"
    "pipewire-audio"
    "pipewire-pulse"
    "pipewire-alsa"
    "cava"
    "ttf-material-symbols-variable-git"
    "ttf-nerd-fonts-symbols"
    "ttf-rubik-vf"
)

NEW_FONTS_INSTALLED=false

# 1. Custom handling for quickshell to guarantee local AUR build with sysinfo feature
if ! pacman -Qi quickshell-git &>/dev/null; then
    echo -e "    ${GRAY}➔${RESET} Building quickshell-git locally via AUR..."
    
    # Clean out binary packages to avoid transaction blocks or dynamic link conflicts
    if pacman -Qi quickshell &>/dev/null; then
        sudo pacman -Rns --noconfirm quickshell
    fi

    # Explicitly pull from the AUR instead of native mirrors to compile features locally
    if command -v paru &>/dev/null; then
        paru -S --aur --noconfirm --needed quickshell-git
    elif command -v yay &>/dev/null; then
        yay -S --aur --noconfirm --needed quickshell-git
    else
        echo -e "${RED}[X] Error:${RESET} An AUR helper (paru/yay) is required to build quickshell-git."
        exit 1
    fi
else
    echo -e "    ${GRAY}➔${RESET} quickshell-git is already installed. Skipping..."
fi

# 2. Package deployment loops handling native cachyos / core repositories prior to AUR fallbacks
for pkg in "${DEPENDENCIES[@]}"; do
    if [[ "$pkg" == "awww" ]] && command -v awww-daemon &>/dev/null; then
        echo -e "    ${GRAY}➔${RESET} awww daemon is already installed. Skipping..."
        continue
    fi

    if ! pacman -Qi "$pkg" &>/dev/null; then
        echo -e "    ${GRAY}➔${RESET} Installing $pkg..."
        
        if [[ "$pkg" == ttf-* ]]; then
            NEW_FONTS_INSTALLED=true
        fi

        if command -v pacman &>/dev/null && pacman -Si "$pkg" &>/dev/null; then
            sudo pacman -S --noconfirm --needed "$pkg"
        elif command -v paru &>/dev/null; then
            paru -S --noconfirm --needed "$pkg" || paru -S --needed "$pkg"
        elif command -v yay &>/dev/null; then
            yay -S --noconfirm --needed "$pkg" || yay -S --needed "$pkg"
        else
            echo -e "${RED}[X] Error:${RESET} Neither pacman (repo match), paru, nor yay found. Please install $pkg manually."
            exit 1
        fi
    fi
done

if [ "$NEW_FONTS_INSTALLED" = true ]; then
    echo -e "${BLUE}[*]${RESET} Rebuilding system font cache profiles..."
    fc-cache -f
fi

echo -e "${BLUE}[*]${RESET} Setting up local deployment directories..."
mkdir -p "$HOME/.config/quickshell"

if [ ! -d "$WALLPAPER_DIR" ]; then
    echo -e "    ${GRAY}➔${RESET} Creating missing wallpaper destination: $WALLPAPER_DIR"
    mkdir -p "$WALLPAPER_DIR"
fi

if [ -d "Apertura" ]; then
    echo -e "    ${GRAY}➔${RESET} Updating existing local repository directory..."
    (cd Apertura && git reset --hard HEAD && git pull)
else
    echo -e "    ${GRAY}➔${RESET} Cloning Apertura repository..."
    git clone https://github.com/natepayn3/Apertura.git
fi

echo -e "${BLUE}[*]${RESET} Syncing Apertura core assets and helper scripts..."
mkdir -p "$QUICKSHELL_DIR"
cp -r Apertura/. "$QUICKSHELL_DIR/"

# Dynamically map battery hardware interface identifiers
DETECTED_BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1) || true
if [ -n "$DETECTED_BAT" ]; then
    BAT_BASE=$(basename "$DETECTED_BAT")
    echo -e "    ${GRAY}➔${RESET} Mapping battery target identifier node to: $BAT_BASE"
    sed -i "s/BAT1/$BAT_BASE/g" "$QUICKSHELL_DIR/Battery.qml"
else
    echo -e "    ${GRAY}➔${RESET} No battery interface found. Defaulting core layout configurations."
fi

if [ -f "$QUICKSHELL_DIR/bluetooth_control.sh" ]; then
    echo -e "    ${GRAY}➔${RESET} Fixing permissions on bluetooth controller script..."
    chmod +x "$QUICKSHELL_DIR/bluetooth_control.sh"
fi

echo -e "${BLUE}[*]${RESET} Deploying specialized CAVA profile structures..."
mkdir -p "$HOME/.config/cava"

# Explicit CAVA runtime generation block mapping requirements to SplitParser interface
printf '[general]\n# Match this to your visualizer bar count (e.g., 5 bars)\nbars = 10\nframerate = 60\n\n[input]\n# Explicitly leverage PipeWire loopback for perfect audio capture\nmethod = pipewire\nsource = auto\nsensitivity = 0.5\n\n[output]\n# Output raw data format: ascii values separated by semicolons\nmethod = raw\ndata_format = ascii\nascii_max_range = 100\ndata_path = /tmp/cava_bar.fifo\n' > "$HOME/.config/cava/quickshell_bar.conf"

echo -e "${BLUE}[*]${RESET} Injecting configuration trees into hyprland.lua..."
touch "$HYPRLAND_LUA"

# Utility wrapper to append properties safely to script engines
safe_append() {
    local file="$1"
    if [ -s "$file" ] && [ "$(tail -c1 "$file" | wc -l)" -eq 0 ]; then
        echo "" >> "$file"
    fi
    cat >> "$file"
}

if ! grep -q 'local menu = "qs -c Apertura ipc call launcher toggle"' "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding menu declaration macro..."
    echo 'local menu = "qs -c Apertura ipc call launcher toggle"' | safe_append "$HYPRLAND_LUA"
fi

if ! grep -q "quickshell-bar-blur" "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding bar layer rule hooks..."
    echo -e "\n-- Unique configuration for the bar layer\nhl.layer_rule({\n    name  = \"quickshell-bar-blur\",\n    match = { namespace = \"quickshell-bar\" },\n    blur  = true,\n    xray  = true,\n})\n\n-- Combined rule for all other components using regex matching\nhl.layer_rule({\n    name         = \"quickshell-components-blur\",\n    match        = { namespace = \"^quickshell-(overlay|wallpapers|launcher)$\" },\n    blur         = true,\n    xray         = true,\n    ignore_alpha = 0.5,\n})" | safe_append "$HYPRLAND_LUA"
fi

if ! grep -q "satty-screenshot-floating" "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding satty floating window rule..."
    echo -e "\nhl.window_rule({\n    name  = \"satty-screenshot-floating\",\n    match = { \n        class = \"com.gabm.satty\" \n     },\n    float = true,\n})" | safe_append "$HYPRLAND_LUA"
fi

if ! grep -q 'hl.exec_cmd("qs -c Apertura")' "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding startup daemon execution engine..."
    echo -e "\nhl.on(\"hyprland.start\", function ()\n  hl.exec_cmd(\"qs -c Apertura\")\n  hl.exec_cmd(\"awww-daemon\")\nend)" | safe_append "$HYPRLAND_LUA"
fi

echo -e "${BLUE}[*]${RESET} Deploying color token architectures..."
mkdir -p "$QUICKSHELL_DIR/Colors"

# Initialize an empty JSON fallback object to stop FileView read warnings cold
echo "{}" > "$QUICKSHELL_DIR/Colors/colors.json"

# Process live color extraction prior to starting desktop background daemons
ACTIVE_WALLPAPER=$(ls -d "$WALLPAPER_DIR"/* 2>/dev/null | head -n 1 || echo "")
if [ -n "$ACTIVE_WALLPAPER" ] && command -v matugen &>/dev/null; then
    echo -e "    ${GRAY}➔${RESET} Compiling dynamic JSON colorscheme via Matugen..."
    matugen image "$ACTIVE_WALLPAPER" -m dark --source-color-index 0 --dry-run --json hex > "$QUICKSHELL_DIR/Colors/colors.json"
fi

echo -e "${BLUE}[*]${RESET} Booting underlying hardware service engines..."
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service

echo -e "${BLUE}[*]${RESET} Initializing user session sound system modules..."
# Set up default user session media states completely rootless
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

echo -e "${BLUE}[*]${RESET} Activating user space daemons..."
mkdir -p "$HOME/.cache/awww"

if command -v awww-daemon &>/dev/null; then
    pkill awww-daemon || true
    awww-daemon & disown
fi

echo ""
echo -e "${GREEN}[✓] Deployment finished successfully!${RESET}"
