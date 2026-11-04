"""Exercise nanoCDN cleanup with stock IPTV and missing boot links/services."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'decompressed/gui_file/usr/share/transformer/scripts/ispConfigHelper.sh'


# POSIX shell is required to run the helper: resolve Git's bundled sh on Windows.
SH = shutil.which('sh')
if not SH:
    _candidate = Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git' / 'bin' / 'sh.exe'
    if _candidate.exists():
        SH = str(_candidate)

def _msys_path(p):
    """Convert a "C:/Users/..." path to "/c/Users/...": MSYS sh silently
    ignores C:/ style entries. Pattern taken from tests/test_smartphone_app.py."""
    p = str(p).replace(os.sep, '/')
    if len(p) >= 3 and p[1:2] == ':':
        return '/' + p[0].lower() + p[2:]
    return p



class NanoCdnCleanup(unittest.TestCase):
    def run_cleanup(self, enabled, service=True, boot_link=True):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            init = base / 'nanocdn'
            state = base / 'enabled'
            actions = base / 'actions'
            if enabled is not None:
                state.write_text(enabled)
            if service:
                init.write_text('#!/bin/sh\necho "service $1" >> "$ACTIONS"\n', newline="\n")
                init.chmod(0o755)
            link = base / 'S99nanocdn'
            if boot_link:
                # Reproduce the boot symlink when the sandbox allows it; the
                # upstream purge no longer reads it, so failure is tolerable.
                try:
                    link.symlink_to(init)
                except OSError:
                    pass
            source = HELPER.read_text().split('firewall_specific_sip_rules_FASTWEB()')[0]
            source = source.replace('/etc/init.d/nanocdn', _msys_path(init))
            source = source.replace('/etc/rc.d/S99nanocdn', _msys_path(link))
            source = source.replace('/etc/init.d/bulkdata', _msys_path(base / 'bulkdata'))
            mock = r'''
uci() {
  [ "$1" = '-q' ] && shift
  case "$1:$2" in
    get:system.mabr) [ -f "$STATE" ] && echo agent ;;
    get:system.mabr.enabled) cat "$STATE" 2>/dev/null ;;
    get:system.acotel.enabled) return 1 ;;
    show:network) echo "network.iptv=interface" ;;
    set:system.mabr.enabled=0) echo 0 > "$STATE"; echo set >> "$ACTIONS" ;;
    commit:system) echo commit >> "$ACTIONS" ;;
    *) return 1 ;;
  esac
}
purge_telemetry
purge_telemetry
'''
            script = (
                f'STATE={shlex.quote(_msys_path(state))}\n'
                f'export ACTIONS={shlex.quote(_msys_path(actions))}\ndebug=0\n'
                + source + mock
            )
            result = subprocess.run([SH], input=script, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, '')
            self.assertEqual(state.read_text().strip() if state.exists() else None,
                             '0' if enabled is not None else None)
            expected = ['set', 'commit'] if enabled not in (None, '0') else []
            if service:
                expected += ['service stop', 'service disable'] * 2
            self.assertEqual(actions.read_text().splitlines() if actions.exists() else [],
                             expected)

    def test_stock_iptv_does_not_preserve_nanocdn(self):
        self.run_cleanup('1')

    def test_missing_boot_link_still_stops_service(self):
        self.run_cleanup('1', boot_link=False)

    def test_disabled_flag_still_stops_running_service(self):
        self.run_cleanup('0', boot_link=False)

    def test_firmware_without_mabr(self):
        self.run_cleanup(None, service=False, boot_link=False)


if __name__ == '__main__':
    unittest.main()
