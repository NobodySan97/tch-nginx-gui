"""Render live extension cards and check their shared polling clients.

Ported from upstream ddeb7d60/e2150b75; the Smartphone card additionally
proves the custom-refresh ownership handshake and the fork `.card` identities.
The VPN extension entries render through the shared-polling client wired in
their owning wave (upstream ddeb7d60), matching tests/test_extension_cards.js.
"""
from pathlib import Path
from html.parser import HTMLParser
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
CARDS = ROOT / 'decompressed/gui_file/www/cards'
SMARTPHONE_CARD = ROOT / 'decompressed/smartphone/www/cards/017_smartphone.lp'
SMARTPHONE_MODAL = ROOT / 'decompressed/smartphone/www/docroot/modals/smartphone-modal.lp'

VOID_ELEMENTS = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
                 'link', 'meta', 'param', 'source', 'track', 'wbr'}


class CardLayers(HTMLParser):
    """Every visible card value must belong to the existing foreground layer."""
    def __init__(self):
        super().__init__()
        self.stack = []
        self.foreground = False

    def handle_starttag(self, tag, attrs):
        classes = dict(attrs).get('class', '').split()
        if tag in VOID_ELEMENTS:
            return
        if tag == 'div' and any(item[0] == 'p' for item in self.stack):
            raise AssertionError('Block indicator inside a paragraph changes browser layout')
        if 'divtable' in classes:
            assert self.stack[-1][1] == ['content', 'card_bg']
            self.foreground = True
        self.stack.append((tag, classes))

    def handle_endtag(self, tag):
        assert self.stack[-1][0] == tag, (tag, self.stack)
        self.stack.pop()

    def handle_data(self, text):
        if text.strip() and any('content' in classes for _, classes in self.stack):
            assert any('divtable' in classes for _, classes in self.stack), text


