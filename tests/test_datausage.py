"""Data Usage uses the firmware backend with tainted HTTP arguments."""


from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / 'decompressed/gui_file'
RUNTIMES = list(filter(None, (shutil.which('lua'), shutil.which('luajit'))))


def resolve_sh():
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


class DataUsage(unittest.TestCase):
    @unittest.skipUnless(RUNTIMES, 'Lua required')
    def test_native_counters_and_reset_with_protected_arguments(self):
        for lua in RUNTIMES:
            with self.subTest(runtime=lua):
                result = subprocess.run([lua, str(ROOT / 'tests/test_datausage.lua'), str(GUI)],
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(SH, 'POSIX shell required')
    def test_native_intercept_hook_runs_when_available(self):
        rule = (GUI / 'usr/share/transformer/commitapply/uci_datausage.ca').read_text().splitlines()[0]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            daemon, intercept = root / 'daemon', root / 'intercept'
            daemon.write_text('#!/bin/sh\necho "$1"\n')
            daemon.chmod(0o755)
            command = rule.split(' ', 1)[1].replace('/etc/init.d/datausaged', _msys_path(daemon)).replace(
                '/usr/share/transformer/scripts/datausage_intercept.lua', _msys_path(intercept))
            result = subprocess.run([SH, '-c', command], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ['reload'])
            intercept.write_text('#!/bin/sh\necho native-intercept\n')
            intercept.chmod(0o755)
            result = subprocess.run([SH, '-c', command], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ['reload', 'native-intercept'])


if __name__ == '__main__':
    unittest.main()
