local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo, IsAddOnLoaded, IsQuestFlaggedCompleted, GetLFGDungeonNumEncounters, GetLFGDungeonEncounterInfo, GetLFGDungeonRewardCapInfo
-- GLOBALS: select, wipe, type, tonumber, ipairs, unpack
local format, strsplit = string.format, string.split
local max, floor = math.max, math.floor

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('weekly')

function broker:OnEnable()
	-- self:RegisterEvent('EVENT_NAME', self.Update, self)
	self:Update()
end
function broker:OnDisable()
	-- self:UnregisterEvent('EVENT_NAME')
end

function broker:OnClick(btn, down)
	-- do something, like show a UI
end

function broker:UpdateLDB()
	self.text = _G.CALENDAR_REPEAT_WEEKLY
end

-- old code
local worldBosses 	= { 32099, 32098, 32518, 32519, 33117, 33118 }
local LFRDungeons 	= { {527, 528}, {529, 530}, {526}, {610, 611, 612, 613}, {716, 717, 724, 725} }
local weeklyQuests 	= { -- sharedID or 'allianceID|hordeID'
	32610, 32626, 32609, 32505, '32640|32641', -- Isle of Thunder (stone, key, chest, chamberlain, champions)
	'32719|32718', -- lesser charms trade-in
	33338, 33334, --32956, -- timeless isle (epoch stone, rares, pirate chest)
}
local currencies 	= { _G.VALOR_CURRENCY, _G.JUSTICE_CURRENCY, 738, 697, 752, 776 } -- lesser/elder/mogu/warforged charm
--[[
CONQUEST_CURRENCY = 390
HONOR_CURRENCY = 392
--]]

local function tex(item, text)
	local icon = select(10, GetItemInfo(item))
	return icon and '|T'..icon..':0|t' or text or '?'
end
local returnTable = {}
local function getColumnHeaders(dataType)
	if dataType == 'lfr' then
		return _G.RAID_FINDER,
			'MV', 'HoF', 'ToES', 'ToT', 'SoO'
	elseif dataType == 'boss' then
		return _G.BATTLE_PET_SOURCE_7, --BOSS,
			tex(89317, 'Sha'), tex(89783, 'Galleon'), tex(85513, 'Nalak'), tex(95424, 'Oondasta'), tex(102145, 'Celestials'), tex(104297, 'Ordos')
	elseif dataType == 'weekly' then
		return _G.QUESTS_LABEL
			, tex(94221, 'Stone'), tex(94222, 'Key'), tex(87391, 'Chest'), tex(93792, 'Chamberlain'), tex(90538, 'Champions')
			, tex(90815, 'Charms')
			--, tex(97849, 'Barrens')
			, tex(105715, 'Epoch'), tex(33847, 'Rares')
	end
	return ''
end
local function colorize(value, goodValue, badValue)
	local returnString = value or ''
	if goodValue and badValue and goodValue == badValue then
		returnString = _G.GRAY_FONT_COLOR_CODE .. value .. _G.FONT_COLOR_CODE_CLOSE
	elseif goodValue and value == goodValue then
		returnString = _G.GREEN_FONT_COLOR_CODE .. value .. _G.FONT_COLOR_CODE_CLOSE
	elseif badValue and value == badValue then
		returnString = _G.RED_FONT_COLOR_CODE .. value .. _G.FONT_COLOR_CODE_CLOSE
	elseif type(value) == "number" and type(goodValue) == "number" and type(badValue) == "number"
		and goodValue ~= badValue then
		-- color continuously
		local percentage = (value - badValue) / (goodValue - badValue)
		local r, g, b = 255, percentage*510, 0
		if percentage > 0.5 then
			r, g, b = 510 - percentage*510, 255, 0
		end
		returnString = format("|cff%02x%02x%02x%s|r", r, g, b, value)
	end

	return returnString
end
local function prepare(dataTable)
	for index, value in ipairs(dataTable) do
		if not value then
			dataTable[index] = '–'
		elseif value == true then
			dataTable[index] = '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t'
		else
			-- no changes
		end
	end
	return unpack(dataTable)
end

local function GetCharacterQuestState(characterKey, questID)
	if characterKey == brokers:GetCharacter() then
		return IsQuestFlaggedCompleted(questID) and true or false
	else
		return DataStore:IsWeeklyQuestCompletedBy(characterKey, questID) or false
	end
