#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Target deployment paths
QUICKSHELL_DIR="$HOME/.config/quickshell/Apertura"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Valid ANSI Escape Code Variable Identifiers
BLUE='\033[0;34m'
WHITE='\033[0;37m'
GRAY='\033[1;30m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# Clear screen and blast the block capital banner
clear
echo -e "${BLUE}    _   ____  _____ ____ _____ _   _ ____    _   "
echo -e "   / \  |  _ \| ____|  _ \_   _| | | |  _ \  / \  "
echo -e "  / _ \ | |_) |  _| | |_) || | | | | | |_) |/ _ \ "
echo -e " / ___ \|  __/| |___|  _ < | | | |_| |  _ <___  |"
echo -e "/_/   \_\_|   |_____|_| \_\|_|  \___/|_| \_\  |_| ${RESET}"
echo -e "${GRAY}────────────────────────────────────────────────────────────${RESET}"
echo ""

echo -e "${BLUE}[*]${RESET} Updating system repositories and checking dependencies..."
DEPENDENCIES=(
    "quickshell"
    "satty"                         # Added dependency for screenshot annotations
    "matugen"                      # Material You color generation backbone engine
    "awww"                         # Targeted standard AUR package instead of -git
    "bluez"
    "bluez-utils"                  # Provides 'bluetoothctl' binary used by Bluetooth.qml
    "networkmanager"               # Provides 'nmcli' binary used by Wifi.qml
    "python"                       # Provides 'python3' interpreter used by AppLauncher.qml
    "wireplumber"                  # Provides 'wpctl' used by Audio.qml & VolumeHud
    "ttf-material-design-icons-git" # Maps \uE050 style system glyphs cleanly
    "ttf-nerd-fonts-symbols"       # Font tracking backbone fallback for 󰂱 and 󱐋 shapes
)

NEW_FONTS_INSTALLED=false

for pkg in "${DEPENDENCIES[@]}"; do
    # Skip if awww provider is already satisfied by any variant providing awww-daemon
    if [[ "$pkg" == "awww" ]] && command -v awww-daemon &>/dev/null; then
        echo -e "    ${GRAY}➔${RESET} awww daemon is already installed. Skipping..."
        continue
    fi

    if ! pacman -Qi "$pkg" &>/dev/null; then
        echo -e "    ${GRAY}➔${RESET} Installing $pkg..."
        
        # Track if font packages are being added to trigger a cache rebuild
        if [[ "$pkg" == ttf-* ]]; then
            NEW_FONTS_INSTALLED=true
        fi

        # Check cachyos repo or explicit helpers for installation
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

# Rebuild font index immediately if new typography assets were deployed
if [ "$NEW_FONTS_INSTALLED" = true ]; then
    echo -e "${BLUE}[*]${RESET} Rebuilding system font cache profiles..."
    fc-cache -f
fi

echo -e "${BLUE}[*]${RESET} Setting up local deployment directories..."
mkdir -p "$HOME/.config/quickshell"

# Create the hardcoded system asset path for background images if missing
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo -e "    ${GRAY}➔${RESET} Creating missing wallpaper destination: $WALLPAPER_DIR"
    mkdir -p "$WALLPAPER_DIR"
fi

# Atomic repository management pointing to public Git path
if [ -d "Apertura" ]; then
    echo -e "    ${GRAY}➔${RESET} Updating existing local repository directory..."
    # Subshell block safely isolates directory changes and failure risks
    (cd Apertura && git pull)
else
    echo -e "    ${GRAY}➔${RESET} Cloning Apertura repository..."
    git clone https://github.com/natepayn3/Apertura.git
fi

# Dynamic battery sysfs routing locator
DETECTED_BAT=$(basename $(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1) 2>/dev/null || echo "BAT1")
echo -e "    ${GRAY}➔${RESET} Mapping battery target identifier node to: $DETECTED_BAT"
sed -i "s/BAT1/$DETECTED_BAT/g" Apertura/Battery.qml

echo -e "${BLUE}[*]${RESET} Syncing Apertura core assets and helper scripts..."
# Force clear path boundaries to ensure target syncing is clean and non-nested
mkdir -p "$QUICKSHELL_DIR"
cp -r Apertura/. "$QUICKSHELL_DIR/"

