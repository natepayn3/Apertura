#!/bin/bash
# 🎯 Hardened Bluetooth State, Control, and Discovery Engine (High-Performance Edition)

# Find active local adapter MAC address dynamically to target configuration paths
ADAPTER_MAC=$(bluetoothctl show | grep "Controller" | awk '{print $2}')
CONFIG_PATH="/var/lib/bluetooth/${ADAPTER_MAC}"

case "$1" in
    "scan")
        bluetoothctl -t 8 scan on > /dev/null 2>&1
        ;;

    "paired")
        # 🎯 THE FIX: Track only explicitly paired configurations found in the BlueZ directory database
        declare -A local_profiles
        if [ -d "$CONFIG_PATH" ]; then
            for dir in "$CONFIG_PATH"/*/; do
                mac=$(basename "$dir")
                if [[ "$mac" =~ ^([0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}$ ]]; then
                    # Convert folder names (00_00_00...) back to standard BlueZ mac signatures
                    formatted_mac=$(echo "$mac" | tr '_' ':')
                    local_profiles["$formatted_mac"]=1
                fi
            done
        fi

        # Find currently active live connection channels
        declare -A connected_macs
        while read -r _ mac _; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                connected_macs["$mac"]=1
            fi
        done < <(bluetoothctl devices Connected 2>/dev/null)

        # Output only your configured endpoints
        bluetoothctl devices | while read -r _ mac name; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [ -n "${local_profiles["$mac"]}" ]; then
                if [ -n "${connected_macs["$mac"]}" ]; then
                    echo "$mac|true|$name"
                else
                    echo "$mac|false|$name"
                fi
            fi
        done
        ;;

    "discover")
        # 🎯 THE FIX: Filter configured items out of the live background cache matrix
        declare -A local_profiles
        if [ -d "$CONFIG_PATH" ]; then
            for dir in "$CONFIG_PATH"/*/; do
                mac=$(basename "$dir")
                if [[ "$mac" =~ ^([0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}$ ]]; then
                    formatted_mac=$(echo "$mac" | tr '_' ':')
                    local_profiles["$formatted_mac"]=1
                fi
            done
        fi

        bluetoothctl devices | while read -r _ mac name; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [ -z "${local_profiles["$mac"]}" ] && [ -n "$name" ]; then
                echo "$mac|$name"
            fi
        done
        ;;

    "toggle")
        STATUS=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
        if [ "$STATUS" = "yes" ]; then
            bluetoothctl power off > /dev/null 2>&1
            echo '{"powered": false, "connected": false}'
        else
            bluetoothctl power on > /dev/null 2>&1
            sleep 0.2
            CONNECTED=$(bluetoothctl show | grep "Connected:" | awk '{print $2}')
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
