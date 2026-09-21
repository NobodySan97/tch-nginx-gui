local ngx = ngx
local find, require = string.find, require
local sort = table.sort
local lfs = require("lfs")

local uci = require("uci"):cursor()

local includepath

local M = {}

local function get_rules_from_config()
	
	local rules = {}

	uci:foreach('web', 'rule', function(s)
		rules[s['.name']] = s
	end)
	
	uci:unload('web')
	
	return rules
end

local rules = get_rules_from_config()

local function get_cards_from_config()
  local config = {}
  
  uci:foreach('web', 'card', function(card)
    -- only include cards that refer to a valid modal
    -- and are not anonymous
    local rule = rules[card.modal]
    if rule and not card['.anonymous'] then
      -- set modal to the actual path of the modal
      card.modal = rule.target
      -- set correct value for hide (missing means true)
      card.hide = (card.hide~='0')
      card.raw_card = card.card
      -- remove any initial digits
      card.card = card.card:gsub("^%d+_", "")

      config[card.card] = card
    end
  end)
  uci:unload('web')
  return config
end

local config = get_cards_from_config()

local function card_visible(session, config, cardname)
  local card = config[cardname]
  if card then
    local access = false
    if session and card.modal then
      access = session:hasAccess(card.modal)
    end
    if not access and card.hide then
      return false
    end
  end
  return true
end

local cards_limiter
do
  local found
  found, cards_limiter = pcall(require, "cards_limiter")
  if not found then
    cards_limiter = nil
  end
end

local function get_limit_info()
  local fn = cards_limiter and cards_limiter.get_limit_info
  if fn then
    return fn()
  end
end

local function card_limited(info, cardname, includepath)
  local fn = cards_limiter and cards_limiter.card_limited
  if fn then
    return fn(info, cardname, includepath)
  end
  return false
end

function M.setpath(path)
  includepath = path
end

--Returns card from modal provided or nil (In-memory O(1) lookup)
function M.get_card_from_modal(ModalSearch)
	if not ModalSearch then return nil end
	local session = ngx and ngx.ctx and ngx.ctx.session
	local result
	for _, card in pairs(config) do
		if card.modal == ModalSearch then
			result = card.raw_card or card.card
			break
		end
	end
	
	if result and card_visible(session, config, (result:gsub("^%d+_", ""))) then
	  return result
	end
	
	return nil
end

--Returns card from modal provided or nil (In-memory O(1) lookup)
function M.get_modal_from_card(CardSearch)
	if not CardSearch then return nil end
	local clean_name = CardSearch:gsub("^%d+_", "")
	local card = config[clean_name] or config[CardSearch]
	return card and card.modal or nil
end

local card_files_cache = {}

function M.cards()
  local session = ngx and ngx.ctx and ngx.ctx.session
  local limit_info = get_limit_info()
  local result = {}
  local path = includepath or "/www/cards/"

  if not card_files_cache[path] then
    local files = {}
    if lfs.attributes(path, 'mode') == 'directory' then
      for file in lfs.dir(path) do
        if find(file, "%.lp$") then
          files[#files+1] = file
        end
      end
      sort(files)
    end
    card_files_cache[path] = files
  end

  for _, file in ipairs(card_files_cache[path]) do
    local cardname = file:gsub("^%d+_", "")
    if card_visible(session, config, cardname) and not card_limited(limit_info, cardname, path) then
      result[#result+1] = file
    end
  end
  return result
end

return M
