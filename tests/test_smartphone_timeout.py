"""Execute the RPC shell wrapper with both timeout command-line dialects."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which('lua')

# NOTE(fork): the RPC mapping shells out through POSIX syntax; on Windows
# io.popen reaches cmd.exe, so the harness routes every command through the
# Git for Windows bundled sh instead (same shell semantics as CI Linux).
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

# Lua harness installed in every child process: io.popen commands are written
# to a temporary sh script (with the POSIX PATH pre-baked, since the process
# env PATH would be re-converted by MSYS) and executed through sh.
HARNESS = r'''
local original_popen = io.popen
local sh = os.getenv('TCH_SH')
if sh then
  sh = sh:gsub('\\', '/')
  local popen_seq = 0
  io.popen = function(command)
    popen_seq = popen_seq + 1
    local template = os.getenv('TCH_TEMP') .. '/tch_popen.' .. tostring(os.time()) ..
        '.' .. tostring(popen_seq) .. '.sh'
    local script = assert(io.open(template, 'w'))
    script:write('PATH=' .. os.getenv('TCH_FAKE_BINDIR') .. ':/usr/bin:/bin\nexport PATH\n')
    script:write(command)
    script:close()
    -- Double-quote sandwich: cmd /c keeps the outer quotes when the string is
    -- one quoted command, so the spaced sh path stays quoted and the script
    -- path (no spaces) follows unquoted.
    local pipe = original_popen('""' .. sh .. '" ' .. template .. '"')
    return {
      read = function(_, ...) return pipe:read(...) end,
      close = function() os.remove(template); return pipe:close() end,
    }
  end
end'''


def run_lua(script, env=None, stdin=None):
    return subprocess.run([LUA, '-', *stdin], input=script, text=True,
                          capture_output=True, timeout=30, env={**os.environ, **(env or {})})


@unittest.skipUnless(LUA, 'Lua interpreter required')
class SmartphoneTimeoutTest(unittest.TestCase):
    def test_deadline_keeps_usb_identity_and_reports_telemetry_failure(self):
        for status, code in [('124', 'telemetry_timeout'), ('137', 'telemetry_timeout'), ('1', 'helper_error')]:
            with self.subTest(status=status):
                result = run_lua(r'''
local calls = 0
io.popen = function(command)
    calls = calls + 1
    if calls == 1 then
        return {read = function() return "\nEXIT_STATUS|" .. arg[2] .. "\n" end, close = function() end}
    end
    assert(command:find('get_usb_info', 1, true), command)
    return {read = function() return "USB_DEV|Example phone\nUSB_ADB|1\nHOST_IF|usb0\n" end, close = function() end}
end
local mapping
register = function(value) mapping = value end
assert(loadfile(arg[1] .. '/decompressed/smartphone/usr/share/transformer/mappings/rpc/smartphone.map'))()
local stats = mapping.get.stats()
assert(stats:find('ERROR_CODE|' .. arg[3], 1, true), stats)
assert(stats:find('USB_DEV|Example phone', 1, true), stats)
assert(stats:find('HOST_IF|usb0', 1, true), stats)
assert(calls == 2)
''', stdin=[str(ROOT), status, code])
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rpc_preserves_usb_diagnostics_with_old_and_new_timeout(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            timeout = folder / 'timeout'
            timeout.write_text('''#!/bin/sh
if [ "$1" = --help ]; then
    if [ "$LEGACY" = 1 ]; then echo 'Usage: timeout [-t SECS] PROG ARGS';
    else echo 'Usage: timeout SECS PROG ARGS'; fi
    exit 0
fi
if [ "$LEGACY" = 1 ]; then [ "$1" = -t ] || exit 90; shift; fi
[ "$1" = 18 ] || exit 91
shift
exec "$@"
''', newline='\n')
            helper = folder / 'phone_stats.sh'
            helper.write_text('''#!/bin/sh
printf 'ERROR|Enable USB debugging\nERROR_CODE|usb_only\nUSB_DEV|moto g32\nUSB_ADB|0\n'
exit 1
''', newline='\n')
            timeout.chmod(0o755)
            helper.chmod(0o755)
            for legacy in ('0', '1'):
                with self.subTest(legacy=legacy):
                    result = run_lua(HARNESS + r'''
io.popen = (function()
    local custom = io.popen
    return function(command)
        return custom((command:gsub('/usr/bin/phone_stats.sh', os.getenv('HELPER'))))
    end
end)()
local mapping
register = function(value) mapping = value end
assert(loadfile(arg[1] .. '/decompressed/smartphone/usr/share/transformer/mappings/rpc/smartphone.map'))()
local stats = mapping.get.stats()
assert(stats:find('ERROR_CODE|usb_only', 1, true), stats)
assert(stats:find('USB_DEV|moto g32', 1, true), stats)
assert(stats:find('USB_ADB|0', 1, true), stats)
''', stdin=[str(ROOT)], env={'PATH': directory,
                             'LEGACY': legacy, 'HELPER': _msys_path(helper),
                             'TCH_SH': SH, 'TCH_TEMP': folder.parent.as_posix(),
                             'TCH_FAKE_BINDIR': _msys_path(folder)})
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
