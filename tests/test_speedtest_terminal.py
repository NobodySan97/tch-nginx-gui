"""Exercise Ookla streaming through the command wrapper without a router.

Ported from upstream e87789d4 and adapted to the fork: the wrapper reports
"In Progress"/"Error" states through the hardened transformer call, and the
mock PATH is exported via `sh -c` because MSYS re-converts inherited env on
Windows (see tests/test_smartphone_app.py).
"""


from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "decompressed/gui_file/usr/share/transformer/scripts"

SH = shutil.which("sh")
if not SH:
    _candidate = Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git' / 'bin' / 'sh.exe'
    if _candidate.exists():
        SH = str(_candidate)


def _msys_path(p):
    """Convert a "C:/Users/..." path to "/c/Users/..." PATH entry form."""
    p = str(p).replace(os.sep, '/')
    if len(p) >= 3 and p[1:2] == ':':
        return '/' + p[0].lower() + p[2:]
    return p


class SpeedtestTerminal(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua"), "Lua required")
    def test_terminal_progress_rendering(self):
        result = subprocess.run(
            ["lua", "-"], cwd=ROOT,
            input=r'''
local cases = {
    -- The fork terminal rebuilds the log from clean lines: the trailing
    -- newline is intentionally dropped by its multistage reporting.
    {"plain\nlog\n", "plain\nlog"},
    {"header\n\rDownload: 5%\rDownload: 50%\rDownload: 100%\n\rUpload: 2%", "header\nDownload: 100%\nUpload: 2%"},
    {"<unsafe>\n", "<unsafe>"},
    {"windows\r\nlog\r\n", "windows\nlog"},
}
local expected, input
package.preload["datamodel"] = function()
    return {get = function() return {{value = "Requested"}} end}
end
package.preload["dkjson"] = function()
    return {encode = function(data)
        assert(data.log == expected, string.format("Unexpected log: %q", data.log))
        assert(data.state == "Requested")
        return true
    end}
end
string.untaint = function(value) return value end
ngx = {say = function() end, exit = function() end, HTTP_OK = 200}
io.open = function(path)
    assert(path == "/tmp/command_log")
    return {read = function() return input end, close = function() end}
end
for _, case in ipairs(cases) do
    input, expected = case[1], case[2]
    assert(loadfile("decompressed/gui_file/www/docroot/ajax/commandlogread.lua"))()
end
''',
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(SH, "POSIX shell required")
    def test_live_output_completion_and_failure(self):
        source = (SCRIPTS / "appInstallRemoveUtility.sh").read_text()
        start = source.index("app_speedtest() {")
        function = source[start:source.index("\napp_adguardhome()", start)]
        for status in (0, 7):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                rootdir = str(root).replace(os.sep, '/')
                (root / "ookla").mkdir()
                binary = root / "ookla/speedtest"
                binary.write_text('''#!/bin/sh
echo "$*" > "$TEST_ROOT/args"
echo 'Download: testing'
while [ ! -f "$TEST_ROOT/release" ]; do sleep 0.05; done
echo 'Upload: testing' >&2
echo 'Result URL: https://example.test/result'
exit "$TEST_STATUS"
''')
                binary.chmod(0o755)
                command = root / "command.sh"
                command.write_text("#!/bin/sh\n" + function
                                   .replace("/opt/ookla", rootdir + "/ookla")
                                   .replace("/tmp/speedtest", rootdir + "/speedtest") + "\napp_speedtest start\n")
                command.chmod(0o755)
                wrapper = root / "wrapper.sh"
                wrapper.write_text((SCRIPTS / "wrapper.sh").read_text().replace("/tmp/command_log", rootdir + "/command_log"))
                log = root / "command_log"
                lua = root / "lua"
                lua.write_text('#!/bin/sh\nprintf "%s\\n" "$2" >> "$TEST_ROOT/states"\n')
                lua.chmod(0o755)
                process = subprocess.Popen(
                    [SH, '-c',
                     'export PATH=' + _msys_path(rootdir) + ':/usr/bin:/bin' +
                     '; export TEST_ROOT=' + rootdir + '; export TEST_STATUS=' + str(status) +
                     '; exec "$0" "$@"',
                     str(wrapper.as_posix()), str(command.as_posix())],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    env={**os.environ}, text=True,
                )
                try:
                    deadline = time.monotonic() + 5
                    while not (log.exists() and "Download: testing" in log.read_text()):
                        if time.monotonic() > deadline or process.poll() is not None:
                            self.fail("Speedtest output did not reach the terminal while running")
                        time.sleep(0.02)
                    self.assertIsNone(process.poll())
                    states_text = self.states_text(root)
                    self.assertNotIn("'Complete'", states_text)
                    self.assertIn("'In Progress'", states_text)
                    self.assertTrue((root / "speedtest.pid").exists())
                    self.assertIn("--progress=yes", (root / "args").read_text())
                finally:
                    (root / "release").write_text("")
                    process.communicate(timeout=10)
                self.assertEqual(process.returncode, status)
                saved = (root / "speedtest-result.txt").read_text()
                self.assertEqual(saved, "Download: testing\nUpload: testing\nResult URL: https://example.test/result\n")
                self.assertTrue(log.read_text().startswith(saved))
                # The fork wrapper reports Complete on success and Error on failure.
                states_text = self.states_text(root)
                self.assertIn("'Complete'" if status == 0 else "'Error'", states_text)
                if status:
                    self.assertIn("exit status 7", log.read_text())
                self.assertFalse((root / "speedtest.pid").exists())
                self.assertEqual(list(root.glob("speedtest-run.*")), [])

    @staticmethod
    def states_text(root):
        file = root / "states"
        return file.read_text() if file.exists() else ""


if __name__ == "__main__":
    unittest.main()