end
local function GetCharacterLockoutState(characterKey, dungeonID)
	local numEncounters, numDefeated = GetLFGDungeonNumEncounters(dungeonID)

	if characterKey == brokers:GetCharacter() then
		local _, _, cleared, available = GetLFGDungeonRewardCapInfo(dungeonID)

		numEncounters = cleared == 1 and numDefeated or (available * numEncounters)
		return numDefeated or 0, numEncounters or 0
	else
		local status, reset, numDefeated = DataStore:GetLFGInfo(characterKey, dungeonID)
		if status == true then
			return numDefeated or 0, numDefeated or 0
		elseif status == false then
			return numDefeated or 0, numEncounters or 0
		else
			return 0, 0
		end
	end

	return 0, 0
end

local lockoutReturns = { lfr = {}, worldboss = {}, weekly = {} }
local function GetCharacterLFRLockouts(characterKey, hideEmpty)
	wipe(lockoutReturns.lfr)
	local showLine = (characterKey == brokers:GetCharacter())
	local numDefeated, numEncounters, categoryData
	for index, LFRCategory in ipairs(LFRDungeons) do
		categoryData = ''
		for _, dungeonID in ipairs(LFRCategory) do
			numDefeated, numEncounters = GetCharacterLockoutState(characterKey, dungeonID)
			categoryData = (categoryData ~= '' and categoryData..' ' or '') .. colorize(numDefeated, 0, numEncounters)
			-- show line if any bosses are down or we may visit this LFR wing
			showLine = showLine or numDefeated > 0 or numEncounters > 0 or nil
		end
		lockoutReturns.lfr[index] = categoryData
	end
	return (showLine or not hideEmpty) and lockoutReturns.lfr or nil
end
local function GetCharacterBossLockouts(characterKey, hideEmpty)
	wipe(lockoutReturns.worldboss)
	local showLine, questState = characterKey == brokers:GetCharacter(), nil
	for index, questID in ipairs(worldBosses) do
		questState = GetCharacterQuestState(characterKey, questID)
		lockoutReturns.worldboss[index] = questState
		showLine = showLine or questState or nil
	end
	return (showLine or not hideEmpty) and lockoutReturns.worldboss or nil
end
local function GetCharacterWeeklyLockouts(characterKey, hideEmpty)
	wipe(lockoutReturns.weekly)
	local showLine = characterKey == brokers:GetCharacter()
	local questState, alliance, horde
	for index, questID in ipairs(weeklyQuests) do
		if type(questID) == 'string' then
			local faction = DataStore:GetCharacterFaction(characterKey)
			alliance, horde = strsplit('|', questID)
			questID = faction == 'Alliance' and tonumber(alliance) or tonumber(horde)
		end
		questState = GetCharacterQuestState(characterKey, questID)
		lockoutReturns.weekly[index] = questState
		showLine = showLine or questState or nil
	end
	return (showLine or not hideEmpty) and lockoutReturns.weekly or nil
end
-- /old code

local function NOOP() end -- do nothing
function broker:UpdateTooltip()
	local numColumns, lineNum = 1 + max(0, #worldBosses, #weeklyQuests, #LFRDungeons), 2
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': ' .. _G.CALENDAR_REPEAT_WEEKLY, 'LEFT', numColumns)

	self:AddHeader(getColumnHeaders('lfr'))
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local data = GetCharacterLFRLockouts(characterKey, true)
		if data then
			lineNum = self:AddLine(addon.data.GetCharacterText(characterKey), prepare(data))
			self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
		end
	end

	self:AddLine(' ')
	self:AddHeader(getColumnHeaders('boss'))
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local data = GetCharacterBossLockouts(characterKey, true)
		if data then
			lineNum = self:AddLine(addon.data.GetCharacterText(characterKey), prepare(data))
			self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
		end
	end

	self:AddLine(' ')
	self:AddHeader(getColumnHeaders('weekly'))
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local data = GetCharacterWeeklyLockouts(characterKey, true)
		if data then
			lineNum = self:AddLine(addon.data.GetCharacterText(characterKey), prepare(data))
			self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
		end
	end
end
