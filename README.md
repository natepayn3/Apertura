> [!WARNING]  
> _This framework is currently in active development and has not been fully tested across all system hardware configurations yet. Proceed with caution!_

***

<img width="600" height="100" alt="image" src="https://github.com/user-attachments/assets/2acb41ab-1842-40b9-9e7a-86976955c11f" />

A sleek and responsive shell built for Quickshell on Hyprland.

Why "Apertura"? Because like a camera lens opening up to the light, this bar uses Hyprland's xray mechanics to slice through the desktop and expose the beautiful, hidden blur layers underneath. It's built for speed, clean aesthetics, and zero-compromise desktop configuration.

## 📦 What this is and is not

This is a desktop shell, not a full system manager.  There is no settings gui for configuration.  Any changes to this config will require editing the qml files manually.  These files have not been extensively tested on multiple distros/configs, so please proceed with caution.  If you have a good grasp of Hyprland and Linux basics, you should be able to customize this without much trouble.  Please do not contact me for help customizing your unique environment.

Toggles are listed below for you to add custom keybinds if you wish, but these are not set automatically during install.

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
