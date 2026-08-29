local modgui = require("modgui")

local KnownEncryptedPasswordLocaltion = {
	{"mmpbxrvsipnet","sip_profile_0","password"},
	{"mmpbxrvsipnet","sip_profile_1","password"},
	{"mmpbxrvsipnet","sip_profile_2","password"},
	{"cwmpd","cwmpd_config","connectionrequest_password"},
	{"cwmpd","cwmpd_config","acs_pass"},
}

local uci = require("uci").cursor()

local isEncrypted = modgui.isEncrypted
local decryptPassword = modgui.decryptPassword

local value

for _ , v in pairs(KnownEncryptedPasswordLocaltion) do
	value = uci:get(v[1],v[2],v[3])
	if isEncrypted(value) then
		local decrypted = decryptPassword(value)
		if decrypted and decrypted ~= "" then
			uci:set(v[1],v[2],v[3],decrypted)
			uci:commit(v[1])
		end
	end
end

