#!/usr/bin/env bash

# Capture current activation state from the environment parameters
STATE="$1"
TARGET_PROFILE="$2"

# Sanitize the input profile string to strip any unexpected whitespaces
TARGET_PROFILE=$(echo "$TARGET_PROFILE" | tr -d '\r' | xargs)

# 1. Handle Disconnection Sequence
if [ "$STATE" = "true" ]; then
    if [ -n "$TARGET_PROFILE" ]; then
        # Matches your successful terminal deactivation command
        nmcli connection down id "$TARGET_PROFILE"
    else
        # Dynamic fallback: find ANY running wireguard/vpn profile and bring it down
        ACTIVE_PROFILE=$(nmcli -t -f TYPE,NAME connection show --active | grep -E '^(wireguard|vpn|tun):' | head -n 1 | cut -d: -f2)
        if [ -n "$ACTIVE_PROFILE" ]; then
            nmcli connection down id "$ACTIVE_PROFILE"
        fi
    fi
    exit 0
fi

# 2. Handle Connection Sequence (Only runs if STATE is "false")
if [ -n "$TARGET_PROFILE" ]; then
    # Matches your successful terminal activation command
    nmcli connection up id "$TARGET_PROFILE"
else
    # Dynamic fallback: grab the first available wireguard configuration profile name on the system
    NM_PROFILE=$(nmcli -t -f TYPE,NAME connection show | grep -E '^(wireguard|vpn|tun):' | head -n 1 | cut -d: -f2)
    if [ -n "$NM_PROFILE" ]; then
        nmcli connection up id "$NM_PROFILE"
    else
        echo "Error: No configured NetworkManager VPN or WireGuard profiles found." >&2
        exit 1
    fi
fi