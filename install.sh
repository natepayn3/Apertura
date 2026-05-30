#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Target deployment paths
QUICKSHELL_DIR="$HOME/.config/quickshell/Apertura"
HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# ANSI Escape Codes for terminal styling
🔵='\033[0;34m'
⚪='\033[0;37m'
⚫='\033[1;30m'
🟢='\033[0;32m'
❌_COLOR='\033[0;31m'
🏁='\033[0m'

# Clear screen and blast the block capital banner
clear
echo -e "${🔵}    _   ____  _____ ____ _____ _   _ ____    _    "
echo -e "   / \  |  _ \| ____|  _ \_   _| | | |  _ \  / \   "
echo -e "  / _ \ | |_) |  _| | |_) || | | | | | |_) |/ _ \  "
echo -e " / ___ \|  __/| |___|  _ < | | | |_| |  _ <___  | "
echo -e "/_/   \_\_|   |_____|_| \_\|_|  \___/|_| \_\  |_| ${🏁}"
echo -e "${⚫}────────────────────────────────────────────────────────────${🏁}"
echo -e "               ${⚪}Apertura Core Bar Deployment Module${🏁}"
echo -e "${⚫}────────────────────────────────────────────────────────────${🏁}"
echo ""

echo -e "${🔵}[*]${🏁} Updating system repositories and checking dependencies..."
DEPENDENCIES=(
    "quickshell"
    "awww-git"
    "bluez"
    "bluez-utils"              # Provides 'bluetoothctl' binary used by Bluetooth.qml
    "networkmanager"           # Provides 'nmcli' binary used by Wifi.qml
    "python"                   # Provides 'python3' interpreter used by AppLauncher.qml
    "wireplumber"              # Provides 'wpctl' used by Audio.qml & VolumeHud
    "ttf-material-design-icons-git" # Maps \uE050 style system glyphs cleanly
    "ttf-nerd-fonts-symbols"   # Font tracking backbone fallback for 󰂱 and 󱐋 shapes
)

for pkg in "${DEPENDENCIES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        echo -e "    ${⚫}➔${🏁} Installing $pkg..."
        if command -v paru &>/dev/null; then
            paru -S --noconfirm "$pkg"
        elif command -v yay &>/dev/null; then
            yay -S --noconfirm "$pkg"
        else
            echo -e "${❌_COLOR}[X] Error:${🏁} Neither paru nor yay found. Please install $pkg manually."
            exit 1
        fi
    fi
done

echo -e "${🔵}[*]${🏁} Setting up local deployment directories..."
mkdir -p "$HOME/.config/quickshell"

# Create the hardcoded system asset path for background images if missing
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo -e "    ${⚫}➔${🏁} Creating missing wallpaper destination: $WALLPAPER_DIR"
    mkdir -p "$WALLPAPER_DIR"
fi

# Atomic repository management pointing to your public Git path
if [ -d "Apertura" ]; then
    echo -e "    ${⚫}➔${🏁} Updating existing local repository directory..."
    cd Apertura && git pull && cd ..
else
    echo -e "    ${⚫}➔${🏁} Cloning Apertura repository..."
    git clone https://github.com/natepayn3/Apertura.git
fi

# Dynamic battery sysfs routing locator
DETECTED_BAT=$(basename $(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1) 2>/dev/null || echo "BAT1")
echo -e "    ${⚫}➔${🏁} Mapping battery target identifier node to: $DETECTED_BAT"
sed -i "s/BAT1/$DETECTED_BAT/g" Apertura/Battery.qml

echo -e "${🔵}[*]${🏁} Syncing Apertura core assets and helper scripts..."
cp -r Apertura "$QUICKSHELL_DIR"

# Ensure backend execution scripts have execution permissions mapped correctly
if [ -f "$QUICKSHELL_DIR/bluetooth_control.sh" ]; then
    echo -e "    ${⚫}➔${🏁} Fixing permissions on bluetooth controller script..."
    chmod +x "$QUICKSHELL_DIR/bluetooth_control.sh"
fi

echo -e "${🔵}[*]${🏁} Injecting configuration trees into hyprland.lua..."
touch "$HYPRLAND_LUA"

# 1. Inject the IPC toggle macro string if missing
if ! grep -q "local menu = \"qs -c Apertura ipc call launcher toggle\"" "$HYPRLAND_LUA"; then
    echo -e "    ${⚫}➔${🏁} Adding menu declaration macro..."
    echo 'local menu = "qs -c Apertura ipc call launcher toggle"' >> "$HYPRLAND_LUA"
fi

# 2. Inject layer blur configurations if missing
if ! grep -q "quickshell-bar-blur" "$HYPRLAND_LUA"; then
    echo -e "    ${⚫}➔${🏁} Adding bar layer rule hooks..."
    cat << 'EOF' >> "$HYPRLAND_LUA"

-- Unique configuration for the bar layer
hl.layer_rule({
    name  = "quickshell-bar-blur",
    match = { namespace = "quickshell-bar" },
    blur  = true,
    xray  = false,
})

-- Combined rule for all other components using regex matching
hl.layer_rule({
    name         = "quickshell-components-blur",
    match        = { namespace = "^quickshell-(overlay|wallpapers|launcher)$" },
    blur         = true,
    xray         = true,
    ignore_alpha = 0.5,
})
EOF
fi

# 3. Inject initializers hooks into startup blocks
if ! grep -q "qs -c Apertura" "$HYPRLAND_LUA"; then
    echo -e "    ${⚫}➔${🏁} Adding startup daemon execution engine..."
    cat << 'EOF' >> "$HYPRLAND_LUA"

hl.on("hyprland.start", function () 
  hl.exec_cmd("qs -c Apertura")
  hl.exec_cmd("awww-daemon")
end)
EOF
fi

echo -e "${🔵}[*]${🏁} Booting underlying hardware service engines..."
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service

echo -e "${🔵}[*]${🏁} Activating user space daemons..."
if command -v awww-daemon &>/dev/null; then
    pkill awww-daemon || true
    awww-daemon & disown
fi

echo ""
echo -e "${🟢}[✓] Deployment finished successfully! Environment layout is uniform and operational.${🏁}"
