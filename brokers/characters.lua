local addonName, addon, _ = ...

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('characters')
local characters

-- GLOBALS: _G, ipairs, string, ToggleCharacter

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
	EncounterJournal_DisplayInstance(instanceID)

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
	-- EncounterJournal_LootUpdate()
	difficulty = GetLootItemLevel(difficulty)
	heroicDifficulty = GetLootItemLevel(heroicDifficulty)
	print('instance', instanceID, difficulty, heroicDifficulty)
	return difficulty, heroicDifficulty
end

local itemLevelQualities = {}
local function SetItemLevelQualities()
	local index = 1
	local instances = {}
	while EJ_GetInstanceByIndex(index, true) do
		local instanceID = EJ_GetInstanceByIndex(index, true)
		table.insert(instances, instanceID)
		index = index + 1
	end

	for i, instanceID in ipairs(instances) do
		local normal, heroic = GetDifficultyItemLevels(instanceID)
		table.insert(itemLevelQualities, normal)
		table.insert(itemLevelQualities, heroic)
	end
	table.sort(itemLevelQualities)
	while #itemLevelQualities > 5 do
		table.remove(itemLevelQualities, 1)
	end
end

local function ColorByItemLevel(itemLevel)
	if #itemLevelQualities < 1 then return itemLevel end

	local qualityIndex = 0
	for index, qualityLevel in ipairs(itemLevelQualities) do
		if itemLevel >= qualityLevel then
			qualityIndex = index
		else
			break
		end
	end
	local color = _G.ITEM_QUALITY_COLORS[qualityIndex].hex
	return color .. itemLevel .. '|r'
end

function broker:OnEnable()
	self:RegisterEvent('PLAYER_LEVEL_UP', self.Update, self)
	self:RegisterEvent('PLAYER_AVG_ITEM_LEVEL_READY', self.Update, self)

	characters = brokers:GetCharacters()
	SetItemLevelQualities()
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('PLAYER_LEVEL_UP')
	self:UnregisterEvent('PLAYER_AVG_ITEM_LEVEL_READY')
end

function broker:OnClick(btn, down)
	ToggleCharacter('TokenFrame')
end

function broker:UpdateLDB()
	local thisCharacter = brokers:GetCharacter()
	local level = addon.data.GetLevel(thisCharacter)
	local average = addon.data.GetAverageItemLevel(thisCharacter)

	self.text = string.format('L%2$d %1$s %3$s |T%4$s:0|t',
		addon.data.GetCharacterText(thisCharacter),
		level,
		ColorByItemLevel(average),
		'Interface\\GROUPFRAME\\UI-GROUP-MAINTANKICON'
	)
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
	local numColumns, lineNum = 3
	self:SetColumnLayout(numColumns, 'LEFT', 'LEFT', 'RIGHT')
	--, 'LEFT', string.split(',', string.rep('RIGHT,', numColumns-1)))

	-- header
	lineNum = self:AddHeader()
			  self:SetCell(lineNum, 1, addonName .. ': ' .. _G.CHARACTER, 'LEFT', numColumns)

	-- sorting
	lineNum = self:AddLine(_G.LEVEL_ABBR, _G.CHARACTER, 'iLevel')
	for column = 1, numColumns do
		self:SetCellScript(lineNum, column, 'OnMouseUp', SortCharacterList, column)
	end
	self:AddSeparator(2)

	-- data lines
	for _, characterKey in ipairs(characters) do
		lineNum = self:AddLine(
			addon.data.GetLevel(characterKey),
			addon.data.GetCharacterText(characterKey),
			ColorByItemLevel(addon.data.GetAverageItemLevel(characterKey))
		)
	end
end
