#!/usr/bin/env python3
"""
Cross-platform build & release manager for tch-nginx-gui.
Supports:
  - Stable releases (default)
  - Preview releases (triggered by '[preview]' in commit message, --channel preview, or RELEASE_CHANNEL=preview)
"""

import os
import sys
import re
import time
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

def sanitize_text_files_lf(target_dir):
    text_extensions = {
        ".sh", ".lua", ".lp", ".map", ".po", ".js", ".css",
        ".json", ".md", ".conf", ".rules", ".txt", ".version", ".include"
    }
    special_dirs = {"init.d", "hotplug.d", "modgui_scripts", "scripts", "transfers"}
    for root, _, files in os.walk(target_dir):
        r_path = Path(root)
        is_special_dir = any(s in r_path.parts for s in special_dirs)
        for f in files:
            p = r_path / f
            if p.suffix.lower() in text_extensions or is_special_dir:
                try:
                    raw = p.read_bytes()
                    if b"\r\n" in raw:
                        p.write_bytes(raw.replace(b"\r\n", b"\n"))
                except Exception:
                    pass

def _tar_filter(tarinfo):
    tarinfo.uid = 0
    tarinfo.gid = 0
    tarinfo.uname = "root"
    tarinfo.gname = "root"
    tarinfo.mtime = 1514764800
    return tarinfo

def make_tar_bz2(source_dir, output_filename):
    with tarfile.open(output_filename, "w:bz2") as tar:
        for item in sorted(os.listdir(source_dir)):
            item_path = os.path.join(source_dir, item)
            tar.add(item_path, arcname=item, filter=_tar_filter)

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

def detect_channel(last_msg, cli_channel=None):
    if cli_channel:
        return cli_channel.lower()
    env_chan = os.environ.get("RELEASE_CHANNEL", "").lower()
    if env_chan in ["preview", "stable"]:
        return env_chan
    # Check for [preview] or preview in commit message
    if re.search(r'\[preview\]', last_msg, re.IGNORECASE) or "preview" in last_msg.lower():
        return "preview"
    return "stable"

def parse_ver_tuple(ver_str):
    m = re.search(r'(\d+)\.(\d+)\.(\d+)', str(ver_str))
    if m:
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)))
    return (0, 0, 0)

def ver_tuple_to_str(v_tuple):
    return f"{v_tuple[0]}.{v_tuple[1]}.{v_tuple[2]}"

def find_highest_version(src_dir, dest_dir):
    candidates = []
    
    # 1. From git tags in tch-nginx-gui
    try:
        tags_out = subprocess.check_output(
            ["git", "-C", str(src_dir), "tag", "-l", "v*"],
            text=True
        ).strip().splitlines()
        for t in tags_out:
            candidates.append(parse_ver_tuple(t))
    except Exception:
        pass

    # 2. From stable.version, preview.version, latest.version in dest_dir
    for f in ["stable.version", "preview.version", "latest.version"]:
        p = dest_dir / f
        if p.exists():
            try:
                candidates.append(parse_ver_tuple(p.read_text().strip()))
            except Exception:
                pass

    # 3. From version file in dest_dir
    v_file = dest_dir / "version"
    if v_file.exists():
        try:
            for line in v_file.read_text().splitlines():
                if line.strip():
                    candidates.append(parse_ver_tuple(line))
        except Exception:
            pass

    if not candidates:
        return (9, 7, 50)
    
    highest = max(candidates)
    if highest == (0, 0, 0):
        return (9, 7, 50)
    return highest

def calculate_version(last_msg, src_dir, dest_dir, manual_ver=None):
    if manual_ver:
        return manual_ver.strip()
    
    match = re.search(r'\[([0-9]+\.[0-9]+\.[0-9]+)\]', last_msg)
    if match:
        print(f"Detected version tag in commit message: {match.group(1)}")
        return match.group(1)

    highest_tuple = find_highest_version(src_dir, dest_dir)
    major, minor, patch = highest_tuple
    
    patch += 1
    if patch > 99:
        patch = 0
        minor += 1
        if minor > 99:
            minor = 0
            major += 1

    new_ver = f"{major}.{minor}.{patch}"
    print(f"Detected highest existing version across repositories: {ver_tuple_to_str(highest_tuple)} -> Auto-incrementing to: {new_ver}")
    return new_ver

