> [!WARNING]  
> _This framework is currently in active development and has not been fully tested across all system hardware configurations yet. Proceed with caution!_

***

<div align="center">
 
  <h1>
    <img width="50" height="50" alt="Apertura Logo" src="https://github.com/user-attachments/assets/d7f6dbd6-895d-40c7-8a8e-bf28352a16b1" style="display: inline; vertical-align: middle; margin-right: 10px; padding-bottom: 4px;" />
    <span style="font-family: 'Rubik', system-ui, -apple-system, sans-serif; font-weight: 800; font-size: 50px; color: #ffffff; letter-spacing: -1px; vertical-align: middle;">Apertura</span>
  </h1>
  
  <p align="center" style="margin-top: 10px; margin-bottom: 15px;">
    <span style="font-size: 16px; color: #a3a8ce; font-family: system-ui, -apple-system, sans-serif;">A sleek and responsive shell built for Quickshell on Hyprland.</span>
  </p>
  
  <p align="center">
    <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch Linux" /></a>&nbsp;
    <a href="https://hyprland.org"><img src="https://img.shields.io/badge/Hyprland-33CCFF?style=for-the-badge&logo=hyprland&logoColor=white" alt="Hyprland" /></a>&nbsp;
    <a href="https://github.com/outfoxxed/quickshell"><img src="https://img.shields.io/badge/Quickshell-41CD52?style=for-the-badge&logo=qt&logoColor=white" alt="Quickshell" /></a>
  </p>
  <br>
</div>

<img width="1920" height="1080" alt="01" src="https://github.com/user-attachments/assets/d07e79dd-5d86-47cc-9d0a-61b7adcdfb6e" />

<img width="1920" height="1080" alt="02" src="https://github.com/user-attachments/assets/d2733138-4d1a-4b11-8626-56b320d3902d" />

A sleek and responsive shell built for Quickshell on Hyprland.

Why "Apertura"? Because like a camera lens or "aperture" opening up to the light, this bar uses Hyprland's xray mechanics to slice through the desktop and expose the beautiful, hidden blur layers underneath. It's built for speed, clean aesthetics, and zero-compromise desktop configuration.

### What this is and is not

This is a desktop shell, not a full system manager.  There is no settings gui for configuration.  Any changes to this config will require editing the qml files manually.  These files have not been extensively tested on multiple distros/configs, so please proceed with caution.  If you have a good grasp of Hyprland and Linux basics, you should be able to customize this without much trouble.  Please do not contact me for help customizing your unique environment.

This shell is minimal in nature, containing everything you need to operate your system but not necessarily everything you might want.  Please consider making feature requests for what you would like to see!

Toggles are listed below for you to add custom keybinds if you wish, but these are not set automatically during install.

#### This shell assumes you're using the newer Hyprland lua config!

### System Dependencies

Your package manager must resolve the following dependencies to ensure core backend operations:

- quickshell — System shell orchestration platform.
- awww-git — Background wallpaper daemon.
- bluez & bluez-utils — Provides bluetoothctl for Bluetooth management.
- networkmanager — Provides nmcli for wireless network infrastructure.
- wireplumber — Provides wpctl for PipeWire audio routing.
- python — Execution environment for application indexing.

## Installation & Deployment

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

### IPC Architecture

Once deployed, you can interact with or toggle the shell layout elements cleanly via the command line or desktop keybinds:

- Toggle Main Menu: qs -c Apertura ipc call launcher toggle
- Toggle Wallpapers: qs -c Apertura ipc call wallpaper toggle
