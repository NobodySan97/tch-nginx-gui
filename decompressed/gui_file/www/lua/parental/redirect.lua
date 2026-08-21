local proxy = require("datamodel")
local M = {}

function M.process()
  local _h = proxy.get("uci.dhcp.dnsmasq.@dnsmasq.hostname.@1.value"); local hostname = (_h and _h[1] and _h[1].value) or "gateway"
  local _d = proxy.get("uci.dhcp.dnsmasq.@dnsmasq.domain"); local domain = (_d and _d[1] and _d[1].value) or "lan"
  ngx.redirect("http://" .. string.untaint(hostname) .. "." .. string.untaint(domain) .. "/parental-block.lp", ngx.HTTP_MOVED_TEMPORARILY)
end

return M
