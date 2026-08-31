--pretranslated: do not change this file
 
gettext.textdomain('webui-core')
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local triesbeforemsg = 3
local content_helper = require("web.content_helper")
local format = string.format
local passwd_count_msg = format(T"Tentativi errati (%s).", '<span id="pwdCount" class="badge-count"></span>')
local timer_msg = format(T"Blocco temporaneo. Attendi %s secondi.", '<span id="timerSec" class="cooldown-timer"></span>')

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "getcsrf" then
  ngx.print(ngx.ctx.session:getCSRFtoken())
  ngx.exit(ngx.HTTP_OK)
end

local cui = {
  defaultuser = "uci.web.uiconfig.@uidefault.defaultuser",
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  timestamp = "uci.version.version.@version[0].timestamp",
  gui_version = "rpc.system.modgui.gui_version",
  gui_skin = "uci.modgui.gui.gui_skin",
}
content_helper.getExactContent(cui)
local year = cui.timestamp
local current_year = (string.sub(year,1,4))
local users = content_helper.getMatchedContent("uci.web.user.")
local userNames = ""
local legacySalts = ""

local httpi = proxy.get("rpc.network.interface.@wan.up")
httpi = (httpi and httpi[1] and httpi[1].value) or ""

local httpi_wwan = proxy.get("rpc.network.interface.@wwan.up")
httpi_wwan = (httpi_wwan and httpi_wwan[1] and httpi_wwan[1].value) or ""

local wan_mode = proxy.get("uci.network.config.wan_mode")
wan_mode = (wan_mode and wan_mode[1] and wan_mode[1].value) or ""

local assistance_port = proxy.get("uci.web.assist_state.@state_remote.port")
assistance_port = (assistance_port and assistance_port[1] and assistance_port[1].value and assistance_port[1].value ~= "") and assistance_port[1].value or "0"

for _, v in ipairs(users) do
  if v.legacy_salt and v.legacy_salt ~= "" then
    userNames = userNames .. v.name ..","
    legacySalts = legacySalts .. v.legacy_salt .. ","
  end
end

local skin_lower = string.lower(cui.gui_skin or "")
local theme_class = "theme-default"
if skin_lower == "tim" then
  theme_class = "theme-tim"
elseif skin_lower == "fritz" or string.match(skin_lower, "fritz") then
  theme_class = "theme-fritz"
elseif string.match(skin_lower, "dark") then
  theme_class = "theme-dark"
elseif skin_lower == "green" then
  theme_class = "theme-green"
elseif skin_lower == "violet" then
  theme_class = "theme-violet"
end

