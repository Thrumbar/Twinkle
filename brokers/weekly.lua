local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemIcon, IsAddOnLoaded, IsQuestFlaggedCompleted, GetLFGDungeonNumEncounters, GetLFGDungeonEncounterInfo, GetLFGDungeonRewardCapInfo
-- GLOBALS: select, wipe, type, tonumber, ipairs, unpack
local format, strsplit = string.format, string.split
local max, floor = math.max, math.floor

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Weekly')
local characters = {}
local temp = {}

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
	self.icon = 'Interface\\FriendsFrame\\StatusIcon-Away'
end

--[[
local worldBosses = { -- encounter journal bossID
	-- 691, 725, 814, 826, 858, 861, -- Mists of Pandaria: Sha of Fear (qid:32099), Galleon (qid:32098), Nalak (qid:32518), Oondasta (qid:32519), Celestials (qid:33117), Ordos (qid:33118)
	1291, 1211, 1262, -- Warlords of Draenor: Drov (qid:37460/37462), Tarlna (qid:37462), Rukhmar (qid:37464/37474)
} --]]
local worldBosses = {
	-- display order: i = bossID
	-- Warlords of Draenor.
	-- 7, -- drov/tarlna
	-- 9, -- rukhmar
	-- 15, -- supreme lord kazzak
	-- boss data: bossID = encounterID
	[ 7] = 1291, -- drov:1291, tarlna:1211, spell:172612
	[ 9] = 1262, -- rukhmar, item:116771
	[15] = 1452, -- supreme lord kazzak
}
-- World boss zone: EJ_GetInstanceByIndex(1, true)
local weeklyQuests = { -- sharedQuestID or 'allianceID|hordeID'
	-- 32610, 32626, 32609, 32505, '32640|32641', -- Isle of Thunder (stone, key, chest, chamberlain, champions)
	-- '32719|32718', -- lesser charms trade-in
	-- 33338, 33334, --32956, -- timeless isle (epoch stone, rares, pirate chest)
	-- 37638, 37639, 37640, 38482, -- garrison invasions
}

local LFRDungeons, LFRInstances = {}, {}
local playerExpansion = GetAccountExpansionLevel()
-- build raid finder groups for each instance
for index = 1, GetNumRFDungeons() do
	-- ingame label: GetLFGDungeonInfo(dungeonID)
	local dungeonID, _, _, _, _, _, _, _, _, expansionLevel = GetRFDungeonInfo(index)
	if expansionLevel == playerExpansion then
		-- we only display the highest possible tiers
		local _, _, instanceLink = GetDungeonInfo(dungeonID)
		if instanceLink then
			-- molten core has no link
			local instanceID = instanceLink:match('journal:%d+:(%d+)')
			      instanceID = instanceID*1
			if not LFRInstances[instanceID] then
				LFRInstances[instanceID] = #LFRDungeons + 1
				-- let's assume that GetNumRFDungeons() is always << any instanceID
				LFRInstances[ LFRInstances[instanceID] ] = instanceID
			end
			local index = LFRInstances[instanceID]
			if not LFRDungeons[index] then LFRDungeons[index] = {} end
			table.insert(LFRDungeons[index], dungeonID)
		end
	end
end

local function tex(itemID, text)
	local icon = type(itemID) == 'number' and GetItemIcon(itemID) or itemID
	return icon and '|T'..icon..':0|t' or text or '?'
end
local function GetColumnHeaders(dataType)
	if dataType == 'lfr' then
		wipe(temp)
		for index, dungeonIDs in ipairs(LFRDungeons) do
			local instanceName, _, _, _, _, icon = EJ_GetInstanceInfo(LFRInstances[index])
			table.insert(temp, tex(icon, instanceName))
		end
		return _G.RAID_FINDER, unpack(temp)
	elseif dataType == 'boss' then
		wipe(temp)
		for index, bossID in ipairs(worldBosses) do
			local _, bossName, _, _, icon = EJ_GetCreatureInfo(1, worldBosses[bossID])
			table.insert(temp, tex(icon, bossName))
		end
		return _G.BATTLE_PET_SOURCE_7, unpack(temp)
	elseif dataType == 'weekly' then
		return _G.QUESTS_LABEL,
			-- tex(94221, 'Stone'), tex(94222, 'Key'), tex(87391, 'Chest'), tex(93792, 'Chamberlain'), tex(90538, 'Champions'),
			-- tex(90815, 'Charms'),
			-- tex(105715, 'Epoch'), tex(33847, 'Rares')
			tex('Interface\\Icons\\inv_misc_coin_19'), tex('Interface\\Icons\\inv_misc_coin_18'), tex('Interface\\Icons\\inv_misc_coin_17'), tex('Interface\\Icons\\inv_misc_coin_18'),
			nil
	end
	return ''
