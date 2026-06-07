#!/usr/bin/env python3
import os
import json
import shutil
import re
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
                raw_exec = entry.getExec()
                
                if not raw_exec:
                    continue

                # 🧼 Clean standard field descriptors (%u, %F, etc.) out of the execution string
                clean_exec = re.sub(r'%[fFuUnNdDsSkKmM]', '', raw_exec).strip()
                
                # Extract the primary binary descriptor for validation
                # Handles both quoted and unquoted absolute system execution paths safely
                parts = clean_exec.split()
                if not parts:
                    continue
                    
                base_binary = parts[0].replace('"', '').replace("'", "")
                
                # Validate that the system can see the underlying executable path
                if not shutil.which(base_binary):
                    continue
                    
                raw_icon = entry.getIcon()
                
                if name and clean_exec:
                    resolved_icon = ""
                    if raw_icon:
                        if os.path.isabs(raw_icon):
                            resolved_icon = raw_icon
                        else:
                            resolved_icon = getIconPath(raw_icon, size=32) or ""
                    
                    # Track uniqueness against full execution paths to allow distinct Chrome profiles/apps
                    if clean_exec not in seen_bins:
                        seen_bins.add(clean_exec)
                        apps.append({
                            "name": name,
                            "bin": clean_exec,
                            "icon": resolved_icon
                        })
            except Exception:
                pass
                
    apps.sort(key=lambda x: x["name"].lower())
    return json.dumps(apps)

if __name__ == "__main__":
    print(get_desktop_files())
