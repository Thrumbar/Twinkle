local addonName, addon, _ = ...

-- GLOBALS: _G, ToggleCharacter, UnitClass, UnitLevel, EJ_SetDifficulty, EJ_GetNumLoot, EJ_GetLootInfoByIndex, EJ_GetInstanceByIndex, EJ_IsValidInstanceDifficulty, EncounterJournal_DisplayInstance, GetDifficultyInfo, GetSpecialization, GetSpecializationInfo, GetItemInfo, RGBTableToColorCode, GetQuestDifficultyColor, GetLootSpecialization, GetSpecializationInfoByID
-- GLOBALS: ipairs, string, table, math

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Characters')
local characters = {}

local function UpdateItemLevelQualities() end

-- iterate through loot to find dropped itemLevel
local function GetLootItemLevel(difficulty)
	if difficulty and EJ_IsValidInstanceDifficulty(difficulty) then
		EJ_SetDifficulty(difficulty)
	end
	for index = 1, EJ_GetNumLoot() do
		local _, _, itemClass, itemSubClass, itemID, itemLink, encounterID = EJ_GetLootInfoByIndex(index)
		if itemLink and itemClass ~= '' and itemSubClass ~= '' then
			local _, _, _, iLevel = GetItemInfo(itemLink)
			return iLevel
		end
	end
end

local function GetDifficultyItemLevels(instanceID)
	-- EncounterJournal_DisplayInstance(instanceID)
	EJ_SelectInstance(instanceID)

	local difficulty, heroicDifficulty = 0
	while true do
		difficulty = difficulty + 1
		local name, groupType, isHeroic, isChallengeMode, toggleDifficultyID = GetDifficultyInfo(difficulty)
		if not name then
			break
		elseif EJ_IsValidInstanceDifficulty(difficulty) and toggleDifficultyID then
			heroicDifficulty = isHeroic and difficulty or toggleDifficultyID
			difficulty       = isHeroic and toggleDifficultyID or difficulty
			break
		end
	end
	if difficulty > 0 then
		difficulty = GetLootItemLevel(difficulty)
		heroicDifficulty = GetLootItemLevel(heroicDifficulty)
		return difficulty, heroicDifficulty
	end
end

-- TODO: FIXME: this does not work when launching the game
local itemLevelQualities, checkList = {}, {}
local function UpdateItemLevelQualities()
	local index = 1
	local instances = {}
	while EJ_GetInstanceByIndex(index, true) do
		local instanceID = EJ_GetInstanceByIndex(index, true)
		table.insert(instances, instanceID)
		index = index + 1
	end

	local needsUpdate
	for i, instanceID in ipairs(instances) do
		local normal, heroic = GetDifficultyItemLevels(instanceID)
		if not normal and not heroic and not checkList[instanceID] then
			checkList[instanceID] = true
			needsUpdate = true
		else
			checkList[instanceID] = nil
		end
		table.insert(itemLevelQualities, normal)
		table.insert(itemLevelQualities, heroic)
	end
	if needsUpdate then
		broker:RegisterEvent('EJ_LOOT_DATA_RECIEVED', UpdateItemLevelQualities)
	else
		broker:UnregisterEvent('EJ_LOOT_DATA_RECIEVED')
	end

	-- remove duplicates
	local lastLevel = math.huge
	table.sort(itemLevelQualities)
	for i = #itemLevelQualities, 1, -1 do
		if itemLevelQualities[i] >= lastLevel - 10 then
			table.remove(itemLevelQualities, i)
		else
			lastLevel = itemLevelQualities[i]
		end
	end

	while #itemLevelQualities > 5 do
		table.remove(itemLevelQualities, 1)
	end

	broker:Update()
end

local function ColorByItemLevel(itemLevel)
	if #itemLevelQualities < 1 then return itemLevel end

	local qualityIndex = 0
	for index, qualityLevel in ipairs(itemLevelQualities) do
		if itemLevel >= qualityLevel - 4 then -- let's say 4 levels below what drops is okay
			qualityIndex = index
		else
			break
		end
	end
	local color = _G.ITEM_QUALITY_COLORS[qualityIndex].hex
	return color .. itemLevel .. '|r'
end

local sortColumns = {'GetLevel', 'GetName', nil, 'GetAverageItemLevel'}
local sortOrder = {1, 4, 2}
local function Sort(a, b)
	local aValue, bValue
	for _, column in ipairs(sortOrder) do
		local sortType = sortColumns[math.abs(column)]
		aValue, bValue = addon.data[sortType](a), addon.data[sortType](b)
		if aValue ~= bValue then
			if column < 0 then
				-- reverse sorting
				return aValue > bValue
			else
				return aValue < bValue
			end
		end
	end
	return a < b
end
local function SortCharacterList(self, columnIndex, btn, up)
	local sortIndex
	for index, column in ipairs(sortOrder) do
		if math.abs(column) == columnIndex then sortIndex = index; break end
	end
	if sortIndex == 1 then
		columnIndex = -1 * sortOrder[sortIndex]
	end
	table.remove(sortOrder, sortIndex)
	table.insert(sortOrder, 1, columnIndex)
	table.sort(characters, Sort)
	broker:Update()
end

