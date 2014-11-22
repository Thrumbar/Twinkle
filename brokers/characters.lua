local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, ToggleCharacter, UnitClass, UnitLevel, EJ_SetDifficulty, EJ_GetNumLoot, EJ_GetLootInfoByIndex, EJ_GetInstanceByIndex, EJ_IsValidInstanceDifficulty, EncounterJournal_DisplayInstance, GetDifficultyInfo, GetSpecialization, GetSpecializationInfo, GetItemInfo, RGBTableToColorCode, GetQuestDifficultyColor, GetLootSpecialization, GetSpecializationInfoByID
-- GLOBALS: ipairs, string, table, math

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Characters')
local characters

local function UpdateItemLevelQualities() end

-- iterate through loot to find dropped itemLevel
local function GetLootItemLevel(difficulty)
	if difficulty then
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
-- FOO, BAR = itemLevelQualities, ColorByItemLevel

-- TODO: FIXME: does not init levels properly
function broker:OnEnable()
	self:RegisterEvent('PLAYER_LEVEL_UP', self.Update, self)
	self:RegisterEvent('PLAYER_AVG_ITEM_LEVEL_READY', self.Update, self)
	self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED', self.Update, self)
	self:RegisterEvent('PLAYER_TALENT_UPDATE', self.Update, self)
	self:RegisterEvent('PLAYER_ENTERING_WORLD', self.Update, self)

	-- create our own characters table, so sorting doesn't influence other brokers
	characters = addon.data.GetCharacters()
	UpdateItemLevelQualities()
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('PLAYER_LEVEL_UP')
	self:UnregisterEvent('PLAYER_AVG_ITEM_LEVEL_READY')
	self:UnregisterEvent('PLAYER_EQUIPMENT_CHANGED')
	self:UnregisterEvent('PLAYER_TALENT_UPDATE')
	self:UnregisterEvent('PLAYER_ENTERING_WORLD')
end

function broker:OnClick(btn, down)
	ToggleCharacter('TokenFrame')
end

function broker:UpdateLDB()
	local thisCharacter = brokers:GetCharacter()
	local average = addon.data.GetAverageItemLevel(thisCharacter)

	local level      = UnitLevel('player')
	local levelColor = RGBTableToColorCode(GetQuestDifficultyColor(level))
	local _, class   = UnitClass('player')
	local classColor = RGBTableToColorCode(_G.RAID_CLASS_COLORS[class])

	local specID = GetSpecialization()
	local name, icon
	if specID then
		_, name, _, icon = GetSpecializationInfo(specID)
	else
		name = 'No specialization'
		icon = ''
	end

	local lootSpecID = GetLootSpecialization()
	if lootSpecID ~= 0 then
		local role
		_, name, _, icon, _, role = GetSpecializationInfoByID(lootSpecID)
	end

	self.text = string.format('%2$sL%1$s|r %4$s%3$s %6$s |T%7$s:0|t',
		level, levelColor,
		name, classColor,
		icon,
		ColorByItemLevel(average),
		'Interface\\GROUPFRAME\\UI-GROUP-MAINTANKICON'
	)
	-- self.icon = 'Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon'
end

local sortBy, sortReverse
local function Sort(a, b)
	local aValue, bValue
	if sortBy == 1 then
		aValue, bValue = addon.data.GetLevel(a), addon.data.GetLevel(b)
	elseif sortBy == 2 then
		aValue, bValue = addon.data.GetName(a), addon.data.GetName(b)
	else
		aValue, bValue = addon.data.GetAverageItemLevel(a), addon.data.GetAverageItemLevel(b)
	end
	if sortReverse then
		return aValue > bValue
	else
		return aValue < bValue
	end
end
local function SortCharacterList(self, sortType, btn, up)
	if sortBy == sortType then
		sortReverse = not sortReverse
	else
		sortBy = sortType
		sortReverse = false
	end
	table.sort(characters, Sort)
	broker:Update()
end

function broker:UpdateTooltip()
	local numColumns, lineNum = 4
	self:SetColumnLayout(numColumns, 'LEFT', 'LEFT', 'LEFT', 'RIGHT')
	--, 'LEFT', string.split(',', string.rep('RIGHT,', numColumns-1)))

	-- header
	lineNum = self:AddHeader()
			  self:SetCell(lineNum, 1, addonName .. ': ' .. _G.CHARACTER, 'LEFT', numColumns)

	-- sorting
	lineNum = self:AddLine(_G.LEVEL_ABBR, _G.CHARACTER, '', 'iLevel')
	for column = 1, numColumns do
		self:SetCellScript(lineNum, column, 'OnMouseUp', SortCharacterList, column)
	end
	self:AddSeparator(2)

	-- data lines
	for _, characterKey in ipairs(characters) do
		local level = addon.data.GetLevel(characterKey)
		local color = RGBTableToColorCode(GetQuestDifficultyColor(level))

		local currentSpec  = DataStore:GetActiveTalents(characterKey)
		local activeSpec   = DataStore:GetSpecializationID(characterKey, currentSpec)
		local inactiveSpec = DataStore:GetSpecializationID(characterKey, currentSpec == 2 and 1 or 2)

		if activeSpec then
			_, _, _, activeSpec = GetSpecializationInfoByID(activeSpec)
		end
		if inactiveSpec then
			_, _, _, inactiveSpec = GetSpecializationInfoByID(inactiveSpec)
		end
		activeSpec   = activeSpec or '' -- 'Interface\\Icons\\INV_MISC_QUESTIONMARK'
		inactiveSpec = inactiveSpec or '' -- 'Interface\\Icons\\INV_MISC_QUESTIONMARK'

		lineNum = self:AddLine(
			color..level..'|r',
			addon.data.GetCharacterText(characterKey),
			'|T'..activeSpec..':0|t |T'..inactiveSpec..':0|t',
			ColorByItemLevel(addon.data.GetAverageItemLevel(characterKey))
		)
	end
end