def main():
    src_dir = Path(__file__).resolve().parent.parent
    dest_dir = src_dir.parent / "gui-dev-build-auto"
    cli_channel = None
    manual_ver = os.environ.get("CUSTOM_VERSION", None)

    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--channel" and i + 1 < len(sys.argv):
            cli_channel = sys.argv[i + 1]
            i += 2
            continue
        elif arg.startswith("--channel="):
            cli_channel = arg.split("=", 1)[1]
        elif re.match(r'^[0-9]+\.[0-9]+\.[0-9]+', arg):
            manual_ver = arg
        elif arg.lower() in ["preview", "stable"]:
            cli_channel = arg.lower()
        elif not arg.startswith("-"):
            p = Path(arg)
            if p.is_dir() or "build" in arg or "gui" in arg:
                dest_dir = p.resolve()
        i += 1

    dest_dir.mkdir(parents=True, exist_ok=True)

    short_sha, last_msg = get_git_info(src_dir)
    channel = detect_channel(last_msg, cli_channel)

    print(f"Source Directory:      {src_dir}")
    print(f"Destination Directory: {dest_dir}")
    print(f"Target Channel:        {channel.upper()}")

    version = calculate_version(last_msg, src_dir, dest_dir, manual_ver)

    # 1. Sanitize line endings to LF across all source text files
    sanitize_text_files_lf(src_dir / "decompressed")

    # 2. Update version in rootdevice
    rootdevice = src_dir / "decompressed" / "base" / "etc" / "init.d" / "rootdevice"
    if rootdevice.exists():
        content = rootdevice.read_text(encoding="utf-8")
        updated = re.sub(r'version_gui=.*', f'version_gui={version}-{short_sha}', content)
        rootdevice.write_text(updated, encoding="utf-8")
        print(f"Updated rootdevice: version_gui={version}-{short_sha}")

    # 3. Checksums
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
        for _ in range(5):
            try:
                shutil.rmtree(total_dir)
                break
            except Exception:
                time.sleep(0.5)
    total_dir.mkdir(exist_ok=True)

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

    # 5. Packaging tarballs according to channel
    gui_preview_tar = dest_dir / "GUI_preview.tar.bz2"
    gui_stable_tar = dest_dir / "GUI.tar.bz2"

    if channel == "preview":
        print("Packaging Preview release (GUI_preview.tar.bz2)...")
        make_tar_bz2(str(total_dir), str(gui_preview_tar))
        gui_md5 = md5_file(gui_preview_tar)

        # Update preview & latest metadata
        (dest_dir / "preview.version").write_text(f"{version}\n")
        (dest_dir / "latest.version").write_text(f"{version}\n")
        is_prerelease = "true"
        release_title = f"Release v{version} (Preview)"
    else:
        print("Packaging Stable release (GUI.tar.bz2)...")
        make_tar_bz2(str(total_dir), str(gui_stable_tar))
        gui_md5 = md5_file(gui_stable_tar)

        # Update stable, preview baseline & latest metadata
        (dest_dir / "stable.version").write_text(f"{version}\n")
        (dest_dir / "latest.version").write_text(f"{version}\n")
        (dest_dir / "preview.version").write_text(f"{version}\n")
        is_prerelease = "false"
        release_title = f"Release v{version}"

    if total_dir.exists():
        for _ in range(5):
            try:
                shutil.rmtree(total_dir)
                break
            except Exception:
                time.sleep(0.5)

    v_file = dest_dir / "version"
    existing_lines = v_file.read_text().splitlines() if v_file.exists() else []
    filtered_lines = [l for l in existing_lines if not re.search(r'\b' + re.escape(version) + r'\b', l)]
    new_version_content = f"{gui_md5} {version} [{channel.upper()}]\n" + "\n".join(filtered_lines) + "\n"
    v_file.write_text(new_version_content)

    print(f"\nSuccessfully built and synchronized {channel.upper()} release v{version} (MD5: {gui_md5})!")

    # Set GitHub Actions output parameters if running in CI
    gh_output = os.environ.get("GITHUB_OUTPUT")
    if gh_output:
        try:
            with open(gh_output, "a") as f:
                f.write(f"channel={channel}\n")
                f.write(f"version={version}\n")
                f.write(f"is_prerelease={is_prerelease}\n")
                f.write(f"release_title={release_title}\n")
        except Exception:
            pass

if __name__ == "__main__":
    main()
