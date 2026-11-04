"""Exercise the real TUN lifecycle with simulated kernel commands and private paths.

Ported from [upstream 4074838d, bf0d28eb, bae7baa9] and adapted to the fork's
preserved shared-lifecycle (armv7l-only reviewed build, curl+sha256 verified
download, POSIX/subshell patterns). Tests for upstream features not present in
the fork yet (MIPS tbz module download, easy-rsa, DH download, private OpenSSL
rework, modal cipher export, openvpn restart services) are not carried over.
"""
from pathlib import Path
import gzip
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
INSTALLER = ROOT / 'usr/share/transformer/scripts/appInstallRemoveUtility.sh'


def resolve_sh():
    """Find a POSIX shell (fork development machines may run Windows)."""
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


def sh_run(script, args=(), cwd=None):
    """Run a POSIX snippet; large scripts must go through a real file on Windows."""
    return subprocess.run([SH, '-c', script, 'probe', *map(str, args)],
                          capture_output=True, text=True,
                          cwd=cwd and str(cwd))


def run_sh(script, args=(), cwd=None, timeout=60):
    if sys.platform == 'win32':
        with tempfile.NamedTemporaryFile('w', delete=False, suffix='.sh',
                                         encoding='utf-8', newline='\n') as fh:
            # The dev-shell PATH may not include the msys userland commands.
            fh.write('PATH="/usr/bin:/bin:$PATH"; export PATH\n')
            fh.write(script)
            staged = fh.name
        try:
            return subprocess.run([SH, staged.replace('\\', '/'), *map(str, args)],
                                  capture_output=True, text=True,
                                  cwd=cwd and str(cwd), timeout=timeout)
        finally:
            try: os.unlink(staged)
            except OSError: pass
    return subprocess.run([SH, '-c', script, 'probe', *map(str, args)],
                          capture_output=True, text=True,
                          cwd=cwd and str(cwd), timeout=timeout)




def tun_helpers():
    source = INSTALLER.read_text()
    # Use a function boundary, not a comment whose wording can change. index()
    # must fail if the boundary disappears rather than running the dispatcher.
    return source[:source.index('\ninstall_from_github()')]


def kernel_helpers():
    source = INSTALLER.read_text()
    start = source.index('modgui_kernel_abi_matches() (')
    return source[start:source.index('\nmodgui_load_wireguard()')]


@unittest.skipUnless(SH, 'sh required')
class KernelAbi(unittest.TestCase):
    """Kernel ABI/selection helpers [adapted from upstream KernelVPN tests]."""

    def test_compressed_index_supplies_legacy_kernel_abi(self):
        for abi in ('exact', 'wrong'):
            with self.subTest(abi=abi), tempfile.TemporaryDirectory() as directory:
                directory = Path(directory).as_posix()
                Path(directory, 'feed').write_bytes(gzip.compress((
                    'Package: kernel\nVersion: 4.1.38-1-' + abi + '\n\n'
                    'Package: kmod-tun\nVersion: 4.1.38-1\n\n').encode()))
                helper = kernel_helpers().replace('/var/opkg-lists', directory).replace('/usr/lib/opkg/lists', directory).replace('/etc/opkg', directory + '/opkg')
                script = helper + '''
uname() { echo 4.1.38; }
opkg() {
  case "$1" in
    status) echo 'Version: 4.1.38-1-exact' ;;
    list) echo 'kmod-tun - 4.1.38-1' ;;
    info) printf '%s\\n' 'Version: 4.1.38-1' 'Depends: kernel' ;;
  esac
}
modgui_kernel_package '^kmod-tun(-|$)'
'''
                result = run_sh(script)
                self.assertEqual(result.stdout.strip(), 'kmod-tun' if abi == 'exact' else '')

    def test_pinned_module_is_preferred_over_legacy_generic(self):
        script = kernel_helpers() + '''
uname() { echo 4.1.38; }
opkg() {
  case "$1 $2" in
    'status kernel') echo 'Version: 4.1.38-1-exact' ;;
    'list ') printf '%s\\n' 'kmod-tun - 4.1.38-1' 'kmod-tun-specific - 4.1.38-1' ;;
    'info kmod-tun') printf '%s\\n' 'Version: 4.1.38-1' 'Depends: kernel' ;;
    'info kmod-tun-specific') printf '%s\\n' 'Version: 4.1.38-1' 'Depends: kernel (= 4.1.38-1-exact)' ;;
  esac
}
modgui_kernel_package '^kmod-tun(-|$)'
'''
        result = run_sh(script)
        self.assertEqual(result.stdout.strip(), 'kmod-tun-specific')

    def test_unpinned_module_without_abi_evidence_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory).as_posix()
            helper = kernel_helpers().replace('/var/opkg-lists', directory).replace('/usr/lib/opkg/lists', directory).replace('/etc/opkg', directory + '/opkg')
            script = helper + '''
uname() { echo 4.1.38; }
opkg() {
  case "$1" in
    status) echo 'Version: 4.1.38-1-exact' ;;
    list) echo 'kmod-tun - 4.1.38-1' ;;
    info) printf '%s\\n' 'Version: 4.1.38-1' 'Depends: kernel' ;;
  esac
}
modgui_kernel_package '^kmod-tun(-|$)'
'''
            result = run_sh(script)
            self.assertEqual(result.stdout, '')
            self.assertIn('Unverified kernel ABI', result.stderr)


