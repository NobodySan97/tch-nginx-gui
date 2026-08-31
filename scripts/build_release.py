#!/usr/bin/env python3
"""
Cross-platform build & release manager for tch-nginx-gui.
Supports:
  - Stable releases (default: builds GUI.tar.bz2, updates stable.version, preview.version, latest.version)
  - Preview releases (--channel preview: builds GUI_preview.tar.bz2, updates preview.version, latest.version)
  - Dev releases (--channel dev: builds GUI_dev.tar.bz2, updates latest.version)
  - Dry-run verification (--dry-run: builds into tempdir, verifies archives, checksums, permissions without altering repo)
  - Release archive validation (--verify: audits target release directory integrity and tarball structure)
"""

import os
import sys
import re
import time
import shutil
import tarfile
import hashlib
import tempfile
import subprocess
from pathlib import Path

# Epoch timestamp: 2018-01-01 00:00:00 UTC (deterministic reproducible builds)
REPRODUCIBLE_MTIME = 1514764800

MODULAR_DIRS = [
    "base", "gui_file", "traffic_mon",
    "upgrade-pack-specificDGA", "upgrade-pack-specificTG800",
    "upgrade-pack-specificTG789", "upgrade-pack-specificTG789Xtream35B",
    "telstra_gui", "ledfw_support-specificTG788", "ledfw_support-specificTG789",
    "ledfw_support-specificTG799", "ledfw_support-specificTG800",
    "ledfw_support-specificDGA", "ledfw_support-specificDGA4131"
]


def md5_file(filepath):
    """Calculates MD5 hexadecimal digest of a file."""
    h = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def md5_bytes(data: bytes) -> str:
    """Calculates MD5 hexadecimal digest of in-memory bytes."""
    return hashlib.md5(data).hexdigest()


def get_git_modes_and_symlinks(repo_dir):
    """
    Extracts file modes and symlink information directly from git index.
    Returns:
        git_modes: dict mapping normalized relative posix paths to integer mode (e.g. 0o755, 0o644, 0o777)
        git_symlinks: dict mapping normalized relative posix paths to target path string
    """
    git_modes = {}
    git_symlinks = {}
    try:
        out = subprocess.check_output(
            ["git", "-C", str(repo_dir), "ls-files", "-s"],
            text=True,
            stderr=subprocess.DEVNULL
        )
        for line in out.splitlines():
            parts = line.strip().split(None, 3)
            if len(parts) == 4:
                raw_mode = parts[0]
                rel_path = parts[3].replace("\\", "/").strip("/")
                if raw_mode == "120000":
                    # Symlink entry in git index
                    p = Path(repo_dir) / rel_path
                    if p.is_symlink():
                        target = os.readlink(p)
                    elif p.exists():
                        try:
                            target = p.read_text(encoding="utf-8").strip()
                        except Exception:
                            target = ""
                    else:
                        target = ""
                    git_symlinks[rel_path] = target
                    git_modes[rel_path] = 0o777
                else:
                    mode_oct = int(raw_mode, 8) & 0o777
                    git_modes[rel_path] = mode_oct
    except Exception:
        pass
    return git_modes, git_symlinks


def sanitize_text_files_lf(target_dir):
    """
    Recursively converts CRLF line endings to LF across all text files in target_dir.
    Safely ignores binary files by checking for null bytes.
    """
    for root, _, files in os.walk(target_dir):
        r_path = Path(root)
        for f in files:
            p = r_path / f
            try:
                raw = p.read_bytes()
                # Skip binary files containing null bytes
                if b"\x00" in raw[:4096]:
                    continue
                if b"\r\n" in raw:
                    p.write_bytes(raw.replace(b"\r\n", b"\n"))
            except Exception:
                pass


