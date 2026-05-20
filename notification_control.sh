#!/bin/bash
# 🎯 SwayNC Native Data Stream Bridge

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

case "$1" in
    "count")
        # Natively fetches just the numerical unread message queue ceiling
        swaync-client -c 2>/dev/null || echo "0"
        ;;
    "toggle")
        # Direct CLI toggle call to slide open the main GTK GUI Control Center panel
        swaync-client -t -sw >/dev/null 2>&1
        ;;
    "dismiss")
        # Instantly flushes the active notification daemon cache stack
        swaync-client -C >/dev/null 2>&1
        ;;
esac