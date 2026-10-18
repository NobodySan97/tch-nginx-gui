"""Exercise log collection and terminal state without a router."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


WRAPPER = Path(__file__).resolve().parents[1] / "decompressed/gui_file/usr/share/transformer/scripts/wrapper.sh"
SH = shutil.which("sh") or (str(Path("C:/Program Files/Git/bin/sh.exe")) if Path("C:/Program Files/Git/bin/sh.exe").exists() else None)


@unittest.skipUnless(SH, "POSIX shell required")
class CommandWrapper(unittest.TestCase):
    def run_command(self, status):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "command_log"
            states = root / "states"
            wrapper = root / "wrapper.sh"
            command = root / "command.sh"
            log_posix = log.as_posix()
            states_posix = states.as_posix()
            wrapper_posix = wrapper.as_posix()
            command_posix = command.as_posix()
            root_posix = root.as_posix()
            wrapper.write_text(WRAPPER.read_text().replace("LOG_LOCATION=/tmp/command_log", f"LOG_LOCATION={log_posix}"))
            lua = root / "lua"
            lua.write_text('#!/bin/sh\nprintf "%s\\n" "$2" >> "$TEST_STATES"\n')
            lua.chmod(0o755)
            command = root / "command.sh"
            command.write_text(f'#!/bin/sh\necho first\necho error >&2\necho last\nexit {status}\n')
            command.chmod(0o755)
            result = subprocess.run(
                [SH, wrapper_posix, command_posix],
                env={**os.environ, "PATH": f"{root_posix}:{os.environ['PATH']}", "TEST_STATES": states_posix},
                capture_output=True, text=True, timeout=5,
            )
            log_text = log.read_text() if log.exists() else ""
            states_text = states.read_text() if states.exists() else ""
            return result, log_text, states_text

    def test_stdout_and_stderr_are_preserved_in_order(self):
        result, log, states = self.run_command(0)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(log, "first\nerror\nlast\n")
        self.assertIn("Requested", states)
        self.assertIn("Complete", states)
        self.assertNotIn("Idle", states)

    def test_failure_keeps_output_and_completes_polling(self):
        result, log, states = self.run_command(7)
        self.assertEqual(result.returncode, 7)
        self.assertIn("first\nerror\nlast\n", log)
        self.assertIn("exit status 7", log)
        self.assertIn("Complete", states)


if __name__ == "__main__":
    unittest.main()
