if true then return end





local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local _, class = UnitClass('player')
local views    = addon:GetModule('views')
local lists    = views:GetModule('lists')
local followers  = lists:NewModule('Followers', 'AceEvent-3.0')
      followers.icon = 'Interface\\Icons\\INV_Glyph_Major' .. class
      followers.title = _G.GLYPHS
      followers.excludeItemSearch = true

function followers:OnEnable()
	-- self:RegisterEvent('USE_GLYPH', lists.Update)
end
function followers:OnDisable()
	-- self:UnregisterEvent('USE_GLYPH')
end

function followers:GetNumRows(characterKey)
	return DataStore:GetNumGlyphs(characterKey)
end

function followers:GetRowInfo(characterKey, index)
	local name, _, isKnown, icon, _, link = DataStore:GetGlyphInfo(characterKey, index)
	local prefix
	local suffix = (icon and isKnown) and '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t' or '|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t'

	return (not icon) and 1 or nil, name, prefix, suffix, link
end

function followers:GetItemInfo(characterKey, index, itemIndex)
	local icon, link, tooltipText, isKnown
	if itemIndex == 1 then
		_, _, isKnown, icon, _, link = DataStore:GetGlyphInfo(characterKey, index)
		if isKnown then
			tooltipText = _G.RED_FONT_COLOR_CODE .. _G.ITEM_SPELL_KNOWN
		else
			tooltipText = _G.GREEN_FONT_COLOR_CODE .. _G.UNKNOWN
		end
	end
	return icon, link, nil, 1
end

--[[ local CustomSearch = LibStub('CustomSearch-1.0')
local linkFilters  = {
	known = {
		tags       = {},
		canSearch  = function(self, operator, search) return not operator and search == 'known' end,
		match      = function(self, text)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')

			-- glyph specific search
			local glyphID = addon.GetLinkID(hyperlink or '')
			local isKnown = DataStore:IsGlyphKnown(characterKey, glyphID)
			return isKnown
		end,
	},
}
for tag, handler in pairs(lists.filters) do
	linkFilters[tag] = handler
end
followers.filters = linkFilters --]]