ngx.print('<!DOCTYPE HTML>\n')
ngx.print(format('<html lang="%s" class="%s">\n', gettext.language(), theme_class))
ngx.print('<head>\n')
ngx.print('    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">\n')
ngx.print('    <meta charset="UTF-8">\n')
ngx.print('    <meta name="CSRFtoken" content="'); ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('">\n')
ngx.print('    <link href="/css/font-awesome-all-5.7.2.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\n')
ngx.print('    <link href="/css/gw.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\n')
ngx.print('    <link href="/css/responsive.css?version='); ngx.print(cui.gui_version); ngx.print('" rel="stylesheet">\n')
ngx.print('    <link rel="shortcut icon" type="image/x-icon" href="/img/favicon.ico"/>\n')
ngx.print('    <link rel="stylesheet" href="/theme/'); ngx.print(cui.gui_skin); ngx.print('/style.css?version='); ngx.print(cui.gui_version); ngx.print('">\n')
ngx.print('    <link rel="stylesheet" href="/css/aos.css?version='); ngx.print(cui.gui_version); ngx.print('">\n')
ngx.print('    <title>'); ngx.print(T"Gateway Login"); ngx.print('</title>\n')
ngx.print([[
    <style>
      :root {
        --primary: #059669;
        --primary-hover: #047857;
        --primary-glow: rgba(5, 150, 105, 0.28);
        --accent: #10b981;
        --card-bg: rgba(255, 255, 255, 0.95);
        --card-border: rgba(255, 255, 255, 0.8);
        --card-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(0, 0, 0, 0.05);
        --input-bg: #f8fafc;
        --input-border: #cbd5e1;
        --text-heading: #0f172a;
        --text-body: #334155;
        --text-muted: #64748b;
        --danger: #ef4444;
        --danger-bg: rgba(239, 68, 68, 0.1);
        --danger-border: rgba(239, 68, 68, 0.25);
        --warning-bg: rgba(245, 158, 11, 0.1);
        --warning-border: rgba(245, 158, 11, 0.25);
        --radius-card: 20px;
        --radius-control: 12px;
      }

      .theme-tim {
        --primary: #004691;
        --primary-hover: #00336b;
        --primary-glow: rgba(0, 70, 145, 0.32);
        --accent: #0099ff;
      }
      .theme-fritz {
        --primary: #e65100;
        --primary-hover: #c64200;
        --primary-glow: rgba(230, 81, 0, 0.32);
        --accent: #0288d1;
      }
      .theme-dark, .theme-dark body {
        --card-bg: rgba(30, 41, 59, 0.88);
        --card-border: rgba(255, 255, 255, 0.12);
        --card-shadow: 0 30px 60px -15px rgba(0, 0, 0, 0.6), 0 0 30px rgba(59, 130, 246, 0.15);
        --input-bg: rgba(15, 23, 42, 0.85);
        --input-border: rgba(255, 255, 255, 0.15);
        --text-heading: #f8fafc;
        --text-body: #cbd5e1;
        --text-muted: #94a3b8;
        --primary: #3b82f6;
        --primary-hover: #2563eb;
        --primary-glow: rgba(59, 130, 246, 0.38);
      }
      .theme-green {
        --primary: #059669;
        --primary-hover: #047857;
        --primary-glow: rgba(5, 150, 105, 0.3);
        --accent: #10b981;
      }
      .theme-violet {
        --primary: #7c3aed;
        --primary-hover: #6d28d9;
        --primary-glow: rgba(124, 58, 237, 0.32);
        --accent: #a855f7;
      }

      html, body {
        min-height: 100%;
        margin: 0;
        padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif !important;
        background: radial-gradient(circle at 50% 15%, rgba(5, 150, 105, 0.10), transparent 45%),
                    radial-gradient(circle at 85% 85%, rgba(16, 185, 129, 0.08), transparent 40%),
                    #f1f5f9 !important;
        color: var(--text-body);
        -webkit-font-smoothing: antialiased;
        overflow-x: hidden;
      }
      .theme-tim html, .theme-tim body {
        background: radial-gradient(circle at 50% 15%, rgba(0, 70, 145, 0.10), transparent 45%),
                    radial-gradient(circle at 85% 85%, rgba(0, 153, 255, 0.08), transparent 40%),
                    #f1f5f9 !important;
      }
      .theme-dark html, .theme-dark body {
        background: radial-gradient(circle at 50% 15%, rgba(59, 130, 246, 0.15), transparent 50%),
                    radial-gradient(circle at 85% 85%, rgba(16, 185, 129, 0.08), transparent 45%),
                    #0b0f19 !important;
      }

      .auth-viewport {
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        padding: 24px 16px;
        box-sizing: border-box;
      }

      .auth-card {
        width: 100%;
        max-width: 440px;
        background: var(--card-bg);
        backdrop-filter: blur(24px) saturate(190%);
        -webkit-backdrop-filter: blur(24px) saturate(190%);
        border: 1px solid var(--card-border);
        border-radius: var(--radius-card);
        box-shadow: var(--card-shadow);
        padding: 40px 34px 34px 34px;
        box-sizing: border-box;
        position: relative;
        overflow: hidden;
      }

      .auth-card::before {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 4px;
        background: linear-gradient(90deg, var(--primary), var(--accent, var(--primary)));
      }

      .auth-header {
        text-align: center;
        margin-bottom: 28px;
      }
      .brand-logo-wrap {
        display: inline-block;
        margin-bottom: 16px;
        transition: transform 0.25s ease;
      }
      .brand-logo-wrap:hover {
        transform: scale(1.03);
      }
      .brand-logo-wrap img {
        max-height: 52px;
        width: auto;
        object-fit: contain;
        filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.08));
      }
      .auth-title {
        font-size: 23px;
        font-weight: 700;
        color: var(--text-heading);
        margin: 0 0 6px 0;
        letter-spacing: -0.02em;
      }
      .auth-subtitle {
        font-size: 13px;
        color: var(--text-muted);
        margin: 0;
      }

      .status-pill-list {
        display: flex;
        flex-direction: column;
        gap: 8px;
        margin-bottom: 20px;
      }
      .status-pill {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 10px 14px;
        border-radius: var(--radius-control);
        font-size: 13px;
        font-weight: 500;
        line-height: 1.35;
      }
      .status-pill.warning {
        background: var(--warning-bg);
        border: 1px solid var(--warning-border);
        color: #d97706;
      }
      .status-pill.info {
        background: rgba(59, 130, 246, 0.1);
        border: 1px solid rgba(59, 130, 246, 0.25);
        color: #2563eb;
      }

      /* === PURE FLEXBOX INPUT CONTAINER - IMMUNE TO OVERLAYS === */
      .modern-input-group {
        display: flex !important;
        align-items: center !important;
        background: var(--input-bg) !important;
        border: 1.5px solid var(--input-border) !important;
        border-radius: var(--radius-control) !important;
        padding: 0 12px !important;
        height: 50px !important;
        margin-bottom: 18px !important;
        box-sizing: border-box !important;
        transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1) !important;
      }
      .modern-input-group:focus-within {
        border-color: var(--primary) !important;
        box-shadow: 0 0 0 4px var(--primary-glow) !important;
        background: #ffffff !important;
      }
      .theme-dark .modern-input-group:focus-within {
        background: rgba(15, 23, 42, 0.95) !important;
      }
      .input-prefix-icon {
        width: 32px !important;
        flex: 0 0 32px !important;
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        color: var(--text-muted) !important;
        font-size: 16px !important;
      }
      .modern-input-group:focus-within .input-prefix-icon {
        color: var(--primary) !important;
      }
      .modern-input-group input {
        flex: 1 1 auto !important;
        width: 100% !important;
        border: none !important;
        background: transparent !important;
        box-shadow: none !important;
        outline: none !important;
        padding: 0 10px !important;
        margin: 0 !important;
        height: 100% !important;
        font-size: 15px !important;
        color: var(--text-heading) !important;
        box-sizing: border-box !important;
      }
      .modern-input-group input::placeholder {
        color: var(--text-muted);
        opacity: 0.75;
      }

      .btn-password-toggle {
        width: 36px !important;
        height: 36px !important;
        flex: 0 0 36px !important;
        background: transparent !important;
        border: none !important;
        color: var(--text-muted) !important;
        cursor: pointer !important;
        padding: 0 !important;
        font-size: 16px !important;
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        border-radius: 8px !important;
        transition: all 0.2s ease !important;
      }
      .btn-password-toggle:hover {
        color: var(--text-heading) !important;
        background: rgba(0, 0, 0, 0.06) !important;
      }
      .theme-dark .btn-password-toggle:hover {
        background: rgba(255, 255, 255, 0.1) !important;
      }

      .btn-modern-primary {
        width: 100% !important;
        height: 48px !important;
        background: linear-gradient(135deg, var(--primary), var(--primary-hover)) !important;
        color: #ffffff !important;
        border: none !important;
        border-radius: var(--radius-control) !important;
        font-size: 15.5px !important;
        font-weight: 600 !important;
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        gap: 10px !important;
        cursor: pointer !important;
        transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1) !important;
        box-shadow: 0 4px 14px var(--primary-glow) !important;
        text-decoration: none !important;
        box-sizing: border-box !important;
        text-shadow: none !important;
      }
      .btn-modern-primary:hover {
        transform: translateY(-2px) !important;
        box-shadow: 0 8px 22px var(--primary-glow) !important;
        filter: brightness(1.05) !important;
      }
      .btn-modern-primary:active {
        transform: translateY(0) scale(0.98) !important;
      }
      .btn-modern-primary:disabled {
        opacity: 0.7 !important;
        cursor: not-allowed !important;
        transform: none !important;
        box-shadow: none !important;
      }

      .btn-modern-secondary {
        display: inline-flex !important;
        align-items: center !important;
        justify-content: center !important;
        height: 42px !important;
        padding: 0 18px !important;
        border-radius: var(--radius-control) !important;
        border: 1.5px solid var(--input-border) !important;
        background: transparent !important;
        color: var(--text-body) !important;
        font-size: 14px !important;
        font-weight: 500 !important;
        cursor: pointer !important;
        text-decoration: none !important;
        transition: all 0.2s ease !important;
      }
      .btn-modern-secondary:hover {
        background: rgba(0, 0, 0, 0.04) !important;
        border-color: var(--text-muted) !important;
      }

      .auth-alert-toast {
        display: none;
        align-items: center;
        gap: 10px;
        padding: 12px 16px;
        background: var(--danger-bg);
        border: 1px solid var(--danger-border);
        border-radius: var(--radius-control);
        color: var(--danger);
        font-size: 13.5px;
        font-weight: 500;
        margin-bottom: 20px;
        animation: shake 0.4s ease-in-out;
      }
      .auth-alert-toast.show {
        display: flex;
      }

      .auth-info-card {
        padding: 12px 14px;
        background: rgba(59, 130, 246, 0.08);
        border: 1px solid rgba(59, 130, 246, 0.2);
        border-radius: var(--radius-control);
        font-size: 12.5px;
        color: var(--text-muted);
        margin-bottom: 18px;
        line-height: 1.4;
      }

      @keyframes shake {
        0%, 100% { transform: translateX(0); }
        20%, 60% { transform: translateX(-6px); }
        40%, 80% { transform: translateX(6px); }
      }

      .modern-modal-overlay {
        display: none;
        position: fixed;
        top: 0; right: 0; bottom: 0; left: 0; inset: 0;
        background: rgba(15, 23, 42, 0.65);
        backdrop-filter: blur(8px);
        -webkit-backdrop-filter: blur(8px);
        z-index: 9999;
        align-items: center;
        justify-content: center;
        padding: 16px;
      }
      .modern-modal-overlay.active {
        display: flex;
      }
      .modern-modal-card {
        width: 100%;
        max-width: 400px;
        background: var(--card-bg);
        border: 1px solid var(--card-border);
        border-radius: var(--radius-card);
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35);
        padding: 32px 28px;
        text-align: center;
      }
      .modal-icon-shield {
        width: 64px;
        height: 64px;
        margin: 0 auto 16px auto;
        border-radius: 50%;
        background: var(--warning-bg);
        color: #d97706;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 28px;
      }
      .cooldown-timer {
        font-size: 18px;
        font-weight: 700;
        color: var(--primary);
      }
      .badge-count {
        font-weight: 700;
        color: var(--danger);
      }

      .auth-footer {
        margin-top: 24px;
        text-align: center;
        font-size: 12.5px;
        color: var(--text-muted);
      }
    </style>
