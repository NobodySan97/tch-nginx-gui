"""Exercise the real TUN lifecycle with simulated kernel commands and private paths.

Ported from [upstream 4074838d, bf0d28eb, bae7baa9] and adapted to the fork's
preserved shared-lifecycle (curl+sha256 verified download, POSIX/subshell
patterns), extended with the legacy MIPS gap completion from [upstream
184b19d8, 155e5540]: verified MIPS TUN/OpenSSL/DH downloads, WireGuard MIPS
repackaging, conditional network cleanup, TLS option whitelisting and shared
TUN release on failure. Tests follow the fork's Windows sh harness.
"""
from pathlib import Path
import bz2
import gzip
import hashlib
import io
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
INSTALLER = ROOT / 'usr/share/transformer/scripts/appInstallRemoveUtility.sh'
LUA = shutil.which('lua') or shutil.which('luajit')


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


def _msys_path(p):
    """Convert a "C:/Users/..." path to "/c/Users/...": MSYS sh silently
    ignores C:/ style entries inside PATH-like contexts."""
    p = str(p).replace(os.sep, '/')
    if len(p) >= 3 and p[1:2] == ':':
        return '/' + p[0].lower() + p[2:]
    return p


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
        self.assertIn('WireGuardSupported = function() return vpn_supported("wireguard") end', mapping)
        predicate = source[source.index('modgui_reviewed_tun_build() {'):source.index('\nmodgui_tun_profile()')]
        # Upstream 155e5540: the reviewed TUN build covers also the legacy MIPS
        # gateways selected by CPU + kernel + Homeware 17.2, without model-name
        # checks, so `check tun` passes before the module is installed.
        self.assertNotIn('prod_friendly_name', predicate)
        for cpu, kernel, version, expected in (
            ('mips', '3.4.11-rt19', '17.2', True),
            ('mips', '3.4.11-rt19', '17.2.1', True),
            ('mips', '3.4.11-rt19', '17.2 Mint', True),
            ('mips', '3.4.11-rt19', '16.3', False),
            ('mips', '3.4.11-rt19', '17.20', False),
            ('mips', '3.4.11', '17.2', False),
            ('mipsel', '3.4.11-rt19', '17.2', False),
            ('armv7l', '4.1.52', '19.4', True),
            ('armv7l', '4.1.38', '18.3', False),
        ):
            with self.subTest(cpu=cpu, kernel=kernel, version=version):
                setup = '\n'.join((
                    'test_cpu="$1"; test_kernel="$2"; test_version="$3"; cpu_type="$test_cpu"; marketing_version="$test_version"',
                    'uname() { if [ "$1" = -m ]; then echo "$test_cpu"; else echo "$test_kernel"; fi; }',
                    'uci() { case "$*" in *marketing_version*) echo "$test_version";; *) echo unexpected-model-lookup >&2; return 99; esac; }',
                    'modgui_has_tun() { return 1; }',
                    'modgui_kernel_package() { :; }',
                    'set -- check tun',
                ))
                start = source.rindex('case "$1" in\ncheck)')
                dispatch = source[start:]
                script = setup + '\n' + predicate + '\n' + dispatch
                result = run_sh(script, (cpu, kernel, version))
                self.assertEqual(result.returncode == 0, expected, result.stderr)

    def test_tailscale_cleanup_waits_for_exit_and_removes_only_its_rules(self):
        source = (ROOT / 'usr/share/modgui-tailscale/tailscale.init').read_text()
        functions = source[source.index('service_stopped() {'):]
        rules = """0: from all lookup local
5210: from all fwmark 0x80000/0xff0000 lookup main
5210: from all fwmark 0x80000/0xff0000 lookup main
5230: from all fwmark 0x80000/0xff0000 lookup default
5250: from all fwmark 0x80000/0xff0000 unreachable
5270: from all lookup 52
5210: from all fwmark 0x10000000/0xf0000000 lookup voip
5270: from all lookup main
5270: from 10.0.0.0/8 lookup 52
6000: from all lookup 52
"""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'rules').write_text(rules, newline='\n')
            script = '''
log="$1"; rules="$2"
pidof() { [ "$running" = 1 ]; }
sleep() { echo waiting >> "$log"; running=0; }
ip() {
 if [ "$2 $3" = 'rule show' ]; then cat "$rules";
 else echo "$*" >> "$log"; fi
}
''' + functions + '\nrunning=1\nservice_stopped\n'
            result = run_sh(script, ((root / 'log').as_posix(), (root / 'rules').as_posix()))
            self.assertEqual(result.returncode, 0, result.stderr)
            lines = (root / 'log').read_text().splitlines()
            self.assertEqual(lines[0], 'waiting')
            for family in ('-4', '-6'):
                expected = [
                    f'{family} rule del pref 5210 fwmark 0x80000/0xff0000 table main',
                    f'{family} rule del pref 5210 fwmark 0x80000/0xff0000 table main',
                    f'{family} rule del pref 5230 fwmark 0x80000/0xff0000 table default',
                    f'{family} rule del pref 5250 fwmark 0x80000/0xff0000 unreachable',
                    f'{family} rule del pref 5270 table 52',
                ]
                self.assertEqual([line for line in lines if line.startswith(family)], expected)
            (root / 'log').unlink()
            blocked = 'log="$1"\npidof() { return 0; }\nsleep() { :; }\nip() { echo unexpected >> "$log"; }\n' + functions + '\nservice_stopped\n'
            result = run_sh(blocked, ((root / 'log').as_posix(),))
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root / 'log').exists(), 'Never clean rules while the daemon is alive')

    def test_disabled_wireguard_removal_does_not_reload_unrelated_networks(self):
        source = INSTALLER.read_text()
        start = source.index('  wireguard_cleanup_network() {')
        original = source[start:source.index('\n  case "$1" in', start)]
        for configured in (False, True):
            with self.subTest(configured=configured), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                reloads = (root / 'reloads').as_posix()
                function = original.replace('/etc/init.d/network reload >/dev/null 2>&1', 'echo network >> "' + reloads + '"')
                function = function.replace('/etc/init.d/firewall reload >/dev/null 2>&1', 'echo firewall >> "' + reloads + '"')
                script = '''
configured="$1"
uci() {
 if [ "$*" = '-q show network' ]; then
  [ "$configured" = 1 ] && echo 'network.modgui_wg0=interface'
 elif [ "$*" = '-q show firewall' ]; then
  [ "$configured" = 1 ] && echo 'firewall.modgui_wireguard_zone=zone'
 fi
 return 0
}
''' + function + '\nwireguard_cleanup_network\n'
                result = run_sh(script, (str(int(configured)),))
                self.assertEqual(result.returncode, 0, result.stderr)
                if configured:
                    self.assertEqual((root / 'reloads').read_text().splitlines(), ['network', 'firewall'])
                else:
                    self.assertFalse((root / 'reloads').exists())

    def test_mips_wireguard_archive_is_verified_and_owned_by_opkg(self):
        source = INSTALLER.read_text()
        function = source[source.index('  wireguard_prepare_mips_package() {'):source.index('\n  wireguard_register_gui()')]
        runtime_files = ['usr/bin/wireguard-go', 'usr/bin/wg-go', 'usr/bin/wg',
                         'lib/netifd/proto/wireguard.sh', 'etc/hotplug.d/net/10-wireguard']
        for corrupt in (False, True):
            with self.subTest(corrupt=corrupt), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                # GNU tar (MSYS) treats "C:" as a remote host; use the /c/ form.
                testroot = _msys_path(root)
                archive_path = root / 'runtime.tgz'
                with tarfile.open(archive_path, 'w:gz') as archive:
                    for name in runtime_files + ['etc/sysctl.d/99-wireguard.conf']:
                        entry = tarfile.TarInfo(name)
                        entry.size = 7
                        archive.addfile(entry, io.BytesIO(b'runtime'))
                checksum = hashlib.sha256(archive_path.read_bytes()).hexdigest()
                script = '''
wireguard_version=2023.09.29
wireguard_tmp="$1/package.ipk"
wireguard_sha256="$2"
testroot="$1"
curl() { cp "$testroot/runtime.tgz" "$4"; }
'''
                script += function.replace('/tmp/modgui-wireguard-mips.', testroot + '/stage.')
                script += '\nwireguard_prepare_mips_package\n'
                result = run_sh(script, (testroot, 'invalid' if corrupt else checksum))
                self.assertEqual(result.returncode == 0, not corrupt, result.stderr)
                self.assertFalse(list(root.glob('stage.*')))
                if corrupt:
                    self.assertFalse((root / 'package.ipk').exists())
                    continue
                with tarfile.open(root / 'package.ipk') as package:
                    self.assertEqual(package.extractfile('debian-binary').read(), b'2.0\n')
                    with tarfile.open(fileobj=package.extractfile('control.tar.gz')) as control:
                        metadata = control.extractfile('control').read().decode()
                        self.assertIn('Package: wireguard-go\n', metadata)
                        self.assertIn('Architecture: brcm63xx\n', metadata)
                    with tarfile.open(fileobj=package.extractfile('data.tar.gz')) as data:
                        self.assertEqual(set(data.getnames()), set(runtime_files))

    def test_openvpn_init_supports_inline_and_external_option_lists(self):
        source = INSTALLER.read_text()
        function = source[source.index('  openvpn_prepare_init() {'):source.index('\n  openvpn_prepare_dh()')]
        for layout in ('inline', 'external', 'external-existing', 'external-missing', 'unknown'):
            with self.subTest(layout=layout), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                service, options = root / 'init', root / 'options'
                external = '. ' + options.as_posix() + '\n'
                if layout.startswith('external'):
                    service.write_text(external, newline='\n')
                    if layout != 'external-missing':
                        options.write_text("OPENVPN_PARAMS='tls_cipher" + (' tls_version_min' if layout == 'external-existing' else '') + "'\n", newline='\n')
                else:
                    service.write_text("OPENVPN_PARAMS='" + ('tls_cipher' if layout == 'inline' else 'cipher') + "'\n", newline='\n')
                before = service.read_bytes(), options.read_bytes() if options.exists() else None
                private = function.replace('/etc/init.d/openvpn', service.as_posix()).replace('/usr/share/openvpn/openvpn.options', options.as_posix())
                script = private + '\nopenvpn_prepare_init\n'
                result = run_sh(script)
                supported = layout not in ('external-missing', 'unknown')
                self.assertEqual(result.returncode == 0, supported, result.stderr)
                if supported:
                    active = options if layout.startswith('external') else service
                    self.assertEqual(active.read_text().count('tls_version_min'), 1)
                    result = run_sh(script)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(active.read_text().count('tls_version_min'), 1)
                if layout == 'external-existing':
                    self.assertEqual(options.read_bytes(), before[1])

    def test_web_reload_waits_for_transformer_and_stops_on_timeout(self):
        source = INSTALLER.read_text()
        original = source[source.index('  openvpn_restart_services() {'):source.index('\n  openvpn_prepare_init()')]
        for ready in (True, False):
            with self.subTest(ready=ready), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                events = (root / 'events').as_posix()
                # The transformer invocation is replaced by a logged no-op; only
                # the readiness probe is a mocked lua call.
                function = original.replace('/etc/init.d/transformer restart', 'echo transformer >> "' + events + '"')
                script = '''
attempts=0
lua() { attempts=$((attempts + 1)); [ "$1" = -e ] || return 1; [ "$attempts" -ge 3 ] && ''' + ('true' if ready else 'false') + '''; }
sleep() { :; }
nginx() { echo "nginx $*" >> "''' + events + '''"; }
''' + function + '\nopenvpn_restart_services\n'
                result = run_sh(script)
                self.assertEqual(result.returncode == 0, ready, result.stderr)
                expected = ['transformer', 'nginx -t', 'nginx -s reload'] if ready else ['transformer']
                self.assertEqual((root / 'events').read_text().splitlines(), expected)

    def test_dh_download_verifies_checksum_and_preserves_existing_parameters(self):
        source = INSTALLER.read_text()
        function = source[source.index('  openvpn_prepare_dh() {'):source.index('\n  openvpn_prepare_openssl()')]
        self.assertIn('mozilla/ssl-config-generator/99178dcaf7e1c0e5a0b5f783b1767cc47e1bf3e7/', function)
        for scenario in ('download', 'corrupt', 'existing'):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                params = b'public DH fixture\n'
                (root / 'download.pem').write_bytes(params + (b'corrupt' if scenario == 'corrupt' else b''))
                if scenario == 'existing':
                    (root / 'vpn').mkdir()
                    (root / 'vpn/dh2048.pem').write_bytes(b'user parameters')
                private = function.replace('/etc/openvpn', (root / 'vpn').as_posix()).replace('/tmp/modgui-openvpn-dh.', root.as_posix() + '/stage.')
                private = private.replace('2ef7758563185ad0dc1dbc38ab3a91647701e3ebee344fcf86b52e643bacb721',
                                          hashlib.sha256(params).hexdigest())
                script = 'testroot="$1"\ncurl() { cp "$testroot/download.pem" "$4"; }\n' + private + '\nopenvpn_prepare_dh\n'
                result = run_sh(script, (root.as_posix(),))
                self.assertEqual(result.returncode == 0, scenario != 'corrupt', result.stderr)
                self.assertFalse(list(root.glob('stage.*')))
                if scenario != 'corrupt':
                    self.assertEqual((root / 'vpn/dh2048.pem').read_bytes(), b'user parameters' if scenario == 'existing' else params)
                else:
                    self.assertFalse((root / 'vpn/dh2048.pem').exists())

    def test_split_easy_rsa_two_layout_generates_keys_and_preserves_existing_pki(self):
        source = (ROOT / 'usr/share/transformer/scripts/openvpnGenerateKeys.sh').read_text()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            easy, binary, vpn = root / 'easy', root / 'bin', root / 'vpn'
            easy.mkdir(); binary.mkdir(); vpn.mkdir()
            (vpn / 'dh2048.pem').write_text('public DH fixture\n')
            (easy / 'vars').write_text('export KEY_DIR="' + (easy / 'keys').as_posix() + '"\n')
            scripts = {
                'clean-all': '#!/bin/sh\nmkdir -p "' + (easy / 'keys').as_posix() + '"\n',
                'pkitool': '#!/bin/sh\necho call >> "' + (root / 'calls').as_posix() + '"\n' +
                    'for file in ca.crt server.crt server.key client.crt client.key; do echo key > "' + (easy / 'keys').as_posix() + '/$file"; done\n',
                'openssl': '#!/bin/sh\n[ "$1" = dhparam ] && [ "$4" = 2048 ] || exit 1\necho dh > "$3"\n',
            }
            for name, contents in scripts.items():
                path = binary / name
                path.write_text(contents, newline='\n')
                path.chmod(0o755)
            source = source.replace('/etc/easy-rsa', easy.as_posix()).replace('/etc/openvpn', vpn.as_posix())
            source = source.replace('/usr/sbin/pkitool', (binary / 'pkitool').as_posix()).replace('/usr/sbin/clean-all', (binary / 'clean-all').as_posix())
            # A dev-shell PATH may not contain the mock commands; bake it in
            # (MSYS ignores C:/ style PATH entries, so use the /c/ form).
            dev_binary = _msys_path(root / 'bin') if sys.platform == 'win32' else root.as_posix()
            script = root / 'generate.sh'
            script.write_text('#!/bin/sh\nPATH="' + dev_binary + ':/usr/bin:/bin:$PATH"\n' + source, newline='\n')
            command = [SH, _msys_path(script) if sys.platform == 'win32' else script.as_posix()]
            for _ in range(2):
                result = subprocess.run(command, capture_output=True, text=True, timeout=60)
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / 'calls').read_text().splitlines(), ['call'] * 3)
            if sys.platform != 'win32':
                self.assertEqual((vpn / 'server.key').stat().st_mode & 0o777, 0o600)
            self.assertEqual(len(list(vpn.iterdir())), 6)
            original_ca = (vpn / 'ca.crt').read_bytes()
            original_key = (vpn / 'server.key').read_bytes()
            (vpn / 'client.crt').unlink()
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Incomplete existing OpenVPN PKI', result.stderr)
            self.assertEqual((vpn / 'ca.crt').read_bytes(), original_ca)
            self.assertEqual((vpn / 'server.key').read_bytes(), original_key)
            self.assertFalse((vpn / 'client.crt').exists())

    def test_private_openssl_selects_architecture_and_rejects_corruption(self):
        source = INSTALLER.read_text()
        function = source[source.index('  openvpn_prepare_openssl() {'):source.index('\n  openvpn_register_gui()')]
        for cpu, corrupt in [('mips', False), ('armv7l', False), ('mips', True)]:
            with self.subTest(cpu=cpu, corrupt=corrupt), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                # GNU tar (MSYS) treats "C:" as a remote host; use the /c/ form.
                testroot = _msys_path(root)
                with tarfile.open(root / 'data.tar.gz', 'w:gz') as archive:
                    item = tarfile.TarInfo('usr/lib/private-marker')
                    item.size = 2
                    archive.addfile(item, io.BytesIO(b'ok'))
                with tarfile.open(root / 'package.ipk', 'w:gz') as archive:
                    archive.add(root / 'data.tar.gz', arcname='data.tar.gz')
                script = '''
cpu_type="$1"; testroot="$2"; corrupt="$3"
openvpn_openssl_lib="$testroot/private"
modgui_tun_commit=reviewed
openvpn_openssl_sha256=arm-digest
modgui_reviewed_tun_build() { return 0; }
openssl() { [ "${LD_LIBRARY_PATH:-}" = "$openvpn_openssl_lib/usr/lib" ] && [ -f "$openvpn_openssl_lib/usr/lib/private-marker" ]; }
curl() { echo "$2" > "$testroot/url"; cp "$testroot/package.ipk" "$4"; }
sha256sum() { if [ "$corrupt" = True ]; then echo bad; else echo "$openvpn_openssl_sha256"; fi; }
''' + function.replace('/tmp/modgui-openvpn-ssl.', testroot + '/stage.')
                script += '\nopenvpn_prepare_openssl\n'
                result = run_sh(script, (cpu, testroot, str(corrupt)))
                self.assertEqual(result.returncode == 0, not corrupt, result.stderr)
                self.assertEqual(bool(list(root.glob('stage.*'))), False)
                self.assertEqual((root / 'private/usr/lib/private-marker').exists(), not corrupt)
                url = (root / 'url').read_text()
                self.assertIn('brcm63xx.ipk' if cpu == 'mips' else 'arm_cortex-a9_neon.ipk', url)

    def test_openvpn_storage_reserve_matches_runtime_architecture(self):
        source = INSTALLER.read_text()
        function = source[source.index('app_openvpn() {'):source.index('\napp_tailscale()')]
        for cpu, reserve in [('mips', '4096'), ('armv7l', '16384')]:
            script = '''
cpu_type="$1"
opkg() { return 0; }
require_free_space() { echo "$1"; return 1; }
''' + function + '\napp_openvpn install\n'
            result = run_sh(script, (cpu,))
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout.strip(), reserve)

    def test_vpn_module_and_dh_parameters_are_not_bundled(self):
        self.assertFalse((ROOT / 'usr/share/modgui-vpn/tun-mips-3.4.11-rt19.ko.gz').exists())
        self.assertFalse((ROOT / 'usr/share/modgui-openvpn/dh2048.pem').exists())
        source = INSTALLER.read_text()
        self.assertIn('https://alastair.d-silva.org/sites/default/files/2023-04/mips.tun_.ko_.tbz', source)
        self.assertIn('modgui_tun_archive_sha256="ff673e7841df6de1dc0d3595352c17eb375480be2f93406b2aa596c8f7afa698"', source)

    @unittest.skipUnless(shutil.which('bzcat') or shutil.which('bzip2') or
                         (SH and subprocess.run([SH, '-c', 'PATH="/usr/bin:/bin:$PATH"; command -v bzcat >/dev/null 2>&1'],
                                                capture_output=True).returncode == 0),
                         'bzcat or bzip2 required')
    def test_install_rejects_corruption_and_preserves_other_consumers(self):
        prefix = tun_helpers()
        for scenario in ['shared', 'corrupt', 'module-corrupt', 'download-failure', 'decompress-failure', 'preexisting', 'load-failure', 'in-use']:
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                # GNU tar (MSYS) treats "C:" as a remote host; use the /c/ form.
                testroot = _msys_path(root)
                for path in ['etc/modules.d', 'lib/modules/3.4.11-rt19', 'tmp']:
                    (root / path).mkdir(parents=True, exist_ok=True)
                data = b'reviewed module fixture'
                module_data = data + b'corrupt' if scenario == 'module-corrupt' else data
                stream = io.BytesIO()
                with tarfile.open(fileobj=stream, mode='w') as archive:
                    entry = tarfile.TarInfo('tun.ko'); entry.size = len(module_data)
                    archive.addfile(entry, io.BytesIO(module_data))
                downloaded = bz2.compress(stream.getvalue())
                (root / 'download.tbz').write_bytes(downloaded + (b'corrupt' if scenario == 'corrupt' else b''))
                module = root / 'lib/modules/3.4.11-rt19/tun.ko'
                if scenario == 'preexisting':
                    module.write_text('user-owned module')
                prefix_private = prefix.replace('241f06c8ba05e6779438520a345ab8fc6f7d1f34249abac77793ee26e67e5615',
                                                hashlib.sha256(data).hexdigest())
                prefix_private = prefix_private.replace('ff673e7841df6de1dc0d3595352c17eb375480be2f93406b2aa596c8f7afa698',
                                                        hashlib.sha256(downloaded).hexdigest())
                # Rewrite in one pass: a Linux /tmp fixture root itself
                # contains "/tmp/", so sequential str.replace() would re-match
                # the "/tmp/" inserted by earlier passes and double the root
                # (same pitfall avoided by re.sub in the ARM download test).
                prefix_private = re.sub(r'/etc/|/lib/modules/|/tmp/',
                                        lambda match: testroot + match[0], prefix_private)
                setup = '''
testroot="$1"; scenario="$2"
uname() { if [ "$1" = -m ]; then echo mips; else echo 3.4.11-rt19; fi; }
uci() { case "$*" in *marketing_version*) echo 17.2;; *) return 0 ;; esac; }
'''
                mock = '''
modgui_has_tun() { [ -f "$testroot/loaded" ]; }
modprobe() { [ "$scenario" != load-failure ] || return 1; touch "$testroot/loaded"; }
insmod() { modprobe "$@"; }
lsmod() { [ ! -f "$testroot/loaded" ] || echo 'tun 22900 0'; }
rmmod() { [ "$scenario" != in-use ] || return 1; rm -f "$testroot/loaded"; }
opkg() { echo unexpected-opkg >&2; return 99; }
curl() { [ "$scenario" != download-failure ] || return 1; cp "$testroot/download.tbz" "$4"; }
if command -v bzcat >/dev/null 2>&1; then :; else bzcat() { bzip2 -dc "$@"; }; fi
bzcat() { [ "$scenario" != decompress-failure ] || return 1; command bzcat "$@"; }
if modgui_install_tun openvpn; then
  [ "$scenario" = shared ] || [ "$scenario" = in-use ] || exit 10
  modgui_install_tun wireguard || exit 11
  modgui_release_tun openvpn || exit 12
  [ -f "$modgui_tun_file" ] && [ -f "$testroot/loaded" ] || exit 13
  modgui_release_tun wireguard || exit 14
  if [ "$scenario" = in-use ]; then
    [ -f "$modgui_tun_file" ] && [ -f "$modgui_tun_owned" ] || exit 15
  else
    [ ! -e "$modgui_tun_file" ] && [ ! -e "$modgui_tun_owned" ] || exit 16
  fi
else
  case "$scenario" in corrupt|module-corrupt|download-failure|decompress-failure|preexisting|load-failure) ;; *) exit 17;; esac
  [ ! -e "$testroot/loaded" ] || exit 18
fi
'''
                result = run_sh(setup + prefix_private + mock, (testroot, scenario))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if scenario == 'preexisting':
                    self.assertEqual(module.read_text(), 'user-owned module')
                elif scenario in ['corrupt', 'module-corrupt', 'download-failure', 'decompress-failure', 'load-failure']:
                    self.assertFalse(module.exists())
                self.assertEqual(list((root / 'tmp').iterdir()), [])

    @unittest.skipUnless(LUA, 'lua or luajit required')
    def test_connected_count_rpc_reads_private_status_without_exposing_it(self):
        source = (ROOT / 'usr/share/transformer/mappings/rpc/openvpn.map').read_text()
        script = '''
local objects, status, closed = {}, nil, false
register = function(object) objects[object.objectType.name] = object end
io.open = function(path)
 assert(path == '/tmp/openvpn-status.log')
 if not status then return nil end
 return {lines = function() return status:gmatch('[^\\n]+') end, close = function() closed = true end}
end
assert((loadstring or load)(SOURCE))()
local object = objects['rpc.openvpn.server.']
assert(object.objectType.parameters.connected_clients.access == 'readOnly')
assert(object.get.connected_clients() == '0')
status = 'Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since\\nuser,peer:12,1,2,date\\n10.8.0.6,user,peer:12,date\\n'
assert(object.get.connected_clients() == '1' and closed)
status = 'HEADER,CLIENT_LIST,fields\\nCLIENT_LIST,user,peer,1,2\\nCLIENT_LIST\\tuser2\\tpeer2\\t3\\t4\\n'
assert(object.get.connected_clients() == '2')
'''.replace('SOURCE', repr(source))
        result = subprocess.run([LUA, '-'], input=script, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        card = (ROOT / 'www/cards/015_openvpn-server.lp').read_text()
        self.assertNotIn('io.open("/tmp/openvpn-status.log"', card)
        self.assertIn('rpc.openvpn.server.connected_clients', card)

    @unittest.skipUnless(shutil.which('lua') or shutil.which('luajit'), 'lua or luajit required')
    def test_client_cipher_choices_and_validation_follow_runtime_capabilities(self):
        source = (ROOT / 'www/docroot/modals/openvpn-server-modal.lp').read_text()
        block = source[source.index('  local cipher_options,'):]
        block = block[:block.index('  local map_params')]
        validator = source[source.index('  local function valid_cipher(value)'):source.index('  local function valid_auth(value)')]
        for modern in (False, True):
            setup = '''
local closed = false
T = function(s) return s end
local sample = 'AES-256-CBC 256 bit key\\nDES-CBC 64 bit key\\n' .. EXTRA
io = {popen = function(command)
 assert(command == '/usr/sbin/openvpn --show-ciphers 2>/dev/null')
 return {lines = function() return sample:gmatch('[^\\n]+') end,
 close = function() closed = true end}
end}
'''.replace('EXTRA', repr('AES-256-GCM 256 bit key\n' if modern else ''))
            checks = '''
assert(closed and supported_ciphers['AES-256-CBC'])
assert(not supported_ciphers['DES-CBC'] and not valid_cipher('DES-CBC'))
assert(valid_cipher('AES-256-CBC'))
assert((supported_ciphers['AES-256-GCM'] == true) == MODERN)
'''.replace('MODERN', 'true' if modern else 'false')
            result = subprocess.run([LUA, '-'], input=setup + block + validator + checks,
                                    capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which('lua') or shutil.which('luajit'), 'lua or luajit required')
    def test_exported_profile_matches_server_transport_and_requires_tls_twelve(self):
        source = (ROOT / 'www/docroot/modals/openvpn-server-modal.lp').read_text().split('local tab =')[0]
        setup = '''
gettext = {textdomain = function() end}
T = function(s) return s end
local protocol, output = 'udp', {}
for _, name in ipairs({'web.ui_helper', 'web.post_helper', 'web.uimessage_helper'}) do
 package.preload[name] = function() return {} end
end
package.preload.datamodel = function() return {get = function(path)
 local value = path:match('%.proto$') and protocol or path:match('%.port$') and '1194' or 'test-material'
 return {{value = value}}
end} end
ngx = {header = {}, var = {http_host = 'vpn.example.test'}, HTTP_OK = 200,
 req = {get_uri_args = function() return {download = '1'} end}, exit = function() end,
 print = function(...) for _, v in ipairs({...}) do output[#output + 1] = v end end}
local export = assert((loadstring or load)(SOURCE))
for _, test in ipairs({{'udp', 'udp'}, {'tcp', 'tcp-client'}, {'tcp-server', 'tcp-client'}}) do
 protocol, output = test[1], {}
 export()
 local profile = table.concat(output)
 assert(profile:find('proto ' .. test[2] .. '\\n', 1, true))
 assert(profile:find('tls-version-min 1.2', 1, true))
 assert(profile:find('remote-cert-tls server', 1, true))
end
'''.replace('SOURCE', repr(source))
        result = subprocess.run([LUA, '-'], input=setup, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)

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
