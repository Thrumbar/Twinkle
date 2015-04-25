local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local views    = addon:GetModule('views')
local lists    = views:GetModule('lists')
local talents  = lists:NewModule('Talents', 'AceEvent-3.0')
      talents.icon = 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_LADYLUCK_RANK2' -- Ability_Marksmanship
      talents.title = _G.TALENTS
      talents.excludeItemSearch = true

function talents:OnEnable()
	-- self:RegisterEvent('USE_GLYPH', lists.Update)
end
function talents:OnDisable()
	-- self:UnregisterEvent('USE_GLYPH')
end

function talents:GetNumRows(characterKey)
	-- TODO: maybe add header rows for "major glyphs" and "minor glyphs"
	return 2 * (MAX_TALENT_TIERS + 1)
end

function talents:GetRowInfo(characterKey, index)
	local talentIndex = (index - 1) % (MAX_TALENT_TIERS + 1)
	local isHeader = talentIndex == 0
	local specNum = index > MAX_TALENT_TIERS + 1 and 2 or 1

	local text, link
	if isHeader then
		local specID = DataStore:GetSpecializationID(characterKey, specNum)
		local _, specName, _, icon, _, role, class = GetSpecializationInfoByID(specID or 0)
		if not specName then
			specName = 'Not specialized'
			icon = 'Interface\\Icons\\Ability_Marksmanship'
			role = 'DAMAGER'
		end

		text = ('|T%s:0|t %s (%s)'):format(icon, specName, specNum == 1 and _G.SPECIALIZATION_PRIMARY or _G.SPECIALIZATION_SECONDARY)
	else
		local talentID = DataStore:GetTalentSelection(characterKey, talentIndex, specNum)
		local _, name, icon = GetTalentInfoByID(talentID or 0)
		link = GetTalentLink(talentID or 0)
		if not name then
			name = 'Not selected'
			icon = 'Interface\\Icons\\INV_Misc_QuestionMark'
		end
		text = ('|T%s:0|t %s'):format(icon, name)
	end
	return isHeader and 1 or nil, text, '', '', link
end

function talents:GetItemInfo(characterKey, index, itemIndex)
	local icon, link
	local tooltipText, count = nil, 1

	local talentIndex = (index - 1) % (MAX_TALENT_TIERS + 1)
	if itemIndex <= 3 then -- num talents per tier
		--
	end
	return icon, link, tooltipText, count
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
talents.filters = linkFilters --]]
