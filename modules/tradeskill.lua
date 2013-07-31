local addonName, ns, _ = ...
-- local LPT = LibStub("LibPeriodicTable-3.1", true)

-- GLOBALS:

-- ================================================
--
-- ================================================


-- ================================================
--  Events
-- ================================================
--[[ ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 == addonName then
		ns.UnregisterEvent('ADDON_LOADED', 'trandeskill_init')
	end
end, 'trandeskill_init') --]]


local blshift = _G.bit.lshift;
local band = _G.bit.band;
local strbyte = _G.string.byte

--------------------------------------------------------------------------------
-- Base 64 decode                                                             --
--------------------------------------------------------------------------------
local Base64MatchString = "[A-Za-z0-9+/]";
local base64chars = {
	'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
	'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
	'0','1','2','3','4','5','6','7','8','9','+','/'
};
local base64values = {
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63,
	52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1,
	-1, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14,
	15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
	-1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
	41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1};

function ns.DecodeBase64Char(c)
	c = strbyte(c);
	if c < 0 or c > 127 then
		return -1;
	end
	return base64values[c + 1];
end
function ns.Decode64(str)
	local out = ""
	str:gsub(".", function(c)
		local v = ns.DecodeBase64Char(c)
		for i = 0, 5 do
			out = out .. (bit.band(v, blshift(1, i)) == 0 and 0 or 1)
		end
	end)
	return out
end
