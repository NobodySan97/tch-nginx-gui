"""The managed resolver must exist before dnsmasq starts after a reboot."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INIT = ROOT / 'decompressed/smartphone/etc/init.d/modgui-smartphone-uplink'

# NOTE(fork): boot flows are POSIX init scripts; on Windows run them with the
# Git for Windows bundled sh and verify symlink targets and permission bits
# through the same POSIX tooling instead of os.readlink()/os.stat().
SH = shutil.which('sh') or shutil.which('sh.exe') or \
     str(Path(os.environ.get('ProgramFiles', 'C:/Program Files'),
              'Git', 'bin', 'sh.exe'))
SH = SH if Path(SH).exists() else None


def _msys_path(path):
    """Convert a "C:/..." path to "/c/...": MSYS sh only resolves POSIX PATHs."""
    path = str(path).replace(os.sep, '/')
    if len(path) >= 3 and path[1:2] == ':':
        return '/' + path[0].lower() + path[2:]
    return path


@unittest.skipUnless(SH, 'POSIX shell required')
class SmartphoneBootTest(unittest.TestCase):
    def test_both_boot_links_use_one_script_and_late_phase_starts_monitor(self):
        with tempfile.TemporaryDirectory() as folder:
            links = Path(folder) / 'etc/rc.d'
            links.mkdir(parents=True)
            # NOTE(fork): on Windows MSYS symlinks must not dangle, so the
            # init script is staged for the enable/disable procedure; the
            # staged copy also serves as the link target reference below.
            target = Path(folder) / 'etc/init.d/modgui-smartphone-uplink'
            target.parent.mkdir(parents=True)
            target.write_text(INIT.read_text().replace('\r\n', '\n'), newline='\n')
            subprocess.run([SH, '-c', '''
. "$1"
enable || exit 1
initscript=/etc/rc.d/S95modgui-smartphone-uplink
start() { echo monitor; }
boot
''', 'sh', str(INIT)], check=True, capture_output=True, text=True,
                env={**os.environ, 'IPKG_INSTROOT': folder})
            self.assertEqual(sorted(p.name for p in links.iterdir()), [
                'K10modgui-smartphone-uplink', 'S18modgui-smartphone-uplink',
                'S95modgui-smartphone-uplink'])
            if os.name == 'posix':
                for link in links.iterdir():
                    self.assertEqual(os.readlink(link), '../init.d/modgui-smartphone-uplink')
            else:
                # NOTE(fork): os.readlink() cannot describe MSYS symlinks and,
                # without symlink privileges, ln -s falls back to a copy of the
                # target; assert the link identity through the POSIX tooling.
                targets = subprocess.run(
                    [SH, '-c', 'for f in "$1"/etc/rc.d/*; do readlink "$f"; done', 'sh',
                     _msys_path(folder)], capture_output=True, text=True, env={**os.environ})
                links_seen = [line for line in targets.stdout.splitlines() if line]
                if links_seen:
                    self.assertEqual(sorted(links_seen), [
                        '../init.d/modgui-smartphone-uplink'] * 3)
                else:
                    same = subprocess.run(
                        [SH, '-c', 'for f in "$1"/etc/rc.d/*; do cmp -s "$f" "$2" && echo same; done',
                         'sh', _msys_path(folder), _msys_path(target)],
                        capture_output=True, text=True, env={**os.environ})
                    self.assertEqual(same.stdout.count('same'), 3, same.stderr)
            result = subprocess.run([SH, '-c', '''
. "$1"
initscript=/etc/rc.d/S95modgui-smartphone-uplink
start() { echo monitor; }
boot
disable
''', 'sh', str(INIT)], check=True, capture_output=True, text=True,
                env={**os.environ, 'IPKG_INSTROOT': folder})
            self.assertEqual(result.stdout.strip(), 'monitor')
            self.assertEqual(list(links.iterdir()), [])

    def test_resolver_preparation_before_dnsmasq_is_guarded_and_idempotent(self):
        source = INIT.read_text()
        self.assertIn('START=95', source)
        with tempfile.TemporaryDirectory() as folder:
            resolver = Path(folder) / 'dns/resolv.conf'
            script = Path(folder) / 'init.sh'
            script.write_text(source.replace('/var/run/modgui-smartphone-dns',
                                             str(resolver.parent).replace(os.sep, '/')), newline='\n')
            command = '''
uci() { case "$*" in *enabled) echo "$ENABLED";; *dns_managed) echo "$MANAGED";; esac; }
. "$1"
initscript=/etc/rc.d/S18modgui-smartphone-uplink
start() { exit 99; }
boot
'''
            def run(enabled, managed):
                subprocess.run([SH, '-c', command, 'sh', str(script)], check=True,
                               env={**os.environ, 'ENABLED': enabled, 'MANAGED': managed})
            run('0', '1')
            self.assertFalse(resolver.exists())
            run('1', '0')
            self.assertFalse(resolver.exists())
            run('1', '1')
            self.assertTrue(resolver.exists())
            if os.name == 'posix':
                self.assertEqual(resolver.parent.stat().st_mode & 0o777, 0o755)
                self.assertEqual(resolver.stat().st_mode & 0o777, 0o644)
            else:
                modes = subprocess.run(
                    [SH, '-c', 'stat -c %a "$1" "$2"', 'sh', _msys_path(resolver.parent),
                     _msys_path(resolver)], capture_output=True, text=True, env={**os.environ})
                self.assertEqual(modes.stdout.split(), ['755', '644'], modes.stderr)
            resolver.write_text('nameserver 192.0.2.1\n', newline='\n')
            run('1', '1')
            self.assertEqual(resolver.read_text(), 'nameserver 192.0.2.1\n')


if __name__ == '__main__':
    unittest.main()
