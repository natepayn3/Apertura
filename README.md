# Apertura

A sleek, hyper-responsive status bar framework built for Quickshell on Wayland (Layershell). 

Why "Apertura"? Because like a camera lens opening up to the light, this bar uses Hyprland's `xray` mechanics to slice through the desktop and expose the beautiful, hidden blur layers underneath. It's built for speed, clean aesthetics, and zero-compromise desktop configuration.

## 📦 System Dependencies

Your package manager must resolve the following dependencies to ensure core backend operations:

- quickshell — System shell orchestration platform.
- awww-git — Background wallpaper daemon.
- bluez & bluez-utils — Provides bluetoothctl for Bluetooth management.
- networkmanager — Provides nmcli for wireless network infrastructure.
- wireplumber — Provides wpctl for PipeWire audio routing.
- python — Execution environment for application indexing.

## 🚀 Installation & Deployment

An automated deployment script is included to handle dependencies, verify hardware endpoints, and hook into your display compositor setup.

    git clone https://github.com/natepayn3/Apertura.git
    cd Apertura
    chmod +x install.sh
    ./install.sh

### What the Installer Automates:
1. Dependency Verification: Installs required system packages via paru or yay if absent.
2. Dynamic Sysfs Profiling: Automatically detects your hardware's active battery node (e.g., BAT0 or BAT1) and fixes paths inline.
3. Hyprland Integration: Injects system daemon initializers (qs -c Apertura), keybind macros, and precise layer blur rules directly into your hyprland.lua:

-- Injected bar blur rule hook
hl.layer_rule({
    name  = "quickshell-bar-blur",
    match = { namespace = "quickshell-bar" },
    blur  = true,
    xray  = false,
})

## 💡 IPC Architecture

Once deployed, you can interact with or toggle the shell layout elements cleanly via the command line or desktop keybinds:

- Toggle Main Menu: qs -c Apertura ipc call launcher toggle
- Toggle Wallpapers: qs -c Apertura ipc call wallpaper toggle
