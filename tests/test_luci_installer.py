"""Verify service activation on legacy and current rc.common implementations."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "decompressed/gui_file/usr/share/transformer/scripts/appInstallRemoveUtility.sh"
SH = shutil.which("sh") or (str(Path("C:/Program Files/Git/bin/sh.exe")) if Path("C:/Program Files/Git/bin/sh.exe").exists() else None)


@unittest.skipUnless(SH, "POSIX shell required")
class LuciActivation(unittest.TestCase):
    def activate(self, enabled_status):
        source = INSTALLER.read_text()
        start = source.index("      /etc/init.d/uhttpd enable")
        activation = source[start:source.index("    }", start)]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            service = root / "uhttpd"
            calls = root / "calls"
            service.write_text(
                '#!/bin/sh\necho "$1" >> "$TEST_CALLS"\n'
                'case "$1" in\nenable) exit 1;;\n'
                f'enabled) exit {enabled_status};;\nrestart) exit 0;;\nesac\n'
            )
            service.chmod(0o755)
            service_str = service.as_posix()
            calls_str = calls.as_posix()
            script = "activate() {\n" + activation.replace("/etc/init.d/uhttpd", service_str) + "}\nactivate\n"
            result = subprocess.run(
                [SH, "-c", script],
                env={**os.environ, "TEST_CALLS": calls_str},
                capture_output=True, timeout=5,
            )
            return result.returncode, calls.read_text().splitlines() if calls.exists() else []

    def test_legacy_enable_status_does_not_prevent_startup(self):
        status, calls = self.activate(0)
        self.assertEqual(status, 0)
        self.assertEqual(calls, ["enable", "enabled", "restart"])

    def test_missing_boot_link_stops_installation(self):
        status, calls = self.activate(1)
        self.assertNotEqual(status, 0)
        self.assertEqual(calls, ["enable", "enabled"])


if __name__ == "__main__":
    unittest.main()
