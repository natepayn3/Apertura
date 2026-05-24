#!/bin/bash
# 🎯 Hardened Bluetooth State, Control, and Discovery Engine (High-Performance Edition)

case "$1" in
    "scan")
        bluetoothctl -t 8 scan on > /dev/null 2>&1
        ;;

    "paired")
        # 🎯 THE FIX: Verify column 2 is an actual MAC address before outputting
        bluetoothctl paired-devices | while read -r _ mac name; do
            # Ensure mac string matches standard hexadecimal byte formatting bounds
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                info=$(bluetoothctl info "$mac" 2>/dev/null)
                if echo "$info" | grep -q "Connected: yes"; then
                    echo "$mac|true|$name"
                else
                    echo "$mac|false|$name"
                fi
            fi
        done
        ;;

    "discover")
        declare -A paired_macs
        while read -r _ mac _; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                paired_macs["$mac"]=1
            fi
        done < <(bluetoothctl paired-devices 2>/dev/null)

        bluetoothctl devices | while read -r _ mac name; do
            if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [ -z "${paired_macs["$mac"]}" ] && [ -n "$name" ]; then
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