</head>
<body>

<div class="auth-viewport">
  <div class="auth-card" data-aos="fade-up" data-aos-duration="600">

    <div class="auth-header">
]])
ngx.print('      <a href="'); ngx.print(cui.nsplink); ngx.print('" target="_blank" class="brand-logo-wrap" title="Gateway Portal">\n')
ngx.print('        <picture>\n')
if cui.gui_skin == "TIM" then
  ngx.print('          <img src="/img/TIM.png" alt="TIM Gateway">\n')
elseif cui.gui_skin == "Fritz" or string.match(cui.gui_skin, "[dD][aA][rR][kK]") then
  ngx.print('          <source srcset="/img/logo_white.webp" type="image/webp">\n')
  ngx.print('          <source srcset="/img/logo_white.png" type="image/png">\n')
  ngx.print('          <img src="/img/logo_white.png" alt="Gateway Admin">\n')
else
  ngx.print('          <source srcset="/img/logo.webp" type="image/webp">\n')
  ngx.print('          <source srcset="/img/logo.png" type="image/png">\n')
  ngx.print('          <img src="/img/logo.png" alt="Gateway Admin">\n')
end
ngx.print('        </picture>\n')
ngx.print('      </a>\n')
ngx.print('      <h1 class="auth-title">'); ngx.print(T"Gateway Sign In"); ngx.print('</h1>\n')
ngx.print('      <p class="auth-subtitle">'); ngx.print(T"Technicolor Gateway Web Interface"); ngx.print('</p>\n')
ngx.print('    </div>\n')

