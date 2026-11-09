"""Exercise status reporting with a finished connect worker and a live daemon.

Ported from upstream 5c8d9d4c/6b032636; the dev harness keeps the fork
convention of baking `-S` into `-f` with a regular marker file so it also runs
on Windows dev shells without AF_UNIX.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
STATUS = ROOT / "decompressed/gui_file/usr/share/transformer/scripts/tailscaleStatus.sh"
SH = shutil.which("sh") or (str(Path("C:/Program Files/Git/bin/sh.exe")) if Path("C:/Program Files/Git/bin/sh.exe").exists() else None)


class TailscaleStatus(unittest.TestCase):
    @unittest.skipUnless(SH, "POSIX shell required")
    def test_status_uses_read_only_process_checks(self):
        for running, enabled, bootstrap, expected in ((True, True, False, "connected"),
                                                      (False, True, False, "stopped"),
                                                      (True, False, False, "stopped"),
                                                      (False, True, True, "starting")):
            with self.subTest(running=running, enabled=enabled, bootstrap=bootstrap), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "daemon.sock").touch()
                source = STATUS.read_text().replace(
                    "/etc/init.d/tailscale", "mock_service").replace(
                    "/var/run/tailscale/tailscaled.sock", str(root / "daemon.sock").replace('\\', '/')).replace(
                    "-S ", "-f ").replace(
                    "/tmp/modgui-tailscale-", str(root / "worker-").replace('\\', '/'))
                script = '''
uci() {
    case "$*" in
        *service.enabled) echo "$ENABLED" ;;
        *service.download_url) echo https://pkgs.tailscale.com/stable/tailscale_1.104.5_arm.tgz ;;
    esac
}
ip() { echo '    inet 100.64.0.1/32 scope global tailscale0'; }
mock_service() {
    echo 'PRIVILEGED_SERVICE_CHECK' >&2; return 1
}
pidof() { [ "$*" = tailscaled ] && [ "$RUNNING" = 1 ]; }
pgrep() { [ "$BOOTSTRAP" = 1 ]; }
''' + source
                result = subprocess.run(
                    [SH, "-c", f"ENABLED={int(enabled)}; RUNNING={int(running)}; BOOTSTRAP={int(bootstrap)};\n" + script],
                    cwd=str(ROOT),
                    capture_output=True, text=True, check=True, timeout=5)
                status = dict(line.split("=", 1) for line in result.stdout.splitlines())
                self.assertEqual(status["phase"], expected)
                self.assertEqual(status["online"], "true" if expected == "connected" else "false")
                self.assertNotIn('PRIVILEGED_SERVICE_CHECK', result.stderr)


if __name__ == "__main__":
    unittest.main()