# Ensure backend execution scripts have execution permissions mapped correctly
if [ -f "$QUICKSHELL_DIR/bluetooth_control.sh" ]; then
    echo -e "    ${GRAY}➔${RESET} Fixing permissions on bluetooth controller script..."
    chmod +x "$QUICKSHELL_DIR/bluetooth_control.sh"
fi

echo -e "${BLUE}[*]${RESET} Injecting configuration trees into hyprland.lua..."
touch "$HYPRLAND_LUA"

# Helper function to ensure safe appending without messing up missing trailing newlines
safe_append() {
    local file="$1"
    # If the file doesn't end with a newline, add one first
    if [ -s "$file" ] && [ "$(tail -c1 "$file" | wc -l)" -eq 0 ]; then
        echo "" >> "$file"
    fi
    cat >> "$file"
}

# 1. Inject the IPC toggle macro string if missing (strict match on Apertura)
if ! grep -q 'local menu = "qs -c Apertura ipc call launcher toggle"' "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding menu declaration macro..."
    echo 'local menu = "qs -c Apertura ipc call launcher toggle"' | safe_append "$HYPRLAND_LUA"
fi

# 2. Inject layer blur configurations if missing
if ! grep -q "quickshell-bar-blur" "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding bar layer rule hooks..."
    echo -e "\n-- Unique configuration for the bar layer\nhl.layer_rule({\n    name  = \"quickshell-bar-blur\",\n    match = { namespace = \"quickshell-bar\" },\n    blur  = true,\n    xray  = true,\n})\n\n-- Combined rule for all other components using regex matching\nhl.layer_rule({\n    name         = \"quickshell-components-blur\",\n    match        = { namespace = \"^quickshell-(overlay|wallpapers|launcher)$\" },\n    blur         = true,\n    xray         = true,\n    ignore_alpha = 0.5,\n})" | safe_append "$HYPRLAND_LUA"
fi

# 3. Inject satty window rule if missing
if ! grep -q "satty-screenshot-floating" "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding satty floating window rule..."
    echo -e "\nhl.window_rule({\n    name  = \"satty-screenshot-floating\",\n    match = { \n        class = \"com.gabm.satty\" \n    },\n    float = true,\n})" | safe_append "$HYPRLAND_LUA"
fi

# 4. Inject initializers hooks into startup blocks specifically for Apertura
if ! grep -q 'hl.exec_cmd("qs -c Apertura")' "$HYPRLAND_LUA"; then
    echo -e "    ${GRAY}➔${RESET} Adding startup daemon execution engine..."
    echo -e "\nhl.on(\"hyprland.start\", function ()\n  hl.exec_cmd(\"qs -c Apertura\")\n  hl.exec_cmd(\"awww-daemon\")\nend)" | safe_append "$HYPRLAND_LUA"
fi

echo -e "${BLUE}[*]${RESET} Booting underlying hardware service engines..."
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service

echo -e "${BLUE}[*]${RESET} Activating user space daemons..."
if command -v awww-daemon &>/dev/null; then
    pkill awww-daemon || true
    awww-daemon & disown
fi

# Build Matugen tracking ecosystem directly inside target layout directory
echo -e "${BLUE}[*]${RESET} Deploying color token architectures..."
mkdir -p "$QUICKSHELL_DIR/Colors"

# Initialize color generation engine and dump raw json payload straight to destination target
ACTIVE_WALLPAPER=$(ls -d "$WALLPAPER_DIR"/* 2>/dev/null | head -n 1 || echo "")
if [ -n "$ACTIVE_WALLPAPER" ] && command -v matugen &>/dev/null; then
    echo -e "${BLUE}[*]${RESET} Compiling dynamic JSON colorscheme via Matugen..."
    # Stream validated nested hex JSON structure cleanly matching the updated Theme.qml configuration
    matugen image "$ACTIVE_WALLPAPER" -m dark --source-color-index 0 --dry-run --json hex > "$QUICKSHELL_DIR/Colors/colors.json"
fi

echo ""
echo -e "${GREEN}[✓] Deployment finished successfully!${RESET}"