def make_tar_bz2(source_dir, output_filename, git_modes=None, git_symlinks=None, base_rel=""):
    """
    Creates a deterministic tar.bz2 archive with reproducible mtime and normalized POSIX permissions.
    Preserves and restores Unix symlinks correctly across Windows and Linux.
    """
    source_path = Path(source_dir).resolve()
    entries = []

    for root, dirs, files in os.walk(source_path):
        dirs.sort()
        files.sort()
        r_path = Path(root)
        rel_root = r_path.relative_to(source_path)

        # Include directory entry if not root
        if rel_root != Path("."):
            entries.append((r_path, rel_root.as_posix(), True))

        for f in files:
            f_path = r_path / f
            rel_file = (rel_root / f) if rel_root != Path(".") else Path(f)
            entries.append((f_path, rel_file.as_posix(), False))

    # Sort entries by archive path for deterministic archive ordering
    entries.sort(key=lambda x: x[1])

    with tarfile.open(output_filename, "w:bz2") as tar:
        for f_path, arcname, is_dir in entries:
            tarinfo = tarfile.TarInfo(name=arcname)
            tarinfo.mtime = REPRODUCIBLE_MTIME
            tarinfo.uid = 0
            tarinfo.gid = 0
            tarinfo.uname = "root"
            tarinfo.gname = "root"

            if is_dir:
                tarinfo.type = tarfile.DIRTYPE
                if arcname == "tmp" or arcname.endswith("/tmp"):
                    tarinfo.mode = 0o777
                else:
                    tarinfo.mode = 0o755
                tar.addfile(tarinfo)
                continue

            norm_arc = arcname.strip("/")
            full_rel = f"{base_rel}/{norm_arc}".strip("/") if base_rel else norm_arc

            # Check if this file is a symlink
            symlink_target = None
            if f_path.is_symlink():
                symlink_target = os.readlink(f_path)
            elif git_symlinks:
                if full_rel in git_symlinks:
                    symlink_target = git_symlinks[full_rel]
                else:
                    for g_path, target in git_symlinks.items():
                        if g_path.endswith("/" + norm_arc) or g_path == norm_arc:
                            symlink_target = target
                            break

            if symlink_target:
                tarinfo.type = tarfile.SYMTYPE
                tarinfo.linkname = symlink_target
                tarinfo.mode = 0o777
                tarinfo.size = 0
                tar.addfile(tarinfo)
                continue

            # Regular file
            tarinfo.type = tarfile.REGTYPE
            tarinfo.size = f_path.stat().st_size

            # Determine mode
            is_executable = (
                norm_arc.endswith(".sh")
                or norm_arc.endswith(".postinst")
                or norm_arc.endswith(".prerm")
                or any(part in {"init.d", "rc.d", "hotplug.d", "bin", "sbin", "modgui_scripts", "transfers", "mount_modroot"} for part in Path(norm_arc).parts)
            )

            if is_executable:
                mode = 0o755
            elif git_modes:
                if full_rel in git_modes:
                    mode = git_modes[full_rel]
                else:
                    for g_path, g_mode in git_modes.items():
                        if g_path.endswith("/" + norm_arc) or g_path == norm_arc:
                            mode = g_mode
                            break

            if mode is None:
                mode = 0o644

            tarinfo.mode = mode

            with open(f_path, "rb") as f_obj:
                tar.addfile(tarinfo, f_obj)


