local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local dkjson = require("dkjson")
local format = string.format

local M = {}

local function count_lines(filepath)
  local f = io.open(filepath, "r")
  if not f then return 0 end
  local count = 0
  for line in f:lines() do
    if line:match("%S") and not line:match("^#") then
      count = count + 1
    end
  end
  f:close()
  return count
end

local function get_runtime_info()
  local f = io.open("/tmp/adb_runtime.json", "r")
  local info = {
    status = "disabled",
    version = "3.5.5",
    blocked_domains = "0",
    last_rundate = "-",
  }
  if f then
    local content = f:read("*a")
    f:close()
    local data = dkjson.decode(content)
    if data then
      local node = data.data or data
      info.status = node.adblock_status or "disabled"
      info.version = node.adblock_version or "3.5.5"
      local domains = node.blocked_domains or node.overall_domains or "0"
      info.blocked_domains = tostring(domains):match("(%d+)") or "0"
      info.last_rundate = node.last_rundate or node.last_run or "-"
    end
  end
  return info
end

function M.getAdblockStatus()
  local info = get_runtime_info()
  
  local enabled_sources_count = 0
  local sources = proxy.getPN("uci.adblock.source.", true) or {}
  for _, src in ipairs(sources) do
    local state = proxy.get(src.path .. "enabled")
    if state and state[1] and state[1].value == "1" then
      enabled_sources_count = enabled_sources_count + 1
    end
  end

  local white = count_lines("/etc/adblock/adblock.whitelist")
  local black = count_lines("/etc/adblock/adblock.blacklist")

  local light_map = {
    disabled = "0",
    enabled = "1",
    running = "2",
    paused = "4",
  }

  local status_code = light_map[info.status] or "0"

  return {
    state = info.status,
    status = status_code,
    status_text = "Adblock " .. info.status,
    version = info.version,
    blocked_domains = info.blocked_domains,
    last_rundate = info.last_rundate,
    enabled_lists = enabled_sources_count,
    custom_whitelist = white,
    custom_blacklist = black,
  }
end

function M.getAdblockCardHTML()
  local ui_helper = require("web.ui_helper")
  local content = M.getAdblockStatus()
  local blocked = tonumber(content.blocked_domains) or 0
  local modal_link_sources = 'class="modal-link" data-toggle="modal" data-remote="/modals/adblck-sources-modal.lp" data-id="adblck-sources-modal"'

  local html = {}
  html[#html+1] = ui_helper.createSimpleLight(content.status, content.status_text, nil, "fa fa-shield")
  html[#html+1] = '<span class="simple-desc"><i class="fa fa-list-ul" aria-hidden="true">&nbsp;</i>' .. format('<strong %s>%d Liste DNS</strong> attive', modal_link_sources, content.enabled_lists) .. '</span><br/>'
  html[#html+1] = '<span class="simple-desc"><i class="fa fa-ban" aria-hidden="true">&nbsp;</i><strong>' .. blocked .. ' Domini</strong> bloccati</span><br/>'
  html[#html+1] = '<span class="simple-desc"><i class="fa fa-clock" aria-hidden="true">&nbsp;</i><strong>Aggiornato:</strong> ' .. content.last_rundate .. '</span><br/>'
  return html
end

return M
