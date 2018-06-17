local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

-- TODO: display mastery spell

local lists = addon:GetModule('views'):GetModule('lists')
local specializations = lists:NewModule('Specialization', 'AceEvent-3.0')
      specializations.icon = 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_LADYLUCK_RANK2' -- Ability_Marksmanship
      specializations.title = _G.SPECIALIZATION -- _G.TALENTS
      specializations.excludeItemSearch = true
local NUM_ROWS_PER_SPEC = MAX_TALENT_TIERS + 1 -- header + talents

function specializations:OnEnable()
	-- self:RegisterEvent('USE_GLYPH', 'Update')
end
function specializations:OnDisable()
	-- self:UnregisterEvent('USE_GLYPH')
end

function specializations:GetNumRows(characterKey)
	return DataStore:GetNumSpecializations(characterKey) * NUM_ROWS_PER_SPEC
end

local UNLOCKS_AT_LEVEL = UNLOCKS_AT_LABEL .. ' %d'
-- local UNLOCKS_AT_LEVEL = GLYPH_SLOT_TOOLTIP1:gsub('%d+', '%%d')
function specializations:GetRowInfo(characterKey, index)
	local talentIndex = (index - 1) % NUM_ROWS_PER_SPEC
	local specNum     = math.ceil(index / NUM_ROWS_PER_SPEC)

	local text, link, tipText
	if talentIndex == 0 then
		-- Specialization header.
		local specID = DataStore:GetSpecializationID(characterKey, specNum)
		local _, specName, description, icon, role, class = GetSpecializationInfoByID(specID or 0)
		if not specName then
			specName = 'Not specialized'
			icon = 'Interface\\Icons\\Ability_Marksmanship'
			role = 'DAMAGER'
		else
			tipText = description
		end

		if specNum == DataStore:GetActiveTalents(characterKey) then
			specName = specName .. ' - ' .. _G.ACTIVE_PETS
		end

		text = ('|T%s:18|t %s'):format(icon, specName)
		-- specNum == 1 and _G.SPECIALIZATION_PRIMARY or _G.SPECIALIZATION_SECONDARY
	else
		-- Talent row.
		local talentID = DataStore:GetTalentSelection(characterKey, talentIndex, specNum)
		local _, name, icon = GetTalentInfoByID(talentID or 0)
		link = GetTalentLink(talentID or 0)
		if not name then
			local level = DataStore:GetCharacterLevel(characterKey) or 1 -- MAX_PLAYER_LEVEL
			local _, class = DataStore:GetCharacterClass(characterKey)
			local talentLevels = CLASS_TALENT_LEVELS[class] or CLASS_TALENT_LEVELS.DEFAULT

			name = level >= talentLevels[talentIndex] and 'Not selected' or UNLOCKS_AT_LEVEL:format(talentLevels[talentIndex]) -- LEVEL_REQUIRED
			icon = 'Interface\\Icons\\INV_Misc_QuestionMark'
		end
		text = ('|T%s:0|t %s'):format(icon, name)
	end
	return talentIndex == 0 and 1 or nil, text, '', '', link, tipText
end

function specializations:GetItemInfo(characterKey, index, itemIndex)
	local count, icon, link, tooltipText = 1, nil, nil, nil
	local talentIndex = (index - 1) % NUM_ROWS_PER_SPEC
	local specNum     = math.ceil(index / NUM_ROWS_PER_SPEC)

	if talentIndex == 0 then
		-- Specialization header.
		if itemIndex == 1 then
			local spellID = DataStore:GetSpecializationMastery(characterKey, specNum)
			_, _, icon = GetSpellInfo(spellID or 0)
			link = GetSpellLink(spellID or 0)
		end
	else
		-- Talent row.
		-- TODO display talent options
		--[[ if itemIndex <= 3 then
			local glyphType = talentIndex == 1 and 'MAJOR' or 'MINOR'
			local socket = _G['GLYPH_ID_' .. glyphType .. '_' .. (3 - itemIndex + 1)]
			local enabled, glyphID, tooltipIndex
			enabled, _, _, icon, glyphID, tooltipIndex = DataStore:GetGlyphSocketInfo(characterKey, specNum, socket)
			link        = enabled and DataStore:GetGlyphLink(glyphID) or nil
			tooltipText = (not enabled and tooltipIndex) and _G['GLYPH_SLOT_TOOLTIP' .. tooltipIndex] or nil
			icon = icon or 'Interface\\Icons\\INV_Misc_QuestionMark'
		end --]]
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
specializations.filters = linkFilters --]]