end
local function Colorize(value, goodValue, badValue)
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

local lockoutReturns = { lfr = {}, worldboss = {}, weekly = {} }
local function GetLFRGroup(dungeonID)
	for group, dungeons in ipairs(LFRDungeons) do
		for index, dungeon in ipairs(dungeons) do
			if dungeon == dungeonID then
				return group
			end
		end
	end
end
local function GetCharacterLFRLockouts(characterKey, hideEmpty)
	wipe(lockoutReturns.lfr)
	local hasData = false
	for _, data in ipairs(addon.data.GetLFRState(characterKey, temp)) do
		local dungeonID, name, numDefeated, completed = data.id, data.name, data.killed or 0, data.complete
		local group = GetLFRGroup(dungeonID)
		if group then
			hasData = true
			local text = lockoutReturns.lfr[group] and lockoutReturns.lfr[group]..' ' or ''
			lockoutReturns.lfr[group] = text .. Colorize(numDefeated, 0, numDefeated + (completed and 0 or 1))
		end
	end
	return hasData and lockoutReturns.lfr or nil
end

local function GetCharacterBossLockouts(characterKey, hideEmpty)
	wipe(lockoutReturns.worldboss)
	local showLine = characterKey == addon.data.GetCurrentCharacter()
	for index, bossID in ipairs(worldBosses) do
		local hasLockout = DataStore:IsWorldBossKilledBy(characterKey, bossID)
		lockoutReturns.worldboss[index] = hasLockout and true or false
		showLine = showLine or hasLockout
	end
	return (showLine or not hideEmpty) and lockoutReturns.worldboss or nil
end


local function GetCharacterQuestState(characterKey, questID)
	if characterKey == addon.data.GetCurrentCharacter() then
		return IsQuestFlaggedCompleted(questID) and true or false
	else
		return DataStore:IsWeeklyQuestCompletedBy(characterKey, questID) or false
	end
end
local function GetCharacterQuestLockouts(characterKey, hideEmpty)
	wipe(lockoutReturns.weekly)
	local showLine = characterKey == addon.data.GetCurrentCharacter()
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

local function NOOP() end -- do nothing
function broker:UpdateTooltip()
	local numColumns, lineNum = 1 + max(0, #worldBosses, #weeklyQuests, #LFRDungeons), 2
	self:SetColumnLayout(numColumns, 'LEFT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': ' .. _G.CALENDAR_REPEAT_WEEKLY, 'LEFT', numColumns)

	addon.data.GetCharacters(characters)
	-- table.sort(characters, Sort) -- TODO

	if #LFRDungeons > 0 then
		self:AddHeader(GetColumnHeaders('lfr'))
		self:AddSeparator(2)
		for _, characterKey in ipairs(characters) do
			local data = GetCharacterLFRLockouts(characterKey, true)
			if data then
				lineNum = self:AddLine(addon.data.GetCharacterText(characterKey), prepare(data))
				self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
			end
		end
	end

	if #worldBosses > 0 then
		if #LFRDungeons > 0 then self:AddLine(' ') end
		self:AddHeader(GetColumnHeaders('boss'))
		self:AddSeparator(2)
		for _, characterKey in ipairs(characters) do
			local data = GetCharacterBossLockouts(characterKey, true)
			if data then
				lineNum = self:AddLine(addon.data.GetCharacterText(characterKey), prepare(data))
				self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
			end
		end
	end

	if #weeklyQuests > 0 then
		if #LFRDungeons > 0 or #worldBosses > 0 then self:AddLine(' ') end
		self:AddHeader(GetColumnHeaders('weekly'))
		self:AddSeparator(2)
		for _, characterKey in ipairs(characters) do
			local data = GetCharacterQuestLockouts(characterKey, true)
			if data then
				lineNum = self:AddLine(addon.data.GetCharacterText(characterKey), prepare(data))
				self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
			end
		end
	end
end
