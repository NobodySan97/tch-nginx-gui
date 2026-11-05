"""Exercise feed registration against isolated opkg configuration files."""
from pathlib import Path
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'decompressed/gui_file/etc/modgui_scripts/02_specific.sh'


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


def sh_run(script):
    """Run a POSIX snippet; large scripts must go through a real file on Windows."""
    result = None
    if sys.platform == 'win32' and SH:
        with tempfile.NamedTemporaryFile('w', delete=False, suffix='.sh',
                                         encoding='utf-8', newline='\n') as fh:
            # The dev-shell PATH may not include the msys userland commands.
            fh.write('PATH="/usr/bin:/bin:$PATH"; export PATH\n')
            fh.write(script)
            staged = fh.name
        try:
            result = subprocess.run([SH, staged], capture_output=True, text=True, timeout=60)
        finally:
            try: os.unlink(staged)
            except OSError: pass
        return result
    return subprocess.run(['sh', '-c', script], capture_output=True, text=True)


@unittest.skipUnless(SH, 'sh required')
class OpkgFeeds(unittest.TestCase):
    def test_legacy_kernel_feed_and_its_cached_indexes_are_removed(self):
        source = SOURCE.read_text()
        helper = source[source.index('remove_legacy_kernel_feed()'):source.index('apply_right_opkg_repo()')]
        for ending in ('', '/', ' # obsolete', '/ # obsolete'):
            with self.subTest(ending=ending), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                directory = root / 'opkg'
                directory.mkdir()
                cache = root / 'cache'
                cache.mkdir()
                legacy = 'https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/target/packages' + ending
                conf = root / 'opkg.conf'
                conf.write_text(f'lists_dir ext {cache}\nsrc/gz chaos_calmer_core {legacy}\nsrc/gz keep https://example.invalid/packages\n')
                extra = directory / 'customfeeds.conf'
                extra.write_text(f'src/gz old_custom {legacy}\nsrc/gz userspace https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/base\n')
                for name in ('chaos_calmer_core', 'old_custom', 'keep'):
                    (cache / name).write_text('cached index')
                # Keep every path private, including the default index directories.
                private = helper.replace('/var/opkg-lists', root.as_posix() + '/cache').replace('/tmp/opkg-lists', root.as_posix() + '/cache').replace('/usr/lib/opkg/lists', root.as_posix() + '/cache')
                if shutil.which('gsed'):
                    private = private.replace('sed -i', shutil.which('gsed') + ' -i')
                script = private + f'\nopkg_file={shlex.quote(root.as_posix() + "/opkg.conf")}\nopkg_config_dir={shlex.quote(directory.as_posix())}\nremove_legacy_kernel_feed\nremove_legacy_kernel_feed\n'
                result = sh_run(script)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn('target/packages', conf.read_text())
                self.assertNotIn('target/packages', extra.read_text())
                self.assertIn('src/gz keep ', conf.read_text())
                self.assertIn('kernel-4.1/base', extra.read_text())
                self.assertFalse((cache / 'chaos_calmer_core').exists())
                self.assertFalse((cache / 'old_custom').exists())
                self.assertTrue((cache / 'keep').exists())

    def test_no_install_branch_adds_the_legacy_kernel_feed(self):
        source = SOURCE.read_text()
        apply = source[source.index('apply_right_opkg_repo()'):source.index('ledfw_extract()')]
        self.assertIn('remove_legacy_kernel_feed', apply)
        self.assertNotIn('kernel-4.1/target/packages', apply)

    def test_arm_feed_setup_does_not_reintroduce_legacy_kernel_source(self):
        source = SOURCE.read_text()
        functions = source[source.index('append_missing_opkg_feeds()'):source.index('ledfw_extract()')]
        for version in ('18.3', '19.4'):
            with self.subTest(version=version), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root / 'opkg').mkdir()
                conf = root / 'opkg.conf'
                conf.write_text('src/gz chaos_calmer_core https://raw.githubusercontent.com/Ansuel/GUI_ipk/kernel-4.1/target/packages\n')
                private = functions.replace('/etc/opkg', root.as_posix() + '/opkg')
                for directory in ('/var/opkg-lists', '/tmp/opkg-lists', '/usr/lib/opkg/lists'):
                    private = private.replace(directory, root.as_posix() + '/cache')
                if shutil.which('gsed'):
                    private = private.replace('sed -i', shutil.which('gsed') + ' -i')
                script = private + f'''
logecho() {{ :; }}
cpu_type=armv7l
marketing_version={version}
uname() {{ echo 4.1.38; }}
uci() {{ echo VBNT-O; }}
curl() {{ return 0; }}
opkg() {{ echo 'arch brcm963xx 100'; }}
apply_right_opkg_repo
apply_right_opkg_repo
'''
                sh_run(script)
                result = conf.read_text()
                self.assertNotIn('kernel-4.1/target/packages', result)
                self.assertIn('kernel/4.1.38-vbnto', result)
                self.assertIn('kernel-4.1/base', result)
                # The removed legacy feed also contained LuCI's iwinfo Lua
                # dependency. Keep its published userspace replacement active.
                self.assertEqual(result.count('src/gz modgui_target_userspace https://francyesco.github.io/GUI_ipk/target/packages'), 1)

    def test_vpn_feeds_follow_running_kernel_and_skip_missing_indexes(self):
        source = SOURCE.read_text()
        helper = source[source.index('append_missing_opkg_feeds()'):source.index('apply_right_opkg_repo()')]
        for available in (False, True):
            with self.subTest(available=available), tempfile.TemporaryDirectory() as tmp:
                conf = Path(tmp) / 'opkg.conf'
                conf.touch()
                root = Path(tmp).as_posix()
                script = helper + f'''
opkg_file={shlex.quote(root + "/opkg.conf")}
opkg_config_dir={shlex.quote(root)}
uname() {{ echo 6.6.99-custom; }}
curl() {{ return {0 if available else 1}; }}
opkg() {{ awk '$1 == "arch" {{print "arch", $2, $3}}' "$opkg_file"; }}
append_gui_vpn_feeds
append_gui_vpn_feeds
'''
                result = sh_run(script)
                self.assertEqual(result.returncode, 0, result.stderr)
                lines = conf.read_text().splitlines()
                self.assertEqual(lines.count('src/gz modgui_base https://francyesco.github.io/GUI_ipk/base'), 1)
                self.assertEqual(lines.count('src/gz modgui_target_userspace https://francyesco.github.io/GUI_ipk/target/packages'), 1)
                kernel_feed = 'src/gz modgui_kernel_6.6.99-custom https://francyesco.github.io/GUI_ipk/kernel/6.6.99-custom'
                self.assertEqual(lines.count(kernel_feed), int(available))
                self.assertEqual(lines.count('arch brcm963xx 100'), int(available))

    def test_platform_feed_is_normalized_and_probed_independently(self):
        source = SOURCE.read_text()
        helper = source[source.index('append_missing_opkg_feeds()'):source.index('apply_right_opkg_repo()')]
        for product, platform in (("VBNT-O_fastweb", "vbnto"), ("VBNT-S", "vbnts")):
            for generic_available in (False, True):
                with self.subTest(product=product, generic_available=generic_available), tempfile.TemporaryDirectory() as tmp:
                    conf = Path(tmp) / 'opkg.conf'
                    conf.touch()
                    root = Path(tmp).as_posix()
                    script = helper + f'''
opkg_file={shlex.quote(root + "/opkg.conf")}
opkg_config_dir={shlex.quote(root)}
uname() {{ echo 4.1.38; }}
uci() {{ echo {shlex.quote(product)}; }}
curl() {{
  case "$2" in
    */4.1.38-{platform}/Packages.gz) return 0 ;;
    *) return {0 if generic_available else 1} ;;
  esac
}}
opkg() {{ echo 'arch brcm963xx 100'; }}
append_gui_vpn_feeds
append_gui_vpn_feeds
'''
                    sh_run(script)
                    lines = conf.read_text().splitlines()
                    self.assertEqual(lines.count(f'src/gz modgui_kernel_4.1.38_{platform} https://francyesco.github.io/GUI_ipk/kernel/4.1.38-{platform}'), 1)
                    self.assertEqual(lines.count('src/gz modgui_kernel_4.1.38 https://francyesco.github.io/GUI_ipk/kernel/4.1.38'), int(generic_available))

    def test_custom_partial_commented_and_repeated_feeds(self):
        source = SOURCE.read_text()
        helper = source[source.index('append_missing_opkg_feeds()'):source.index('apply_right_opkg_repo()')]
        for custom in (False, True):
            with self.subTest(custom=custom), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                conf = base / 'opkg.conf'
                conf.write_text('# src/gz feed_a https://old.invalid/a\n')
                directory = base / 'opkg'
                if custom:
                    directory.mkdir()
                    (directory / 'customfeeds.conf').write_text('src/gz feed_a https://custom.invalid/a\n')
                    (directory / 'extra.conf').write_text('src feed_b https://custom.invalid/b\n')
                script = helper + '\nopkg_file=' + shlex.quote(base.as_posix() + '/opkg.conf') + '\nopkg_config_dir=' + shlex.quote(directory.as_posix()) + '\n'
                script += 'append_missing_opkg_feeds <<EOF\nsrc/gz feed_a https://new.invalid/a\nsrc/gz feed_b https://new.invalid/b\nsrc/gz feed_c https://new.invalid/c\nEOF\n'
                for _ in range(2):
                    result = sh_run(script)
                    self.assertEqual(result.returncode, 0, result.stderr)
                lines = conf.read_text().splitlines()
                actual = [line.split()[1] for line in lines if line.startswith('src')]
                self.assertEqual(actual, ['feed_c'] if custom else ['feed_a', 'feed_b', 'feed_c'])
                if custom:
                    self.assertEqual((directory / 'customfeeds.conf').read_text(), 'src/gz feed_a https://custom.invalid/a\n')


if __name__ == '__main__':
    unittest.main()
