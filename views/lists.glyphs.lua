local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local _, class = UnitClass('player')
local views  = addon:GetModule('views')
local lists  = views:GetModule('lists')
local glyphs = lists:NewModule('Glyphs', 'AceEvent-3.0')
      glyphs.icon = 'Interface\\Icons\\INV_Glyph_Major' .. class
      glyphs.title = _G.GLYPHS
      glyphs.excludeItemSearch = true

function glyphs:OnEnable()
	self:RegisterEvent('USE_GLYPH', lists.Update, lists)
	self:RegisterEvent('GLYPH_ADDED', lists.Update, lists)
	self:RegisterEvent('GLYPH_REMOVED', lists.Update, lists)
	self:RegisterEvent('GLYPH_UPDATED', lists.Update, lists)
end
function glyphs:OnDisable()
	self:UnregisterEvent('USE_GLYPH')
	self:UnregisterEvent('GLYPH_ADDED')
	self:UnregisterEvent('GLYPH_REMOVED')
	self:UnregisterEvent('GLYPH_UPDATED')
end

function glyphs:GetNumRows(characterKey)
	return DataStore:GetNumGlyphs(characterKey)
end

function glyphs:GetRowInfo(characterKey, index)
	local name, _, isKnown, icon, _, link = DataStore:GetGlyphInfo(characterKey, index)
	local prefix
	local suffix = (icon and isKnown) and '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t' or '|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t'

	return (not icon) and 1 or nil, name, prefix, suffix, link
end

function glyphs:GetItemInfo(characterKey, index, itemIndex)
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

local CustomSearch = LibStub('CustomSearch-1.0')
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
glyphs.filters = linkFilters