class ExtensionCards(unittest.TestCase):
    @unittest.skipUnless(shutil.which('lua'), 'Lua required')
    def test_tailscale_light_and_header_switch(self):
        for enabled, online, phase, light in [
            ('0', 'false', 'stopped', '0'),
            ('1', 'false', 'authorization_required', '2'),
            ('1', 'false', 'stopped', '2'),
            ('1', 'true', 'connected', '1'),
        ]:
            with self.subTest(enabled=enabled, online=online, phase=phase):
                result = subprocess.run(['lua', '-', str(CARDS / '016_tailscale.lp'),
                                         enabled, online, phase, light], input=r'''
T = function(value) return value end
gettext = {textdomain = function() end}
string.untaint = function(value) return value end
ngx = {ctx = {session = {hasAccess = function() return true end}},
 print = function() end}
-- The fork cards keep the `file_exists` auto-hide guard: make every probed
-- path visible without writing to the host filesystem.
io.open = function() return {read = function() return "" end, close = function() end} end
package.preload['web.content_helper'] = function() return {getExactContent = function(content)
 for key in pairs(content) do content[key] = '' end
 content.enabled = arg[2]
end} end
local checked_header, checked_light = false, false
package.preload['web.ui_helper'] = function() return {
 createCardHeader = function(_, path, name, value)
  assert(path == '/modals/tailscale-modal.lp' and name == 'enabled' and value == arg[2])
  checked_header = true; return ''
 end,
 createSimpleLight = function(value)
  assert(value == arg[5], 'Unexpected light: ' .. tostring(value))
  checked_light = true; return ''
 end
} end
io.popen = function()
 local lines = {'online=' .. arg[3], 'phase=' .. arg[4]}; local i = 0
 return {lines = function() return function() i = i + 1; return lines[i] end end, close = function() end}
end
assert(loadfile(arg[1]))()
assert(checked_header and checked_light)
''', text=True, capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which('node'), 'Node.js required')
    def test_polling_lifecycle(self):
        result = subprocess.run(['node', 'tests/test_extension_cards.js'], cwd=ROOT,
                                text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(SMARTPHONE_CARD.is_file(), 'smartphone deck missing')
    def test_smartphone_card_identity(self):
        card = SMARTPHONE_CARD.read_text()
        self.assertIn('id="smartphone-card"', card)
        self.assertIn('new modgui.createAjaxUpdateCard("smartphone-card"', card)
        self.assertIn('uci.modgui.app.smartphone_app', (CARDS / '009_extensions.lp').read_text())

    @unittest.skipUnless(shutil.which('lua'), 'Lua required')
    def test_smartphone_card_layers_and_access_gate(self):
        self.assertTrue(SMARTPHONE_MODAL.is_file())
        for access in ('yes', 'no'):
            with self.subTest(access=access):
                result = subprocess.run(
                    ['lua', '-', str(SMARTPHONE_CARD), access], input=r'''
local output = {}
T = function(value) return value end
gettext = {textdomain = function() end}
string.untaint = function(value) return value end
package.preload["web.ui_helper"] = function() return {
  createCardHeader = function(title) return title end,
  createSimpleLight = function(_, text) return '<span><div class="light"></div>' .. text .. '</span>' end
} end
package.preload["web.web"] = function() return {
  html_escape = function(value)
    value = tostring(value):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
    return value
  end
} end
ngx = {ctx = {session = {hasAccess = function() return arg[2] == "yes" end}},
 print = function(...) for _, value in ipairs({...}) do output[#output + 1] = tostring(value) end end}
assert(loadfile(arg[1]))()
io.write(table.concat(output))
''', text=True, capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                html = result.stdout
                self.assertIn('id="smartphone-card"', html)
                self.assertIn('Smartphone USB', html)
                # The inline client must ship only with modal access.
                self.assertEqual('<script>' in html, access == 'yes')
                layers = CardLayers()
                layers.feed(html)
                self.assertTrue(layers.foreground)
                self.assertEqual(layers.stack, [])

    @unittest.skipUnless(shutil.which('lua'), 'Lua required')
    def test_vpn_cards_snapshots_and_access(self):
        for name, filename, connected, stopped in [
            ('tailscale', '016_tailscale.lp', 'Tailscale connected', 'Service disabled'),
            ('wireguard', '016_wireguard.lp', 'Peers connected', 'Tunnel disabled'),
            ('openvpn', '015_openvpn-server.lp', 'OpenVPN server enabled', 'OpenVPN server disabled'),
        ]:
            for enabled in ('0', '1'):
                for access in ('yes', 'no'):
                    with self.subTest(name=name, enabled=enabled, access=access):
                        result = subprocess.run(['lua', '-', str(CARDS / filename), name, enabled, access,
                                                 connected if enabled == '1' else stopped], input=r'''
local output = {}
T = function(value) return value end
N = function(single, plural, count) return count == 1 and single or plural end
gettext = {textdomain = function() end}
string.untaint = function(value) return value end
ngx = {ctx = {session = {hasAccess = function() return arg[4] == "yes" end}},
 print = function(...) for _, value in ipairs({...}) do output[#output + 1] = tostring(value) end end}
-- The fork cards keep the `file_exists` auto-hide guard: make every probed
-- path visible without writing to the host filesystem.
io.open = function()
  return {read = function() return "" end, close = function() end}
end
package.preload["web.ui_helper"] = function() return {
 createCardHeader = function(title) return title end,
 createSimpleLight = function(_, text) return '<span><i class="light"></i>' .. text .. '</span>' end
} end
package.preload["web.content_helper"] = function() return {getExactContent = function(content)
 for key in pairs(content) do content[key] = "" end
 content.enabled = arg[3]; content.client_enabled = "0"; content.connected_clients = "2"
end} end
io.popen = function(command)
 assert(command:find(arg[2], 1, true))
 local lines = arg[3] == "1" and {'online=true', 'running=true', 'live=2', 'peers=3', 'ip=<unsafe>&'} or {}
 local i = 0
 return {lines = function() return function() i = i + 1; return lines[i] end end, close = function() end}
end
assert(loadfile(arg[1]))()
local html = table.concat(output)
assert(html:find('id="' .. arg[2] .. '-card"', 1, true))
assert(html:find(arg[5], 1, true))
assert(not html:find('<unsafe>', 1, true))
if arg[2] ~= "openvpn" and arg[3] == "1" then assert(html:find('&lt;unsafe&gt;&amp;', 1, true)) end
assert((html:find('new modgui.createAjaxUpdateCard(', 1, true) ~= nil) == (arg[4] == "yes"))
''', text=True, capture_output=True, timeout=5)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_extensions_card_wiring(self):
        card = (CARDS / '009_extensions.lp').read_text()
        modal = (ROOT / 'decompressed/gui_file/www/docroot/modals/applications-modal.lp').read_text()
        for source, marker in (
            (card, 'smartphone_application = "uci.modgui.app.smartphone_app"'),
            (card, '{ key = "smartphone_application", title = T"Smartphone USB" }'),
            (modal, '"smartphone",'),
            (modal, 'append_extension_card('),
        ):
            self.assertIn(marker, source, marker)
        self.assertIn('"smartphone",', (ROOT / 'decompressed/gui_file/usr/share/transformer/mappings/rpc/system.modgui.map').read_text())
        # aMule gate must reach ARMv7 too (ondata-3 follow-up fix).
        self.assertIn('if cputype:match("^mips") or cputype:match("^armv7") then', card)
        self.assertIn('if cputype:match("^mips") or cputype:match("^armv7") then', modal)


if __name__ == '__main__':
    unittest.main()
