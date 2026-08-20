#!/usr/bin/env python3
"""
Cross-platform build & release manager for tch-nginx-gui.
Handles:
  1. Version determination (manual from commit msg / env, or auto-increment from latest.version)
  2. Setting version in rootdevice
  3. Generating checksum files for LED framework
  4. Packaging modular tar.bz2 archives
  5. Assembling total distribution and packaging GUI.tar.bz2 / GUI_dev.tar.bz2
  6. Updating version metadata files in gui-dev-build-auto
"""

import os
import sys
import re
import shutil
import tarfile
import hashlib
import subprocess
from pathlib import Path

def md5_file(filepath):
    h = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def make_tar_bz2(source_dir, output_filename):
    with tarfile.open(output_filename, "w:bz2") as tar:
        for item in sorted(os.listdir(source_dir)):
            item_path = os.path.join(source_dir, item)
            tar.add(item_path, arcname=item)

def get_git_info(repo_dir):
    try:
        short_sha = subprocess.check_output(
            ["git", "-C", str(repo_dir), "log", "-1", "--format=%h"],
            text=True
        ).strip()
        last_msg = subprocess.check_output(
            ["git", "-C", str(repo_dir), "log", "-1", "--format=%B"],
            text=True
        ).strip()
    except Exception:
        short_sha = "unknown"
        last_msg = ""
    return short_sha, last_msg

def calculate_version(last_msg, latest_version_file, manual_ver=None):
    # 1. Explicit override passed as argument or env
    if manual_ver:
        return manual_ver.strip()
    
    # 2. Check for [x.y.z] in commit message
    match = re.search(r'\[([0-9]+\.[0-9]+\.[0-9]+)\]', last_msg)
    if match:
        print(f"Detected version tag in commit message: {match.group(1)}")
        return match.group(1)

    # 3. Auto-increment from latest.version
    cur_ver = "9.7.8"
    if latest_version_file.exists():
        try:
            content = latest_version_file.read_text().strip()
            if re.match(r'^[0-9]+\.[0-9]+\.[0-9]+$', content):
                cur_ver = content
        except Exception:
            pass

    parts = cur_ver.split(".")
    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])
    
    patch += 1
    if patch > 99:
        patch = 0
        minor += 1
        if minor > 99:
            minor = 0
            major += 1

    new_ver = f"{major}.{minor}.{patch}"
    print(f"Auto-incrementing version: {cur_ver} -> {new_ver}")
    return new_ver

def main():
    src_dir = Path(__file__).resolve().parent.parent
    
    # Check if build destination path passed as argument or default to adjacent folder
    if len(sys.argv) > 1 and Path(sys.argv[1]).exists():
        dest_dir = Path(sys.argv[1]).resolve()
    else:
        dest_dir = src_dir.parent / "gui-dev-build-auto"
        if not dest_dir.exists():
            dest_dir.mkdir(parents=True, exist_ok=True)

    manual_ver = os.environ.get("CUSTOM_VERSION", None)

    print(f"Source Directory:      {src_dir}")
    print(f"Destination Directory: {dest_dir}")

    short_sha, last_msg = get_git_info(src_dir)
    version = calculate_version(last_msg, dest_dir / "latest.version", manual_ver)

    # 1. Update version in rootdevice
    rootdevice = src_dir / "decompressed" / "base" / "etc" / "init.d" / "rootdevice"
    if rootdevice.exists():
        content = rootdevice.read_text(encoding="utf-8")
        updated = re.sub(r'version_gui=.*', f'version_gui={version}-{short_sha}', content)
        rootdevice.write_text(updated, encoding="utf-8")
        print(f"Updated rootdevice: version_gui={version}-{short_sha}")

    # 2. Checksum files
    status_led = src_dir / "decompressed" / "gui_file" / "tmp" / "status-led-eventing.lua_new"
    if status_led.exists():
        md5_val = md5_file(status_led)
        (src_dir / "decompressed" / "gui_file" / "tmp" / "status-led-eventing.md5sum").write_text(
            f"{md5_val}  tmp/status-led-eventing.lua_new\n"
        )

    modular_dirs = [
        "base", "gui_file", "traffic_mon",
        "upgrade-pack-specificDGA", "upgrade-pack-specificTG800",
        "upgrade-pack-specificTG789", "upgrade-pack-specificTG789Xtream35B",
        "telstra_gui", "ledfw_support-specificTG788", "ledfw_support-specificTG789",
        "ledfw_support-specificTG799", "ledfw_support-specificTG800",
        "ledfw_support-specificDGA", "ledfw_support-specificDGA4131"
    ]

    for mod in modular_dirs:
        if "ledfw_support" in mod:
            sm = src_dir / "decompressed" / mod / "etc" / "ledfw" / "stateMachines.lua"
            if sm.exists():
                md5_val = md5_file(sm)
                (src_dir / "decompressed" / mod / "stateMachines.md5sum").write_text(
                    f"{md5_val}  etc/ledfw/stateMachines.lua\n"
                )

    # 3. Packaging modular packages
    modular_dest = dest_dir / "modular"
    modular_dest.mkdir(parents=True, exist_ok=True)

    for mod in modular_dirs:
        mod_src = src_dir / "decompressed" / mod
        if mod_src.exists():
            out_tar = modular_dest / f"{mod}.tar.bz2"
            print(f"Packaging modular: {mod} -> {out_tar.name}")
            make_tar_bz2(str(mod_src), str(out_tar))

    # 4. Assembling total GUI
    total_dir = src_dir / "total"
    if total_dir.exists():
        shutil.rmtree(total_dir)
    total_dir.mkdir()

    for mod in ["base", "gui_file", "traffic_mon"]:
        mod_src = src_dir / "decompressed" / mod
        for root, dirs, files in os.walk(mod_src):
            rel = Path(root).relative_to(mod_src)
            d_dest = total_dir / rel
            d_dest.mkdir(parents=True, exist_ok=True)
            for f in files:
                shutil.copy2(Path(root) / f, d_dest / f)

    tmp_dir = total_dir / "tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    for mod in modular_dirs:
        if not mod.startswith("upgrade-pack-"):
            mod_tar = modular_dest / f"{mod}.tar.bz2"
            if mod_tar.exists():
                shutil.copy2(mod_tar, tmp_dir / f"{mod}.tar.bz2")

    gui_tar = dest_dir / "GUI.tar.bz2"
    gui_dev_tar = dest_dir / "GUI_dev.tar.bz2"

    print("Packaging main GUI.tar.bz2 and GUI_dev.tar.bz2...")
    make_tar_bz2(str(total_dir), str(gui_tar))
    shutil.copy2(gui_tar, gui_dev_tar)

    shutil.rmtree(total_dir)

    # 5. Update version files in destination
    gui_md5 = md5_file(gui_tar)
    (dest_dir / "latest.version").write_text(f"{version}\n")
    (dest_dir / "stable.version").write_text(f"{version}\n")
    (dest_dir / "preview.version").write_text(f"{version}\n")

    v_file = dest_dir / "version"
    existing = v_file.read_text() if v_file.exists() else ""
    v_file.write_text(f"{gui_md5} {version}\n" + existing)

    print(f"\nSuccessfully built release v{version} (MD5: {gui_md5})!")

if __name__ == "__main__":
    main()