ngx.print('    <div class="status-pill-list">\n')
if httpi == "0" and httpi_wwan == "0" and wan_mode ~= "bridge" then
  ngx.print(format('      <div class="status-pill warning"><i class="fas fa-wifi"></i><span>%s</span></div>\n', T"Nessuna connessione Internet attiva"))
end
if wan_mode == "bridge" then
  ngx.print(format('      <div class="status-pill info"><i class="fas fa-network-wired"></i><span>%s</span></div>\n', T"Modalità Bridge Attiva"))
end
if assistance_port ~= "0" then
  ngx.print(format('      <div class="status-pill info"><i class="fas fa-headset"></i><span>%s</span></div>\n', T"Sessione Assistenza Remota Attiva"))
end
ngx.print('    </div>\n')

ngx.print('    <div id="erroruserpass" class="auth-alert-toast"><i class="fas fa-exclamation-circle"></i><span>'); ngx.print(T"Username o Password non validi."); ngx.print('</span></div>\n')

ngx.print([[
    <div id="login-section">
      <form id="auth-form" onsubmit="return false;">
        
        <div class="modern-input-group">
          <div class="input-prefix-icon"><i class="fas fa-user"></i></div>
]])
ngx.print('          <input type="text" id="srp_username" placeholder="'); ngx.print(T"Username"); ngx.print('" value="'); ngx.print(cui.defaultuser); ngx.print('" autocomplete="username" autofocus required>\n')
ngx.print([[
        </div>

        <div class="modern-input-group">
          <div class="input-prefix-icon"><i class="fas fa-lock"></i></div>
]])
ngx.print('          <input type="password" id="srp_password" placeholder="'); ngx.print(T"Password"); ngx.print('" autocomplete="current-password" required>\n')
ngx.print([[
          <button type="button" class="btn-password-toggle" id="btn-toggle-pw" aria-label="Mostra/Nascondi password" title="Mostra/Nascondi password">
            <i class="fas fa-eye" id="toggle-pw-icon"></i>
          </button>
        </div>

        <div id="defaultpassword" class="auth-info-card" style="display: none;">
          <i class="fas fa-info-circle" style="color: var(--primary); margin-right: 4px;"></i>
]])
ngx.print('          '); ngx.print(T"Se non modificata, la password predefinita corrisponde all'<strong>Access Code</strong> presente sull'etichetta sotto il modem."); ngx.print('\n')
ngx.print([[
        </div>

        <div style="margin-top: 24px;">
          <button id="sign-me-in" type="button" class="btn-modern-primary">
            <i id="sign-me-in-icon" class="fas fa-sign-in-alt"></i>
            <span id="sign-me-in-text">]]) ngx.print(T"Accedi") ngx.print([[</span>
          </button>
        </div>
      </form>
    </div>

    <div id="forgot-login" style="display: none;">
      <div class="auth-header" style="margin-bottom: 20px;">
        <h2 class="auth-title" style="font-size: 18px;">]]) ngx.print(T"Reset Password") ngx.print([[</h2>
      </div>

      <div id="erroruserpass1" class="auth-alert-toast">
        <i class="fas fa-exclamation-circle"></i>
        <span>]]) ngx.print(T"Access Code non valido.") ngx.print([[</span>
      </div>

      <div class="auth-info-card">
        <i class="fas fa-key"></i> ]]) ngx.print(T'Inserisci il codice <strong>"Access Code"</strong> presente sotto il modem.') ngx.print([[
      </div>

      <div class="modern-input-group">
        <div class="input-prefix-icon"><i class="fas fa-key"></i></div>
        <input type="password" id="srp_password1" placeholder="]]) ngx.print(T"Access Code") ngx.print([[">
      </div>

      <div style="display: flex; gap: 10px; margin-top: 20px;">
        <button type="button" id="cancel-reset" class="btn-modern-secondary" style="flex: 1;">]]) ngx.print(T"Annulla") ngx.print([[</button>
        <button type="button" id="verify-password" class="btn-modern-primary" style="flex: 1;">]]) ngx.print(T"Verifica") ngx.print([[</button>
      </div>
    </div>

  </div>

  <div class="auth-footer">
    <span>Technicolor Gateway &bull; GUI v]]) ngx.print(cui.gui_version) ngx.print([[ &bull; &copy; ]]) ngx.print(current_year) ngx.print([[</span>
  </div>
</div>

<div class="modern-modal-overlay" id="loginfailure" role="dialog" aria-modal="true">
  <div class="modern-modal-card">
    <div class="modal-icon-shield">
      <i class="fas fa-shield-alt"></i>
    </div>
    <h3 style="font-size: 20px; font-weight: 700; color: var(--text-heading); margin: 0 0 10px 0;">]]) ngx.print(T"Accesso Bloccato") ngx.print([[</h3>
    <p style="font-size: 14px; color: var(--text-body); line-height: 1.5; margin-bottom: 20px;">
      ]]) ngx.print(passwd_count_msg) ngx.print([[<br/>
      ]]) ngx.print(timer_msg) ngx.print([[
    </p>
    <div style="display: inline-flex; align-items: center; gap: 8px; font-size: 13px; color: var(--text-muted);">
      <i class="fas fa-spinner fa-spin"></i>
      <span>]]) ngx.print(T"Sblocco automatico in corso...") ngx.print([[</span>
    </div>
  </div>
</div>

<script src="/js/jquery.min.js?version=]]) ngx.print(cui.gui_version) ngx.print([["></script>
<script src="/js/main-min-nojquery.js?version=]]) ngx.print(cui.gui_version) ngx.print([["></script>
<script src="/js/srp-min.js?version=]]) ngx.print(cui.gui_version) ngx.print([["></script>
<script src="/js/aos.js?version=]]) ngx.print(cui.gui_version) ngx.print([["></script>
]])