-- TODO: FIXME: does not init levels properly
function broker:OnEnable()
	self:RegisterEvent('PLAYER_LEVEL_UP', self.Update, self)
	self:RegisterEvent('PLAYER_LEVEL_CHANGED', self.Update, self)
	self:RegisterEvent('PLAYER_AVG_ITEM_LEVEL_UPDATE', self.Update, self)
	self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED', self.Update, self)
	self:RegisterEvent('PLAYER_TALENT_UPDATE', self.Update, self)
	self:RegisterEvent('PLAYER_ENTERING_WORLD', self.Update, self)
	self:RegisterEvent('PLAYER_LOOT_SPEC_UPDATED', self.Update, self)

	UpdateItemLevelQualities()
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('PLAYER_LEVEL_UP')
	self:UnregisterEvent('PLAYER_LEVEL_CHANGED')
	self:UnregisterEvent('PLAYER_AVG_ITEM_LEVEL_UPDATE')
	self:UnregisterEvent('PLAYER_EQUIPMENT_CHANGED')
	self:UnregisterEvent('PLAYER_TALENT_UPDATE')
	self:UnregisterEvent('PLAYER_ENTERING_WORLD')
	self:UnregisterEvent('PLAYER_LOOT_SPEC_UPDATED')
end

function broker:OnClick(btn, down)
	if btn == 'RightButton' then
		-- loot spec selection
		if not self.dropDown then
			local function SelectLootSpec(self, arg1, arg2, isChecked)
				SetLootSpecialization(self.value)
			end

			self.dropDown = CreateFrame('Frame', addonName..'CharacterLootSpecDropDown', UIParent, 'UIDropDownMenuTemplate')
			self.dropDown:Hide()
			self.dropDown.displayMode = 'MENU'
			self.dropDown.initialize = function(self, level, menuList)
				local info = UIDropDownMenu_CreateInfo()
				      info.func = SelectLootSpec

				-- current specialization
				local _, specName = GetSpecializationInfo(GetSpecialization())
				info.value = 0
				info.text = _G.LOOT_SPECIALIZATION_DEFAULT:format(specName)
				info.icon = 'Interface\\Buttons\\UI-GroupLoot-Dice-Up'
				info.checked = GetLootSpecialization() == info.value
				UIDropDownMenu_AddButton(info, level)

				-- specific specialiation
				for i = 1, GetNumSpecializations() do
					local id, name, _, icon, role, primaryStat = GetSpecializationInfo(i)
					info.value = id
					info.text = _G['INLINE_'.. role ..'_ICON'] .. ' ' .. name
					info.icon = icon
					info.checked = GetLootSpecialization() == info.value
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
		ToggleDropDownMenu(nil, nil, self.dropDown, 'cursor')
	else
		ToggleCharacter('PaperDollFrame')
	end
end

function broker:UpdateLDB()
	local thisCharacter = addon.data.GetCurrentCharacter()
	local average    = addon.data.GetAverageItemLevel(thisCharacter)

	local level      = UnitLevel('player')
	local levelColor = RGBTableToColorCode(GetQuestDifficultyColor(level))
	local _, class   = UnitClass('player')
	local classColor = RGBTableToColorCode(_G.RAID_CLASS_COLORS[class])

	-- character spec
	local specIndex  = GetSpecialization()
	local specID, specName, _, icon, role = GetSpecializationInfo(specIndex or 0)
	if not specID then
		-- character has no active specialization
		specName = 'No specialization'
		icon = 'Interface\\Icons\\INV_Misc_QuestionMark'
	end

	local lootSpecID, lootSpecIndicator = GetLootSpecialization(), ''
	if lootSpecID == 0 then
		icon = 'Interface\\Buttons\\UI-GroupLoot-Dice-Up'
	elseif lootSpecID ~= specID then
		_, _, _, icon = GetSpecializationInfoByID(lootSpecID)
		lootSpecIndicator = '|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0|t'
	end

	self.icon = icon
	self.text = ('%sL%d|r %s%s%s|r %s%s'):format(
		levelColor, level,
		classColor, lootSpecIndicator, specName,
		ColorByItemLevel(average), '|TInterface\\GROUPFRAME\\UI-GROUP-MAINTANKICON:0|t'
	)
end

function broker:UpdateTooltip()
	local numColumns, lineNum = 4
	self:SetColumnLayout(numColumns, 'LEFT', 'LEFT', 'LEFT', 'RIGHT')

	-- header
	-- lineNum = self:AddHeader()
	-- 		  self:SetCell(lineNum, 1, addonName .. ': ' .. _G.CHARACTER, 'LEFT', numColumns)
	-- lineNum = self:AddLine()
	-- self:SetCell(lineNum, 1, NORMAL_FONT_COLOR_CODE .. 'Right-Click: Select loot specialization', 'LEFT', numColumns)

	local iLevel = _G.GARRISON_FOLLOWER_ITEM_LEVEL:gsub('%%%d?%$?d', ''):trim()
	lineNum = self:AddLine(_G.LEVEL_ABBR, _G.CHARACTER, '', iLevel)
	for column = 1, numColumns do
		if sortColumns[column] then
			self:SetCellScript(lineNum, column, 'OnMouseUp', SortCharacterList, column) -- sortColumns[column])
		end
	end
	self:AddSeparator(2)

	addon.data.GetCharacters(characters)
	table.sort(characters, Sort)

	for _, characterKey in ipairs(characters) do
		local level = addon.data.GetLevel(characterKey)
		local color = RGBTableToColorCode(GetQuestDifficultyColor(level))

		local activeSpec = addon.data.GetSpecializationID(characterKey)
		if activeSpec then
			_, _, _, activeSpec = GetSpecializationInfoByID(activeSpec)
		end
		activeSpec = activeSpec or ''

		lineNum = self:AddLine(
			color..level..'|r',
			addon.data.GetCharacterText(characterKey),
			'|T'..activeSpec..':0|t',
			ColorByItemLevel(addon.data.GetAverageItemLevel(characterKey))
		)
	end

	lineNum = self:AddLine()
	self:SetCell(lineNum, 1, NORMAL_FONT_COLOR_CODE .. 'Right-Click: Select loot specialization', 'LEFT', numColumns)
end
