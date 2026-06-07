#!/usr/bin/env bash

set -e

QUICKSHELL_DIR="$HOME/.config/quickshell/Apertura"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

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
echo -e "/_/   \_\_|  |_____|_| \_\_|_|  \___/|_| \_\  |_| ${RESET}"
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
    "python-pyxdg"
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

if ! pacman -Qi quickshell-git &>/dev/null; then
    echo -e "    ${GRAY}➔${RESET} Building quickshell-git locally via AUR..."
    
    if pacman -Qi quickshell &>/dev/null; then
        sudo pacman -Rns --noconfirm quickshell
    fi

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
mkdir -p "$HOME/.config/hypr"

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

if [ -d "Apertura/Assets" ]; then
    echo -e "    ${GRAY}➔${RESET} Provisioning layout architecture targets for visual assets..."
    mkdir -p "$QUICKSHELL_DIR/Assets"
fi

cp -r Apertura/. "$QUICKSHELL_DIR/"

DETECTED_BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1) || true
if [ -n "$DETECTED_BAT" ]; then
    BAT_BASE=$(basename "$DETECTED_BAT")
    echo -e "    ${GRAY}➔${RESET} Mapping battery target identifier node to: $BAT_BASE"
    sed -i "s/BAT1/$BAT_BASE/g" "$QUICKSHELL_DIR/Battery.qml"
else
    echo -e "    ${GRAY}➔${RESET} No battery interface found. Defaulting core layout configurations."
fi

if [ -d "$QUICKSHELL_DIR/Scripts" ]; then
    echo -e "    ${GRAY}➔${RESET} Setting execution permissions for modular runtime scripts..."
    chmod +x "$QUICKSHELL_DIR/Scripts"/*.sh 2>/dev/null || true
    chmod +x "$QUICKSHELL_DIR/Scripts"/*.py 2>/dev/null || true
fi

echo -e "${BLUE}[*]${RESET} Deploying specialized CAVA profile structures..."
mkdir -p "$HOME/.config/cava"

printf '[general]\nbars = 10\nframerate = 60\n\n[input]\nmethod = pipewire\nsource = auto\nsensitivity = 0.5\n\n[output]\nmethod = raw\ndata_format = ascii\nascii_max_range = 100\ndata_path = /tmp/cava_bar.fifo\n' > "$HOME/.config/cava/quickshell_bar.conf"

echo -e "${BLUE}[*]${RESET} Checking Hyprland configuration structure..."
if [ ! -f "$HYPRLAND_LUA" ]; then
    if [ -f "Apertura/hyprland.lua" ]; then
        echo -e "    ${GRAY}➔${RESET} hyprland.lua missing. Copying template from repository root..."
        cp "Apertura/hyprland.lua" "$HYPRLAND_LUA"
    elif [ -f "$QUICKSHELL_DIR/hyprland.lua" ]; then
        echo -e "    ${GRAY}➔${RESET} hyprland.lua missing. Copying template from asset directory..."
        cp "$QUICKSHELL_DIR/hyprland.lua" "$HYPRLAND_LUA"
    else
        echo -e "    ${GRAY}➔${RESET} Initialization target created at: $HYPRLAND_LUA"
        touch "$HYPRLAND_LUA"
    fi
else
    echo -e "    ${GRAY}➔${RESET} Existing hyprland.lua detected. Preserving file layout..."
fi

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

if ! grep -q "desktop-clock-widget" "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding bar and extended component layer rule hooks..."
    echo -e "\n-- Unique configuration for the bar layer\nhl.layer_rule({\n    name  = \"quickshell-bar-blur\",\n    match = { namespace = \"quickshell-bar\" },\n    blur  = true,\n    xray  = true,\n})\n\n-- Combined rule for all components (now including the desktop clock widget)\nhl.layer_rule({\n    name         = \"quickshell-components-blur\",\n    match        = { namespace = \"^(quickshell-(overlay|wallpapers|launcher|workspace-preview|detached-note)|desktop-clock-widget)$\" },\n    blur         = true,\n    xray         = true,\n    ignore_alpha = 0.5,\n})" | safe_append "$HYPRLAND_LUA"
fi

if ! grep -q "satty-screenshot-floating" "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding satty floating window rule..."
    echo -e "\n-- Satty always floats\nhl.window_rule({\n    name  = \"satty-screenshot-floating\",\n    match = { \n        class = \"com.gabm.satty\" \n     },\n    float = true,\n})" | safe_append "$HYPRLAND_LUA"
fi

if ! grep -q 'hl.exec_cmd("qs -c Apertura")' "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding startup daemon execution engine..."
    echo -e "\nhl.on(\"hyprland.start\", function ()\n  hl.exec_cmd(\"qs -c Apertura\")\n  hl.exec_cmd(\"awww-daemon\")\nend)" | safe_append "$HYPRLAND_LUA"
fi

echo -e "${BLUE}[*]${RESET} Deploying color token architectures..."
mkdir -p "$QUICKSHELL_DIR/Colors"
echo "{}" > "$QUICKSHELL_DIR/Colors/colors.json"

ACTIVE_WALLPAPER=$(ls -d "$WALLPAPER_DIR"/* 2>/dev/null | head -n 1 || echo "")
if [ -n "$ACTIVE_WALLPAPER" ] && command -v matugen &>/dev/null; then
    echo -e "    ${GRAY}➔${RESET} Compiling dynamic JSON colorscheme via Matugen..."
    matugen image "$ACTIVE_WALLPAPER" -m dark --source-color-index 0 --dry-run --json hex > "$QUICKSHELL_DIR/Colors/colors.json"
fi

echo -e "${BLUE}[*]${RESET} Booting underlying hardware service engines..."
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service

echo -e "${BLUE}[*]${RESET} Aligning user policies for NetworkManager VPN integrations..."
nmcli -t -f TYPE,NAME connection show | grep -E '^(wireguard|vpn|tun):' | cut -d: -f2 | while read -r profile; do
    if [ -n "$profile" ]; then
        echo -e "    ${GRAY}➔${RESET} Elevating user control permissions for connection profile: $profile"
        nmcli connection modify "$profile" connection.permissions "user:$USER" 2>/dev/null || true
    fi
done

echo -e "${BLUE}[*]${RESET} Initializing user session sound system modules..."
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

echo -e "${BLUE}[*]${RESET} Activating user space daemons..."
mkdir -p "$HOME/.cache/awww"

if command -v awww-daemon &>/dev/null; then
    pkill awww-daemon || true
    awww-daemon & disown
fi

echo -e "${BLUE}[*]${RESET} Launching local Apertura desktop shell interface..."
pkill quickshell || true
qs -c Apertura & disown

echo ""
echo -e "${GREEN}[✓] Deployment finished successfully!${RESET}"
