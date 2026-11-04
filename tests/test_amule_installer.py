"""Exercise aMule ownership/rollback and DumaOS target rejection.

Ported from [upstream 42fb0684] and adapted to the fork's Windows sh harness
(real POSIX shell, PATH baked into a file-staged script, newline-aware writes
and Git's bundled sh resolution) like tests/test_smartphone_app.py.
"""
import os
import sys
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "decompressed/gui_file/usr/share/transformer/scripts/appInstallRemoveUtility.sh"


def resolve_sh():
    """POSIX shell required to run the installer snippets."""
    sh = shutil.which('sh')
    if sh:
        return sh
    git = shutil.which('git')
    if git:
        for candidate in (Path(git).parents[1] / 'usr/bin/sh.exe', Path(git).parents[1] / 'bin/sh.exe'):
            if candidate.exists():
                return str(candidate)
    return None


SH = resolve_sh()


def _msys_path(p):
    """Convert a "C:/Users/..." path to "/c/Users/...": MSYS sh silently
    ignores C:/ style entries inside PATH-like contexts."""
    p = str(p).replace(os.sep, '/')
    if len(p) >= 3 and p[1:2] == ':':
        return '/' + p[0].lower() + p[2:]
    return p


def run_sh(script, args=(), cwd=None, busybox_path=True):
    """Run a POSIX snippet; large scripts must go through a real file on
    Windows (msys argument conversion corrupts multi-line -c payloads)."""
    if sys.platform == 'win32':
        with tempfile.NamedTemporaryFile('w', delete=False, suffix='.sh',
                                         encoding='utf-8', newline='\n') as fh:
            fh.write('PATH="/usr/bin:/bin:$PATH"; export PATH\n')
            fh.write(script)
            staged = fh.name
        try:
            return subprocess.run([SH, _msys_path(staged), *map(str, args)],
                                  capture_output=True, text=True,
                                  cwd=cwd, timeout=60)
        finally:
            try: os.unlink(staged)
            except OSError: pass
    return subprocess.run([SH, '-c', script, 'probe', *map(str, args)],
                          capture_output=True, text=True, cwd=cwd, timeout=60)


@unittest.skipUnless(SH, 'sh required')
class AmuleLifecycle(unittest.TestCase):
    def function(self, directory):
        source = SOURCE.read_text()
        source = source[source.index("app_amule() {"):source.index("\napp_aria2()", source.index("app_amule() {"))]
        for path in ("/etc/modgui-amule", "/etc/init.d/amule", "/usr/bin/amuled", "/usr/bin/amuleweb"):
            source = source.replace(path, _msys_path(Path(directory) / Path(path).name))
        return source

    def run_case(self, extra, action="install"):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = self.function(root)
            harness = r'''
set_extension_state() { echo "STATE:$*"; }
require_usb_storage() { return 0; }
require_free_space() { return 0; }
cpu_type=armv7l
opkg() { [ "$1" != status ]; }
'''
            result = run_sh(source + harness + extra + "\napp_amule " + action, cwd=tmp)
            return result, (root / "modgui-amule").exists()

    def test_generated_init_is_executable_and_parses(self):
        source = SOURCE.read_text()
        start = source.index("  amule_write_init() {")
        end = source.index("  amule_publish_password()", start)
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "amule"
            writer = source[start:end].replace("/etc/init.d/amule", _msys_path(target))
            # POSIX permissions are emulated on Windows; parse and presence
            # are asserted on every platform, the mode bit only natively.
            result = run_sh(writer + "\namule_write_init", cwd=tmp)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = run_sh('sh -n "$1"', (_msys_path(target),), cwd=tmp)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('USE_PROCD=1', target.read_text())
            if sys.platform != 'win32':
                self.assertEqual(target.stat().st_mode & 0o777, 0o755)

    def test_failed_feed_does_not_write_state(self):
        result, state = self.run_case('opkg() { return 1; }')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(state)
        self.assertNotIn("STATE:", result.stdout)

    def test_unmanaged_install_is_preserved(self):
        result, state = self.run_case("opkg() { echo 'Status: install user installed'; }")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing to overwrite", result.stdout)
        self.assertFalse(state)

    def test_wrong_architecture_is_rejected(self):
        result, state = self.run_case('cpu_type=aarch64')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(state)

    def test_partial_install_rolls_back_only_new_packages(self):
        extra = r'''
opkg() {
  case "$1" in
    update) return 0 ;;
    list-installed)
      echo 'stock-library - 1'
      [ ! -f amule-added ] || echo 'amule - 3'
      [ ! -f new-dependency-added ] || echo 'new-dependency - 1'
      return 0 ;;
    install) touch amule-added new-dependency-added; return 1 ;;
    status) [ -f "$2-added" ] && echo 'Status: install user installed' ;;
    remove) echo "$2" >> removed; rm -f "$2-added" ;;
  esac
}
'''
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            script = self.function(root) + "\ncpu_type=armv7l\nrequire_free_space() { return 0; }\nset_extension_state() { :; }\n" + extra + "\napp_amule install"
            result = run_sh(script, cwd=tmp)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(set((root / "removed").read_text().splitlines()), {"amule", "new-dependency"})
            self.assertFalse((root / "modgui-amule").exists())

    def test_dumaos_rejects_unsupported_kernel_before_package_operations(self):
        source = SOURCE.read_text()
        helper = source[source.index("dumaos_platform_supported() {"):source.index("\n# Shared TUN")]
        start = source.index("app_dumaos() {")
        function = source[start:source.index("\napp_smartphone()", start)]
        for cpu, kernel in (("armv7l", "4.1.38"), ("mips", "3.4.11-rt19")):
            with self.subTest(cpu=cpu, kernel=kernel):
                harness = f"\ncpu_type={cpu}\nuname() {{ echo {kernel}; }}\nopkg() {{ echo UNEXPECTED_PACKAGE_OPERATION; }}\nrequire_free_space() {{ echo UNEXPECTED_SPACE_CHECK; }}\n"
                result = run_sh(helper + function + harness + "app_dumaos install")
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("UNEXPECTED", result.stdout)


if __name__ == "__main__":
    unittest.main()
