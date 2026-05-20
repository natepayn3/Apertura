#!/usr/bin/env python3
import os
import json
import shutil
from xdg.DesktopEntry import DesktopEntry
from xdg.IconTheme import getIconPath

def get_desktop_files():
    search_dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/share/applications"
    ]
    
    apps = []
    seen_bins = set()

    for data_dir in search_dirs:
        if not os.path.exists(data_dir):
            continue
            
        for filename in os.listdir(data_dir):
            if not filename.endswith(".desktop"):
                continue
                
            file_path = os.path.join(data_dir, filename)
            try:
                entry = DesktopEntry(file_path)
                
                if entry.getNoDisplay() or entry.getHidden():
                    continue
                    
                name = entry.getName()
                
                # 🎯 FIX: Get the clean executable name without %U, %f, etc.
                # entry.getTryExec() returns just the core binary name (e.g., "remmina")
                binary = entry.getTryExec() or entry.getExec().split()[0]
                binary = binary.replace('"', '').replace("'", "").strip()
                
                # Verify the binary actually exists in your $PATH before adding it
                if not shutil.which(binary):
                    continue
                    
                raw_icon = entry.getIcon()
                
                if name and binary:
                    resolved_icon = ""
                    if raw_icon:
                        if os.path.isabs(raw_icon):
                            resolved_icon = raw_icon
                        else:
                            resolved_icon = getIconPath(raw_icon, size=32) or ""
                    
                    if binary not in seen_bins:
                        seen_bins.add(binary)
                        apps.append({
                            "name": name,
                            "bin": binary,
                            "icon": resolved_icon
                        })
            except Exception:
                pass
                
    apps.sort(key=lambda x: x["name"].lower())
    return json.dumps(apps)

if __name__ == "__main__":
    print(get_desktop_files())