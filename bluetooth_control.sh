#!/bin/bash
# 🎯 Hardened Bluetooth State, Control, and Discovery Engine (High-Performance Edition)

case "$1" in
    "scan")
        bluetoothctl -t 8 scan on > /dev/null 2>&1
        ;;
    "paired")
        # 🎯 THE FIX: Uses 'devices' but filters strictly by 'Trusted: yes' to find bonded endpoints instantly
        bluetoothctl devices | while read -r _ mac name; do
            info=$(bluetoothctl info "$mac" 2>/dev/null)
            if echo "$info" | grep -q "Trusted: yes"; then
                conn=$(echo "$info" | grep -q "Connected: yes" && echo "true" || echo "false")
                echo "$mac|$conn|$name"
            fi
        done
        ;;
    "discover")
        # 🎯 THE FIX: Excludes trusted items so only new local signals land in the discover tab
        bluetoothctl devices | while read -r _ mac name; do
            if ! bluetoothctl info "$mac" 2>/dev/null | grep -q "Trusted: yes"; then
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