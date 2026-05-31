#!/bin/bash
# 🎯 Hardened Bluetooth State, Control, and Discovery Engine (High-Performance Edition)

# Dynamic target configuration path tracking variables
ADAPTER_MAC=$(bluetoothctl show | grep "Controller" | awk '{print $2}')
CONFIG_PATH="/var/lib/bluetooth/${ADAPTER_MAC}"

case "$1" in
    "scan")
        bluetoothctl -t 8 scan on > /dev/null 2>&1
        ;;

    "paired")
        # Find currently active live connection channels cleanly
        declare -A connected_macs
        while read -r _ mac _; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                connected_macs["$(echo "$mac" | tr '[:upper:]' '[:lower:]')"]=1
            fi
        done < <(bluetoothctl devices Connected 2>/dev/null)

        # Build a unified map of explicitly Paired or Trusted devices
        declare -A remembered_profiles
        while read -r _ mac _; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                remembered_profiles["$(echo "$mac" | tr '[:upper:]' '[:lower:]')"]=1
            fi
        done < <(
            bluetoothctl devices Paired 2>/dev/null
            bluetoothctl devices Trusted 2>/dev/null
        )

        # Output remembered endpoints directly to the QML receiver
        bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [ -n "$name" ]; then
                lower_mac=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
                
                if [ -n "${remembered_profiles["$lower_mac"]}" ]; then
                    if [ -n "${connected_macs["$lower_mac"]}" ]; then
                        echo "$lower_mac|true|$name"
                    else
                        echo "$lower_mac|false|$name"
                    fi
                fi
            fi
        done
        ;;

    "discover")
        # Identify and isolate paired/trusted profiles to prevent duplicate listings
        declare -A local_profiles
        while read -r _ mac _; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                local_profiles["$(echo "$mac" | tr '[:upper:]' '[:lower:]')"]=1
            fi
        done < <(
            bluetoothctl devices Paired 2>/dev/null
            bluetoothctl devices Trusted 2>/dev/null
        )

        # Output cached and newly discovered background signals
        bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
            lower_mac=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
            if [[ "$lower_mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [ -z "${local_profiles["$lower_mac"]}" ] && [ -n "$name" ]; then
                echo "$lower_mac|$name"
            fi
        done
        ;;

    "toggle")
        STATUS=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')
        if [ "$STATUS" = "yes" ]; then
            bluetoothctl power off > /dev/null 2>&1
            echo '{"powered": false, "connected": false}'
        else
            bluetoothctl power on > /dev/null 2>&1
            sleep 0.2
            CONNECTED=$(bluetoothctl show 2>/dev/null | grep "Connected:" | awk '{print $2}')
            echo "{\"powered\": true, \"connected\": $([ "$CONNECTED" = "yes" ] && echo "true" || echo "false")}"
        fi
        ;;

    "status"|*)
        SHOW_OUT=$(bluetoothctl show 2>/dev/null)
        if [ -z "$SHOW_OUT" ]; then
            echo '{"powered": false, "connected": false}'
            exit 0
        fi
        POWERED=$(echo "$SHOW_OUT" | grep "Powered:" | awk '{print $2}')
        CONNECTED=$(echo "$SHOW_OUT" | grep "Connected:" | awk '{print $2}')
        VAL_POWER=$([ "$POWERED" = "yes" ] && echo "true" || echo "false")
        VAL_CONN=$([ "$CONNECTED" = "yes" ] && echo "true" || echo "false")
        echo "{\"powered\": ${VAL_POWER}, \"connected\": ${VAL_CONN}}"
        ;;
esac