@unittest.skipUnless(SH, 'sh required')
class LegacyTun(unittest.TestCase):
    def test_gui_owned_unpinned_tun_migrates_only_when_unused(self):
        source = tun_helpers()
        for busy, failed in ((False, False), (True, False), (False, True)):
            with self.subTest(busy=busy, failed=failed), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'etc/modules.d').mkdir(parents=True)
                (root / 'etc/.modgui-tun-installed').touch()
                private = source.replace('/etc/', str(root / 'etc').replace('\\', '/') + '/')
                script = private + '''
modgui_tun_profile() { return 1; }
modgui_tun_migrate_owners() { :; }
modgui_reviewed_tun_build() { return 1; }
modgui_kernel_package() { echo kmod-tun; }
modgui_kernel_abi_matches() { printf '%s' "$2" | command grep -q exact; }
modgui_has_tun() { return 0; }
modgui_wait_tun() { return 0; }
grep() { if [ "$3" = /proc/modules ]; then return 0; else command grep "$@"; fi; }
rmmod() { echo UNLOAD; return "$busy"; }
modprobe() { echo LOAD; }
opkg() {
 case "$1" in
 status) echo 'Status: install ok installed'; [ "$upgraded" != 1 ] || echo 'Depends: kernel (= exact)' ;;
 install) echo "INSTALL:$2"; [ "$failed" = 0 ] || return 1; upgraded=1 ;;
 esac
}
busy="$1"
failed="$2"
upgraded=0
modgui_install_tun openvpn
'''
                result = run_sh(script, (str(int(busy)), str(int(failed))))
                self.assertEqual(result.returncode == 0, not busy and not failed, result.stderr)
                self.assertIn('UNLOAD', result.stdout)
                self.assertEqual('INSTALL:kmod-tun' in result.stdout, not busy)
                self.assertEqual('LOAD' in result.stdout.splitlines(), not busy)
                if not busy and not failed:
                    self.assertEqual((root / 'etc/.modgui-tun-package-installed').read_text().strip(), 'kmod-tun')

    def test_reviewed_tun_still_installs_new_openvpn_runtime_dependencies(self):
        source = INSTALLER.read_text()
        start = source.index('      openvpn_runtime_deps=""')
        end = source.index('    else\n      opkg install openvpn-openssl', start)
        block = source[start:end]
        for modern in (False, True):
            with self.subTest(modern=modern):
                dependencies = 'libc, kmod-tun, liblzo' + (', libcap-ng (>= 0.8), liblz4' if modern else '')
                script = "opkg() { if [ \"$1\" = info ]; then echo 'Depends: " + dependencies + "'; else echo \"$*\"; fi; }\n" + block
                result = run_sh(script)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual('libcap-ng' in result.stdout, modern)
                self.assertEqual('liblz4' in result.stdout, modern)
                self.assertIn('install --nodeps --force-depends openvpn-openssl', result.stdout)

    def test_existing_device_node_does_not_bypass_abi_validation(self):
        source = tun_helpers()
        script = source + '''
modgui_tun_profile() { return 1; }
modgui_tun_migrate_owners() { :; }
modgui_reviewed_tun_build() { return 1; }
modgui_kernel_package() { echo kmod-tun-specific; }
modgui_has_tun() { echo UNEXPECTED_DEVICE_PROBE; return 0; }
opkg() {
 [ "$2" != kmod-tun ] || printf '%s\\n' 'Status: install ok installed' 'Depends: kernel'
}
modgui_install_tun openvpn
'''
        result = run_sh(script)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('UNEXPECTED_DEVICE_PROBE', result.stdout)
        self.assertIn('unverified TUN', result.stdout)

    def test_waits_for_delayed_hotplug_and_bounds_failure(self):
        source = INSTALLER.read_text()
        wait = source[source.index('modgui_wait_tun() {'):source.index('\nmodgui_reviewed_tun_build()')]
        for ready, success in [(1, True), (3, True), (99, False)]:
            script = '''
attempts=0; sleeps=0
modgui_has_tun() { attempts=$((attempts + 1)); [ "$attempts" -ge "''' + str(ready) + '''" ]; }
sleep() { sleeps=$((sleeps + 1)); }
''' + wait
            script += '\nmodgui_wait_tun; result=$?; [ "$sleeps" -le 3 ] || exit 99; exit "$result"'
            result = run_sh(script)
            self.assertEqual(result.returncode == 0, success, result.stderr)

    def test_arm_tun_download_retains_legacy_tls_and_verifies_module(self):
        prefix = tun_helpers()
        for corrupt in (False, True):
            with self.subTest(corrupt=corrupt), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'etc/modules.d').mkdir(parents=True)
                (root / 'tmp').mkdir()
                data = b'reviewed ARM module fixture'
                (root / 'download.ko').write_bytes(data + (b'corrupt' if corrupt else b''))
                private = prefix.replace('374b8399951a4fa75a0b9c68b6eced9d064cc442d3150d2210d75623c275354e', hashlib.sha256(data).hexdigest())
                # Rewrite once so a Linux /tmp fixture root is not rewritten again.
                private = re.sub(r'/etc/|/lib/modules/|/tmp/', lambda match: root.as_posix() + match[0], private)
                script = '''
testroot="$1"
uname() { if [ "$1" = -m ]; then echo armv7l; else echo 4.1.52; fi; }
uci() { echo 19.4; }
''' + private + '''
curl() {
 [ "$1" = -kfL ] || return 90
 [ "$2" = 'https://raw.githubusercontent.com/FrancYescO/GUI_ipk/1587d4a113de414f4409ea80b11a8d03c115f17c/artifacts/tun-vbntj-damson-4.1.52.ko' ] || return 91
 cp "$testroot/download.ko" "$4"
}
modgui_has_tun() { [ -f "$testroot/loaded" ]; }
modprobe() { touch "$testroot/loaded"; }
lsmod() { [ ! -f "$testroot/loaded" ] || echo 'tun 100 0'; }
rmmod() { rm -f "$testroot/loaded"; }
modgui_install_tun openvpn || exit 1
modgui_release_tun openvpn
'''
                result = run_sh(script, (root.as_posix(),))
                self.assertEqual(result.returncode, 0 if not corrupt else 1, result.stdout + result.stderr)
                self.assertFalse((root / 'lib/modules/4.1.52/tun.ko').exists())
                self.assertFalse((root / 'loaded').exists())
                self.assertFalse(list((root / 'tmp').iterdir()))

    def test_gui_and_installer_agree_on_supported_platforms(self):
        source = INSTALLER.read_text()
        for path in ('www/docroot/modals/applications-modal.lp', 'www/cards/009_extensions.lp'):
            gui = (ROOT / path).read_text()
            self.assertIn('TunSupported', gui)
            self.assertNotIn('appInstallRemoveUtility.sh check tun', gui)
        mapping = (ROOT / 'usr/share/transformer/mappings/rpc/system.modgui.map').read_text()
        self.assertIn('TunSupported = function() return vpn_supported("tun") end', mapping)
        start = source.rindex('case "$1" in\ncheck)')
        definitions, dispatch = source[:start], source[start:]
        # The fork preserves an armv7l-only reviewed TUN build: MIPS gateways
        # rely on opkg candidate resolution instead, so `check tun` passes on
        # MIPS only when a matching kernel package is available.
        for cpu, kernel, version, available, expected in (
            ('mips', '3.4.11-rt19', '17.2', False, False),
            ('mips', '3.4.11-rt19', '16.3', False, False),
            ('mips', '3.4.11-rt19', '17.20', False, False),
            ('armv7l', '4.1.52', '19.4', False, True),
            ('armv7l', '4.1.38', '18.3', False, False),
            ('armv7l', '4.1.38', '18.3', True, True),
        ):
            with self.subTest(cpu=cpu, kernel=kernel, available=available):
                setup = '\n'.join((
                    'test_cpu="$1"; test_kernel="$2"; test_version="$3"; available="$4"',
                    'uname() { if [ "$1" = -m ]; then echo "$test_cpu"; else echo "$test_kernel"; fi; }',
                    'uci() { echo "$test_version"; }',
                ))
                mocks = '\n'.join((
                    'modgui_has_tun() { return 1; }',
                    'modgui_kernel_package() { [ "$available" = 1 ] && echo kmod-tun-profile; }',
                    'set -- check tun',
                ))
                script = setup + '\n' + definitions + '\n' + mocks + '\n' + dispatch
                result = run_sh(script, (cpu, kernel, version, str(int(available))))
                self.assertEqual(result.returncode == 0, expected, result.stderr)

    def test_tcp_server_uses_server_mode_and_tcp_firewall_protocol(self):
        source = (ROOT / 'usr/share/transformer/scripts/openvpnApply.sh').read_text()
        block = source[source.index('case "$proto" in'):]
        block = block[:block.index('\nesac') + len('\nesac')]
        for proto, expected in [('udp', 'udp:udp'), ('tcp', 'tcp:tcp-server'), ('tcp-server', 'tcp:tcp-server')]:
            result = subprocess.run([SH, '-c', 'proto="$1"\n' + block + '\necho "$proto:$server_proto"', 'check', proto],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), expected)


if __name__ == '__main__':
    unittest.main()
