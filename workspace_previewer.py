#!/usr/bin/env python3
import subprocess
import json
import os
import sys

def get_workspace_layout(ws_id):
    try:
        # Grab active window properties from Hyprland IPC
        clients_raw = subprocess.check_output(["hyprctl", "clients", "-j"])
        clients = json.loads(clients_raw)
        
        # Grab monitor dimensions to handle proportional scaling calculations
        monitors_raw = subprocess.check_output(["hyprctl", "monitors", "-j"])
        monitors = json.loads(monitors_raw)
    except Exception:
        return json.dumps([])

    # Find the monitor bound to this workspace (default to first monitor if multi-head logic drops)
    monitor = monitors[0]
    for m in monitors:
        if m["activeWorkspace"]["id"] == ws_id:
            monitor = m
            break
            
    m_w = monitor["width"]
    m_h = monitor["height"]

    layout_windows = []
    for client in clients:
        if client["workspace"]["id"] == int(ws_id):
            # Extract geometry bounding coordinates
            x, y = client["at"]
            w, h = client["size"]
            
            # Skip floating panels or zero-size ghost artifacts
            if w <= 0 or h <= 0:
                continue
                
            # Normalize coordinates relative to the specific monitor canvas viewport
            rel_x = x - monitor["x"]
            rel_y = y - monitor["y"]

            layout_windows.append({
                "title": client["title"],
                "class": client["class"],
                "is_focused": client["focusHistoryID"] == 0,
                # Convert to percentages (0.0 to 1.0) so QML can scale it to any thumbnail size
                "x_pct": max(0.0, min(1.0, rel_x / m_w)),
                "y_pct": max(0.0, min(1.0, rel_y / m_h)),
                "w_pct": max(0.0, min(1.0, w / m_w)),
                "h_pct": max(0.0, min(1.0, h / m_h))
            })
            
    return json.dumps(layout_windows)

if __name__ == "__main__":
    target_ws = sys.argv[1] if len(sys.argv) > 1 else "1"
    print(get_workspace_layout(target_ws))