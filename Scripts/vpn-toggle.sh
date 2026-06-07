#!/usr/bin/env bash

# Capture current activation state from the environment parameters
STATE="$1"
TARGET_PROFILE="$2"

# Sanitize the input profile string to strip any unexpected whitespaces
TARGET_PROFILE=$(echo "$TARGET_PROFILE" | tr -d '\r' | xargs)

# 1. Handle Disconnection Sequence
if [ "$STATE" = "true" ]; then
    if [ -n "$TARGET_PROFILE" ]; then
        if nmcli connection down id "$TARGET_PROFILE"; then
            notify-send -a "VPN Manager" -i "network-vpn-disabled" "VPN Disconnected" "The secure tunnel connection has been closed."
        fi
    else
        ACTIVE_PROFILE=$(nmcli -t -f TYPE,NAME connection show --active | grep -E '^(wireguard|vpn|tun):' | head -n 1 | cut -d: -f2)
        if [ -n "$ACTIVE_PROFILE" ]; then
            if nmcli connection down id "$ACTIVE_PROFILE"; then
                notify-send -a "VPN Manager" -i "network-vpn-disabled" "VPN Disconnected" "The secure tunnel connection has been closed."
            fi
        fi
    fi
    exit 0
fi

# 2. Handle Connection Sequence (Only runs if STATE is "false")
if [ -n "$TARGET_PROFILE" ]; then
    if nmcli connection up id "$TARGET_PROFILE"; then
        notify-send -a "VPN Manager" -i "network-vpn" "VPN Connected" "Secure tunnel established successfully."
    fi
else
    NM_PROFILE=$(nmcli -t -f TYPE,NAME connection show | grep -E '^(wireguard|vpn|tun):' | head -n 1 | cut -d: -f2)
    if [ -n "$NM_PROFILE" ]; then
        if nmcli connection up id "$NM_PROFILE"; then
            notify-send -a "VPN Manager" -i "network-vpn" "VPN Connected" "Secure tunnel established successfully."
        fi
    else
        echo "Error: No configured NetworkManager VPN or WireGuard profiles found." >&2
        exit 1
    fi
fi
