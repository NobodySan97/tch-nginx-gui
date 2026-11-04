"""Root-side capability probes used by the unprivileged Extensions renderer."""
from pathlib import Path
import shutil
import subprocess
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'decompressed/gui_file/usr/share/transformer/mappings/rpc/system.modgui.map'


@unittest.skipUnless(shutil.which('lua'), 'Lua interpreter required')
class VpnCapabilities(unittest.TestCase):
    def run_probe(self, harness):
        source = SOURCE.read_text()
        helper = source[source.index('local vpn_capability_cache ='):source.index('local SYSTEM_MODGUI_ =')]
        return subprocess.run(['lua', '-'], input=helper + harness, text=True, capture_output=True, check=True).stdout

    def test_probe_returns_only_boolean_and_releases_process(self):
        for status, expected in (('0', '1'), ('1', '0'), ('unexpected', '0')):
            with self.subTest(status=status):
                output = self.run_probe('''
local closed = false
io.popen = function(command)
  assert(command == '/usr/share/transformer/scripts/appInstallRemoveUtility.sh check tun 2>/dev/null; echo $?')
  return {read = function() return "''' + status + '''" end, close = function() closed = true end}
end
print(vpn_supported('tun'))
assert(closed)
''')
                self.assertEqual(output.strip(), expected)

    def test_failed_process_is_unavailable(self):
        self.assertEqual(self.run_probe("io.popen = function() return nil end; print(vpn_supported('tun'))").strip(), '0')

    def test_repeated_gui_reads_are_cached_briefly_then_refreshed(self):
        self.run_probe('''
local now, calls, status = 100, 0, '0'
os.time = function() return now end
io.popen = function()
  calls = calls + 1
  return {read = function() return status end, close = function() end}
end
assert(vpn_supported('tun') == '1')
status = '1'
assert(vpn_supported('tun') == '1' and calls == 1)
now = 130
assert(vpn_supported('tun') == '0' and calls == 2)
assert(vpn_supported('wireguard') == '0' and calls == 3)
''')

    def test_openvpn_connected_clients_count_is_exposed(self):
        source = (SOURCE.parent / 'openvpn.map').read_text()
        block = source[source.index('register({'):source.index('local function readfile')]
        harness = '''local object, status, closed = nil, nil, false
local register = function(entry) object = entry end
local function open(path)
  assert(path == '/tmp/openvpn-status.log')
  if not status then return nil end
  return {lines = function() return status:gmatch('[^\\n]+') end, close = function() closed = true end}
end
''' + block + '''
assert(object.objectType.parameters.connected_clients.access == 'readOnly')
assert(object.get.connected_clients() == '0')
status = 'Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since\\nuser,peer:12,1,2,date\\n10.8.0.6,user,peer:12,date\\n'
assert(object.get.connected_clients() == '1' and closed)
status = 'HEADER,CLIENT_LIST,fields\\nCLIENT_LIST,user,peer,1,2\\nCLIENT_LIST\\tuser2\\tpeer2\\t3\\t4\\n'
assert(object.get.connected_clients() == '2')
closed = false
status = 'CLIENT_LIST,user,peer,1,2\\nCLIENT_LIST\\tuser2\\tpeer2\\t3\\t4\\n'
assert(object.get.connected_clients() == '2' and closed)
'''
        result = subprocess.run(['lua', '-'], input=harness, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