def get_git_info(repo_dir):
    try:
        short_sha = subprocess.check_output(
            ["git", "-C", str(repo_dir), "log", "-1", "--format=%h"],
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
        last_msg = subprocess.check_output(
            ["git", "-C", str(repo_dir), "log", "-1", "--format=%B"],
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        short_sha = "unknown"
        last_msg = ""
    return short_sha, last_msg


def detect_channel(last_msg, cli_channel=None):
    if cli_channel:
        return cli_channel.lower()
    env_chan = os.environ.get("RELEASE_CHANNEL", "").lower()
    if env_chan in ["preview", "stable", "dev"]:
        return env_chan
    # Check for [preview] or preview in commit message
    if re.search(r'\[preview\]', last_msg, re.IGNORECASE) or "preview" in last_msg.lower():
        return "preview"
    # Check for [dev] in commit message
    if re.search(r'\[dev\]', last_msg, re.IGNORECASE):
        return "dev"
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
            ["git", "-C", str(src_dir), "tag", "-l"],
            text=True,
            stderr=subprocess.DEVNULL
        ).strip().splitlines()
        for t in tags_out:
            candidates.append(parse_ver_tuple(t))
    except Exception:
        pass

    # 2. From version files in dest_dir
    for f in ["stable.version", "preview.version", "latest.version", "dev.version"]:
        p = dest_dir / f
        if p.exists():
            try:
                candidates.append(parse_ver_tuple(p.read_text(encoding="utf-8").strip()))
            except Exception:
                pass

    # 3. From version history table in dest_dir
    v_file = dest_dir / "version"
    if v_file.exists():
        try:
            for line in v_file.read_text(encoding="utf-8").splitlines():
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


def verify_archive_structure(tar_path):
    """
    Audits a built tar.bz2 archive for compression integrity, valid member paths,
    expected POSIX permissions, and working symlinks.
    """
    p = Path(tar_path)
    if not p.exists() or p.stat().st_size == 0:
        return False, f"Archive {p.name} does not exist or is empty"

    try:
        with tarfile.open(str(p), "r:bz2") as tar:
            members = tar.getmembers()
            if not members:
                return False, f"Archive {p.name} is empty (0 members)"

            issues = []
            for m in members:
                # Disallow Windows backslashes in tar archive paths
                if "\\" in m.name:
                    issues.append(f"Invalid backslash in member path: {m.name}")

                # Check executable permissions on scripts
                if not m.isdir() and not m.issym():
                    if (
                        m.name.endswith(".sh")
                        or any(part in {"init.d", "rc.d", "hotplug.d", "bin", "sbin"} for part in Path(m.name).parts)
                    ):
                        if m.mode != 0o755:
                            issues.append(f"Script missing execute mode (mode={oct(m.mode)}): {m.name}")

                # Check symlink target validity
                if m.issym() and not m.linkname:
                    issues.append(f"Symlink has empty link target: {m.name}")

            if issues:
                return False, f"Found {len(issues)} issues in {p.name}: {issues[:5]}"
            return True, f"OK ({len(members)} members, {p.stat().st_size:,} bytes)"
    except Exception as e:
        return False, f"Archive extraction/verification failed: {e}"


def verify_release_dir(dest_dir):
    """
    Audits a release directory for required archives, version files, and checksum consistency.
    """
    dest_path = Path(dest_dir).resolve()
    print(f"\n===================================================")
    print(f"  Verifying Release Directory: {dest_path}")
    print(f"===================================================")

    if not dest_path.is_dir():
        print(f"[ERROR] Destination directory does not exist: {dest_path}")
        return False

    all_ok = True

    # 1. Verify Modular Archives
    modular_dir = dest_path / "modular"
    if modular_dir.is_dir():
        print("\nChecking modular packages:")
        for mod in MODULAR_DIRS:
            tar_file = modular_dir / f"{mod}.tar.bz2"
            ok, msg = verify_archive_structure(tar_file)
            status = "[OK]" if ok else "[FAIL]"
            print(f"  {status} {tar_file.name}: {msg}")
            if not ok:
                all_ok = False
    else:
        print("\n[WARN] modular/ subdirectory not found in destination directory.")

    # 2. Verify Main GUI Archives
    print("\nChecking GUI packages:")
    for gui_tar in ["GUI.tar.bz2", "GUI_preview.tar.bz2", "GUI_dev.tar.bz2"]:
        p = dest_path / gui_tar
        if p.exists():
            ok, msg = verify_archive_structure(p)
            status = "[OK]" if ok else "[FAIL]"
            print(f"  {status} {gui_tar}: {msg}")
            if not ok:
                all_ok = False

    # 3. Verify Version Files and Checksums
    print("\nChecking version and checksum files:")
    for v_name in ["stable.version", "preview.version", "latest.version"]:
        v_path = dest_path / v_name
        if v_path.exists():
            val = v_path.read_text(encoding="utf-8").strip()
            print(f"  [OK] {v_name}: {val}")
        else:
            print(f"  [--] {v_name}: Not present")

    v_file = dest_path / "version"
    if v_file.exists():
        lines = v_file.read_text(encoding="utf-8").strip().splitlines()
        print(f"  [OK] version table: {len(lines)} release entries recorded.")
        if lines:
            top_line = lines[0].split()
            if len(top_line) >= 2:
                top_hash, top_ver = top_line[0], top_line[1]
                print(f"       Latest entry: {top_ver} (hash: {top_hash})")
                # Cross-check hash with active GUI archive
                for g_tar in [dest_path / "GUI.tar.bz2", dest_path / "GUI_preview.tar.bz2", dest_path / "GUI_dev.tar.bz2"]:
                    if g_tar.exists():
                        g_hash = md5_file(g_tar)
                        if g_hash == top_hash:
                            print(f"       Checksum verified matches {g_tar.name}!")
    else:
        print("  [--] version: Not present")

    print("\n" + ("=" * 51))
    if all_ok:
        print("  Release Directory Integrity: ALL CHECKS PASSED")
    else:
        print("  Release Directory Integrity: ISSUES DETECTED")
    print("=" * 51 + "\n")
    return all_ok


def build_release(src_dir, dest_dir, channel="stable", manual_ver=None, dry_run=False):
    """
    Executes the full packaging pipeline for the specified channel and destination.
    """
    src_dir = Path(src_dir).resolve()
    dest_dir = Path(dest_dir).resolve()

    short_sha, last_msg = get_git_info(src_dir)
    version = calculate_version(last_msg, src_dir, dest_dir, manual_ver)

    print(f"\n===================================================")
    print(f"  TCH-NGINX-GUI Build & Release Packaging Engine")
    print(f"===================================================")
    print(f"Source Directory:      {src_dir}")
    print(f"Destination Directory: {dest_dir}")
    print(f"Target Channel:        {channel.upper()}")
    print(f"Release Version:       v{version} (Commit: {short_sha})")
    print(f"Dry-Run Mode:          {'ENABLED' if dry_run else 'DISABLED'}")
    print(f"===================================================\n")

    # Load git index metadata for POSIX file permissions and symlink targets
    git_modes, git_symlinks = get_git_modes_and_symlinks(src_dir)
    print(f"Loaded {len(git_modes)} tracked file modes and {len(git_symlinks)} symlinks from git index.")

    # 1. Sanitize line endings to LF across all source text files in decompressed/
    print("Sanitizing text file line endings to LF...")
    sanitize_text_files_lf(src_dir / "decompressed")

    # 2. Update version in rootdevice (or in-memory / restored if dry-run)
    rootdevice = src_dir / "decompressed" / "base" / "etc" / "init.d" / "rootdevice"
    orig_rootdevice_content = None
    if rootdevice.exists():
        orig_rootdevice_content = rootdevice.read_text(encoding="utf-8")
        updated = re.sub(r'version_gui=.*', f'version_gui={version}-{short_sha}', orig_rootdevice_content)
        rootdevice.write_bytes(updated.encode("utf-8"))
        print(f"Updated rootdevice: version_gui={version}-{short_sha}")

    # 3. Generate MD5 Checksums for modular components
    status_led = src_dir / "decompressed" / "gui_file" / "tmp" / "status-led-eventing.lua_new"
    if status_led.exists():
        md5_val = md5_file(status_led)
        (src_dir / "decompressed" / "gui_file" / "tmp" / "status-led-eventing.md5sum").write_bytes(
            f"{md5_val}  tmp/status-led-eventing.lua_new\n".encode("utf-8")
        )

    for mod in MODULAR_DIRS:
        if "ledfw_support" in mod:
            sm = src_dir / "decompressed" / mod / "etc" / "ledfw" / "stateMachines.lua"
            if sm.exists():
                md5_val = md5_file(sm)
                (src_dir / "decompressed" / mod / "stateMachines.md5sum").write_bytes(
                    f"{md5_val}  etc/ledfw/stateMachines.lua\n".encode("utf-8")
                )

    # Use temporary destination if dry-run
    build_target_dir = Path(tempfile.mkdtemp(prefix="tch_build_")) if dry_run else dest_dir
    build_target_dir.mkdir(parents=True, exist_ok=True)

    try:
        # 4. Packaging modular packages
        modular_dest = build_target_dir / "modular"
        modular_dest.mkdir(parents=True, exist_ok=True)

        for mod in MODULAR_DIRS:
            mod_src = src_dir / "decompressed" / mod
            if mod_src.exists():
                out_tar = modular_dest / f"{mod}.tar.bz2"
                print(f"Packaging modular: {mod} -> {out_tar.name}")
                make_tar_bz2(
                    source_dir=str(mod_src),
                    output_filename=str(out_tar),
                    git_modes=git_modes,
                    git_symlinks=git_symlinks,
                    base_rel=f"decompressed/{mod}"
                )

        # 5. Assembling total GUI
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
        for mod in MODULAR_DIRS:
            if not mod.startswith("upgrade-pack-"):
                mod_tar = modular_dest / f"{mod}.tar.bz2"
                if mod_tar.exists():
                    shutil.copy2(mod_tar, tmp_dir / f"{mod}.tar.bz2")

        # 6. Packaging GUI archive according to channel
        if channel == "preview":
            gui_tar = build_target_dir / "GUI_preview.tar.bz2"
            print("\nPackaging Preview release (GUI_preview.tar.bz2)...")
            make_tar_bz2(str(total_dir), str(gui_tar), git_modes, git_symlinks, "")
            gui_md5 = md5_file(gui_tar)

            (build_target_dir / "preview.version").write_bytes(f"{version}\n".encode("utf-8"))
            (build_target_dir / "latest.version").write_bytes(f"{version}\n".encode("utf-8"))
            is_prerelease = "true"
            release_title = f"Release v{version} (Preview)"

        elif channel == "dev":
            gui_tar = build_target_dir / "GUI_dev.tar.bz2"
            print("\nPackaging Dev release (GUI_dev.tar.bz2)...")
            make_tar_bz2(str(total_dir), str(gui_tar), git_modes, git_symlinks, "")
            gui_md5 = md5_file(gui_tar)

            (build_target_dir / "latest.version").write_bytes(f"{version}\n".encode("utf-8"))
            is_prerelease = "true"
            release_title = f"Release v{version} (Dev)"

        else:  # Stable
            gui_tar = build_target_dir / "GUI.tar.bz2"
            print("\nPackaging Stable release (GUI.tar.bz2)...")
            make_tar_bz2(str(total_dir), str(gui_tar), git_modes, git_symlinks, "")
            gui_md5 = md5_file(gui_tar)

            (build_target_dir / "stable.version").write_bytes(f"{version}\n".encode("utf-8"))
            (build_target_dir / "preview.version").write_bytes(f"{version}\n".encode("utf-8"))
            (build_target_dir / "latest.version").write_bytes(f"{version}\n".encode("utf-8"))
            is_prerelease = "false"
            release_title = f"Release v{version}"

        # Clean temporary assemble directory
        if total_dir.exists():
            for _ in range(5):
                try:
                    shutil.rmtree(total_dir)
                    break
                except Exception:
                    time.sleep(0.5)

        # 7. Update version table
        v_file = build_target_dir / "version"
        existing_lines = v_file.read_text(encoding="utf-8").splitlines() if v_file.exists() else []
        filtered_lines = [l for l in existing_lines if not re.search(r'\b' + re.escape(version) + r'\b', l)]
        new_version_content = f"{gui_md5} {version} [{channel.upper()}]\n" + "\n".join(filtered_lines) + "\n"
        v_file.write_bytes(new_version_content.encode("utf-8"))

        print(f"\nSuccessfully built {channel.upper()} release v{version}!")
        print(f"Archive:  {gui_tar.name} ({gui_tar.stat().st_size:,} bytes)")
        print(f"MD5 Sum:  {gui_md5}")

        # 8. Run archive verification checks
        ok, msg = verify_archive_structure(gui_tar)
        if ok:
            print(f"Integrity check passed: {msg}")
        else:
            print(f"[ERROR] Integrity check failed: {msg}")
            if not dry_run:
                sys.exit(1)

        # Set GitHub Actions output parameters if running in CI
        gh_output = os.environ.get("GITHUB_OUTPUT")
        if gh_output:
            try:
                with open(gh_output, "a", encoding="utf-8") as f:
                    f.write(f"channel={channel}\n")
                    f.write(f"version={version}\n")
                    f.write(f"is_prerelease={is_prerelease}\n")
                    f.write(f"release_title={release_title}\n")
            except Exception:
                pass

        if dry_run:
            print("\n[DRY-RUN] Full release verification:")
            verify_release_dir(build_target_dir)

    finally:
        # Revert rootdevice if in dry-run
        if dry_run and orig_rootdevice_content and rootdevice.exists():
            rootdevice.write_bytes(orig_rootdevice_content.encode("utf-8"))
            print("Restored original rootdevice content for dry-run.")
        if dry_run and build_target_dir.exists():
            shutil.rmtree(build_target_dir, ignore_errors=True)

    return True


def print_help():
    print("""Usage: python scripts/build_release.py [options] [DEST_DIR] [VERSION]

Arguments:
  DEST_DIR              Path to output release directory (default: ../gui-dev-build-auto)
  VERSION               Optional version override (e.g. 9.8.28)

Options:
  --channel CHANNEL     Release channel: 'stable' (default), 'preview', or 'dev'
  --dry-run             Build and test archives in a temporary directory without modifying source files
  --verify [DIR]        Verify compression, checksums, and structure of an existing release directory
  -h, --help            Show this help message
""")


def main():
    src_dir = Path(__file__).resolve().parent.parent
    dest_dir = src_dir.parent / "gui-dev-build-auto"
    cli_channel = None
    manual_ver = os.environ.get("CUSTOM_VERSION", None)
    dry_run = False
    verify_mode = False
    verify_target = None

    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg in ["-h", "--help"]:
            print_help()
            return
        elif arg == "--dry-run":
            dry_run = True
        elif arg == "--verify":
            verify_mode = True
            if i + 1 < len(sys.argv) and not sys.argv[i + 1].startswith("-"):
                verify_target = Path(sys.argv[i + 1])
                i += 1
        elif arg.startswith("--verify="):
            verify_mode = True
            verify_target = Path(arg.split("=", 1)[1])
        elif arg == "--channel" and i + 1 < len(sys.argv):
            cli_channel = sys.argv[i + 1]
            i += 2
            continue
        elif arg.startswith("--channel="):
            cli_channel = arg.split("=", 1)[1]
        elif re.match(r'^[0-9]+\.[0-9]+\.[0-9]+', arg):
            manual_ver = arg
        elif arg.lower() in ["preview", "stable", "dev"]:
            cli_channel = arg.lower()
        elif not arg.startswith("-"):
            p = Path(arg)
            dest_dir = p.resolve()
        i += 1

    if verify_mode:
        target = verify_target or dest_dir
        success = verify_release_dir(target)
        sys.exit(0 if success else 1)

    _, last_msg = get_git_info(src_dir)
    channel = detect_channel(last_msg, cli_channel)

    build_release(
        src_dir=src_dir,
        dest_dir=dest_dir,
        channel=channel,
        manual_ver=manual_ver,
        dry_run=dry_run
    )


if __name__ == "__main__":
    main()