local lfs = require("lfs")
if lfs.attributes(string.format("/www/docroot/theme/%s/script.js", cui.gui_skin), "mode") == "file" then
  ngx.print('<script src="/theme/' .. cui.gui_skin .. '/script.js?version=' .. cui.gui_version .. '"></script>\n')
end

ngx.print([[
<script type="text/javascript">
  if (typeof AOS !== 'undefined') {
    AOS.init({ once: true, duration: 600 });
  }

  $(document).ready(function() {
    var triesbeforemsg = ]]) ngx.print(triesbeforemsg) ngx.print([[;
    var tries = 0;
    var password = "";
    var port = window.location.port || (window.location.protocol === 'https:' ? '443' : '80');
    
    if (port == "]]) ngx.print(assistance_port) ngx.print([[") {
      $("#srp_username").val("assist");
    }

    $('#srp_username').focus();

    $('#btn-toggle-pw').on('click', function(e) {
      e.preventDefault();
      var pwInput = $('#srp_password');
      var icon = $('#toggle-pw-icon');
      if (pwInput.attr('type') === 'password') {
        pwInput.attr('type', 'text');
        icon.removeClass('fa-eye').addClass('fa-eye-slash');
      } else {
        pwInput.attr('type', 'password');
        icon.removeClass('fa-eye-slash').addClass('fa-eye');
      }
    });

    $('form input').on('keydown', function(e) {
      if (e.which === 13 || e.which === 10) {
        e.preventDefault();
        $('#sign-me-in').click();
      }
    });

    $("#sign-me-in").on("click", function() {
      var btn = $(this);
      var btnIcon = $("#sign-me-in-icon");
      var btnText = $("#sign-me-in-text");

      $("#erroruserpass").removeClass("show");
      btn.prop("disabled", true);
      btnIcon.attr("class", "fas fa-circle-notch fa-spin");
      btnText.text(']]) ngx.print(T"Verifica in corso...") ngx.print([[');

      password = $("#srp_password").val();

      var legacySalts = "]]) ngx.print(legacySalts) ngx.print([[";
      var userNames = "]]) ngx.print(userNames) ngx.print([[";
      var inputUsername = $("#srp_username").val();
      var index = -1;
      var userNameArray = userNames.split(",");
      var legacySaltArray = legacySalts.split(",");
      var timeSecond;

      for (var i = 0; i < userNameArray.length - 1; i++) {
        if (inputUsername === userNameArray[i]) {
          index = i;
          break;
        }
      }
      if (index >= 0 && typeof jsSHA !== 'undefined') {
        var hashObj = new jsSHA((legacySaltArray[index] + tch.stringToHex(password)), "HEX");
        password = hashObj.getHash("SHA-1", "HEX");
      }

      var srp = new SRP();
      srp.success = function() {
        if (window.location.pathname.search(/\/login\.lp$/) === -1) {
          var curl = window.location.href;
          window.location.href = curl.substring(0, curl.indexOf("#"));
        } else {
          window.location = "/";
        }
      };

      srp.error_message = function(err) {
        if (err === 403) {
          $.get("login.lp", { action: "getcsrf" }, function(data) {
            $('meta[name=CSRFtoken]').attr('content', data);
            if (!$('#loginfailure').hasClass('active')) {
              srp.identify("/authenticate", $("#srp_username").val(), password);
            }
          });
        } else {
          btn.prop("disabled", false);
          btnIcon.attr("class", "fas fa-sign-in-alt");
          btnText.text(']]) ngx.print(T"Accedi") ngx.print([[');
          $("#erroruserpass").addClass("show");
          $("#srp_password").focus();
        }

        timeSecond = err && err.waitTime ? err.waitTime : 0;
        tries++;

        if (timeSecond > 0) {
          $("#timerSec").text(timeSecond);
          $("#pwdCount").text(tries);
          $('#loginfailure').addClass('active');
          updateWaitingTime();
        }

        if (triesbeforemsg > 0 && tries >= triesbeforemsg) {
          $("#defaultpassword").fadeIn();
        }
      };

      function updateWaitingTime() {
        var timeInterval = setInterval(function() {
          timeSecond--;
          $("#timerSec").text(timeSecond);
          if (timeSecond <= 0) {
            clearInterval(timeInterval);
            $('#loginfailure').removeClass('active');
            $("#sign-me-in").prop("disabled", false);
          }
        }, 1000);
      }

      if (!$('#loginfailure').hasClass('active')) {
        srp.identify("/authenticate", $("#srp_username").val(), password);
      }
    });

    $("#cancel-reset").on("click", function() {
      $("#forgot-login").hide();
      $("#login-section").fadeIn();
    });
  });
</script>
</body>
</html>
]])
