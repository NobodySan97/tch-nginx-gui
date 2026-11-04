"""Exercise first-install UCI layouts and already stopped procd services."""

from pathlib import Path
import os
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'decompressed/gui_file'
HELPER = (ROOT / 'usr/share/transformer/scripts/ispConfigHelper.sh').read_text()
NETWORK = (ROOT / 'etc/modgui_scripts/06_network.sh').read_text()

# NOTE(fork): upstream assumed a POSIX CI; on Windows fall back to the
# Git for Windows bundled sh so the guards are actually exercised locally.
SH = shutil.which('sh') or shutil.which('sh.exe') or \
     str(Path(os.environ.get('ProgramFiles', 'C:/Program Files'),
              'Git', 'bin', 'sh.exe'))
SH = SH if Path(SH).exists() else None


@unittest.skipUnless(SH, 'POSIX shell required')
class InstallGuards(unittest.TestCase):
    def test_tim_without_voice_stack_and_with_existing_voice_settings(self):
        function = HELPER[HELPER.index('setup_ISP() {'):HELPER.index('autodetect_isp()')]
        harness = r'''
logecho() { :; }
check_clean() { :; }
cwmp_specific_TIM() { :; }
# NOTE(fork): our setup_ISP still resolves the CWMP section through
# get_cwmp_section(); stub it here so the harness focuses on the guards.
get_cwmp_section() { echo cwmpd_config; }
restart_dnsmasq=0
uci() {
    [ "$1" != -q ] || shift
    [ "$2" != -q ] || set -- "$1" "$3"
    case "$1:$2" in
        get:env.var.serial) echo serial ;;
        get:env.var.oui) echo oui ;;
        get:dhcp.dnsmasq.server) echo 151.99.125.1 ;;
        get:mmpbxrvsipnet.sip_net) [ "$VOICE" != absent ] && echo sip_net ;;
        get:mmpbxrvsipnet.sip_net.user_param_value) [ "$VOICE" != custom ] || echo custom ;;
        set:modgui.var.ppp_mgmt=*|set:modgui.var.ppp_realm_ipv6=*) return 0 ;;
        set:mmpbxrvsipnet.sip_net.user_param_value=phone)
            [ "$VOICE" != absent ] || { echo 'uci: Invalid argument' >&2; return 1; }
            echo phone ;;
        *) echo "Unexpected UCI call: $*" >&2; return 99 ;;
    esac
}
'''
        for voice in ('absent', 'empty', 'custom'):
            with self.subTest(voice=voice):
                result = subprocess.run(
                    [SH, '-c', 'VOICE=$1\n' + harness + function + '\nsetup_ISP TIM', 'test', voice],
                    text=True, capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertEqual(result.stdout.strip(), 'phone' if voice == 'empty' else '')

    def test_dnsmasq_anonymous_section_is_renamed_without_duplicate(self):
        function = NETWORK[NETWORK.index('check_dnsmasq_name() {'):NETWORK.index('update_dhcp_config()')]
        harness = r'''
logecho() { :; }
restart_dnsmasq=0
uci() {
    [ "$1" != -q ] || shift
    [ "$2" != -q ] || set -- "$1" "$3"
    case "$1:$2" in
        get:dhcp.dnsmasq) [ "$LAYOUT" = named ] && echo dnsmasq ;;
        'get:dhcp.@dnsmasq[0]') [ "$LAYOUT" = anonymous ] && echo dnsmasq ;;
        'rename:dhcp.@dnsmasq[0]=dnsmasq')
            [ "$LAYOUT" = anonymous ] || return 99
            LAYOUT=named; echo rename ;;
        set:dhcp.dnsmasq=dnsmasq)
            [ "$LAYOUT" = missing ] || { echo duplicate >&2; return 99; }
            LAYOUT=named; echo create ;;
        *) echo "Unexpected UCI call: $*" >&2; return 99 ;;
    esac
}
'''
        for layout, expected in [('anonymous', 'rename'), ('named', ''), ('missing', 'create')]:
            with self.subTest(layout=layout):
                result = subprocess.run(
                    [SH, '-c', 'LAYOUT=$1\n' + harness + function +
                     '\ncheck_dnsmasq_name\ncheck_dnsmasq_name', 'test', layout],
                    text=True, capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertEqual(result.stdout.strip(), expected)
        self.assertLess(NETWORK.index('\ncheck_dnsmasq_name '), NETWORK.index('\ncheck_isp_config\n'))



if __name__ == '__main__':
    unittest.main()
