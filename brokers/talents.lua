local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, ToggleTalentFrame, ToggleGlyphFrame
-- GLOBALS: string, ipairs

-- TODO: abstract to modules/data
-- TODO: display / change loot spec?

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('talents')
local thisCharacter = DataStore:GetCharacter()

local function CheckTalents(characterKey)
	-- GetSpecializationNameForSpecID(specializationID)
	local _, class = DataStore:GetCharacterClass(characterKey)
	local currentSpec = DataStore:GetActiveTalents(characterKey)
	if not class or not currentSpec then return end

	local primary   = DataStore:GetSpecialization(characterKey, 1)
	local secondary = DataStore:GetSpecialization(characterKey, 2)

	local primaryTree = DataStore:GetTreeNameByID(class, primary)
	local secondaryTree = DataStore:GetTreeNameByID(class, secondary)

	local currentSpecIcon = DataStore:GetTreeInfo(class, currentSpec == 1 and primary or secondary)
		or "Interface\\Icons\\INV_MISC_QUESTIONMARK"

	local unspentPrimary, unspentSecondary = addon.data.GetNumUnspentTalents(characterKey)
	return primaryTree, secondaryTree, currentSpec, currentSpecIcon, unspentPrimary > 0, unspentSecondary > 0
end

local function GetTalentStatus(characterKey)
	local primary, secondary, currentSpec, icon, unspentPrimary, unspentSecondary = CheckTalents(characterKey)

	local statusText = string.format("%s%s%s|r/%s%s%s|r ", -- space so tooltip doesn't clip o.0
		currentSpec == 1 and _G.NORMAL_FONT_COLOR_CODE or _G.GRAY_FONT_COLOR_CODE,
		primary or '?',
		unspentPrimary and '*' or '',
		currentSpec == 2 and _G.NORMAL_FONT_COLOR_CODE or _G.GRAY_FONT_COLOR_CODE,
		secondary or '?',
		unspentSecondary and '*' or ''
	)

	return statusText, icon, unspentSecondary or unspentSecondary
end

--[[ local function GetCharacterSpecInfo(characterKey, specialization)
	specialization = specialization or DataStore:GetActiveTalents(characterKey)

	local primarySpec, secondarySpec, currentSpec, _, unspentPrimary, unspentSecondary = CheckTalents(characterKey)
	local _, name, _, icon, _, role, class = GetSpecializationInfoByID(specialization == 1 and primarySpec or secondarySpec)

	return string.format('|T%s:0|t %s%s|r',
		icon,
		specialization == currentSpec and _G.NORMAL_FONT_COLOR_CODE or _G.GRAY_FONT_COLOR_CODE,
		name
	)
end --]]

function broker:OnEnable()
	self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED', self.Update, self)
	self:RegisterEvent('PLAYER_TALENT_UPDATE', self.Update, self)
	self:RegisterEvent('CHARACTER_POINTS_CHANGED', self.Update, self)
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
	self:UnregisterEvent('PLAYER_TALENT_UPDATE')
	self:UnregisterEvent('CHARACTER_POINTS_CHANGED')
end

function broker:OnClick(btn, down)
	if btn == 'RightButton' then
		ToggleGlyphFrame()
	else
		ToggleTalentFrame()
	end
end

function broker:UpdateLDB()
	local statusText, specIcon, hasUnspentTalents = GetTalentStatus(thisCharacter)
	self.text = statusText .. (hasUnspentTalents and ' *' or '')
	self.icon = specIcon

	--[[
	local lootSpec = GetLootSpecialization()
	local specID = lootSpec
	if lootSpec == 0 then
		specID = GetSpecialization()
	end
	local id, name, description, icon, background, role, class = GetSpecializationInfoByID(specID)
	--]]
end

function broker:UpdateTooltip()
	local numColumns, lineNum = 2
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	local lineNum
	lineNum = self:AddHeader()
			  self:SetCell(lineNum, 1, addonName .. ': ' .. _G.TALENTS, 'LEFT', numColumns)

	local unspent
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local statusText, specIcon, hasUnspentTalents = GetTalentStatus(characterKey)
		unspent = unspent or hasUnspentTalents

		lineNum = self:AddLine(
			'|T'..specIcon..':0|t ' .. addon.data.GetCharacterText(characterKey),
			statusText
		)
	end

	if unspent then
		self:AddSeparator(2)
		self:AddLine("* has unspent talent points")
	end
end
