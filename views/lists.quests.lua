local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, QuestLogFrame, QuestLog_SetSelection
-- GLOBALS: CreateFrame, RGBToColorCode, RGBTableToColorCode, GetItemInfo, GetSpellInfo, GetSpellLink, GetCoinTextureString, GetRelativeDifficultyColor, GetItemQualityColor, GetQuestLogIndexByID
-- GLOBALS: ipairs, tonumber, math

local views  = addon:GetModule('views')
local lists  = views:GetModule('lists')
local quests = lists:NewModule('Quests', 'AceEvent-3.0')
      quests.icon = 'Interface\\LFGFrame\\LFGIcon-Quest' -- grids: Ability_Ensnare
      quests.title = 'Quests'

local shortTags = {
	[_G.FAILED] = '|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t',
	[_G.COMPLETE] = '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t',
	[_G.DAILY] = '•', -- daily
	[_G.ELITE] = '+', -- elite
	[_G.PLAYER_V_PLAYER] = 'PvP', -- player vs. player
	[_G.GROUP] = 'G', -- group
	[_G.GUILD_CHALLENGE_TYPE1] = 'D', -- dungeon
	[_G.GUILD_CHALLENGE_TYPE2] = 'R', -- raid
	[_G.GUILD_CHALLENGE_TYPE4] = 'SC', -- scenario
	[_G.GUILD_CHALLENGE_TYPE3] = 'RBG', -- rated battle ground
	-- [_G.REPEATABLE] = '∞', -- repeatable
	[_G.ITEM_QUALITY5_DESC] = 'L', -- legendary
}

function quests:OnEnable()
	self:RegisterEvent('QUEST_LOG_UPDATE', lists.Update, self)
end
function quests:OnDisable()
	self:UnregisterEvent('QUEST_LOG_UPDATE')
end

function quests:GetNumRows(characterKey)
	return DataStore:GetQuestLogSize(characterKey)
end

function quests:GetRowInfo(characterKey, index)
	local isHeader, questLink, questTag, groupSize, _, isComplete = DataStore:GetQuestLogInfo(characterKey, index)
	local questID, questLevel = questLink:match("quest:(%d+):(-?%d+)")
	      questID, questLevel = tonumber(questID), tonumber(questLevel)
	local title = questLink:gsub('[%[%]]', ''):gsub('\124c........', ''):gsub('\124r', '')

	local tags = ''
	if isComplete == 1 then tags = tags .. shortTags[_G.COMPLETE] end
	if questTag and questTag ~= '' then
		if questTag == _G.ITEM_QUALITY5_DESC then
			title = RGBToColorCode(GetItemQualityColor(5)) .. title .. '|r'
		elseif questTag == _G.GROUP then
			tags = tags .. '['..((groupSize and groupSize > 0) and groupSize or 5)..']'
		else
			tags = tags .. '['..(shortTags[questTag] or questTag)..']'
		end
	end

	local progress = DataStore:GetQuestProgressPercentage(characterKey, questID)
	if isComplete ~= 1 and progress > 0 then
		title = title .. ' ('..math.floor(progress*100)..'%)'
	end
	local color  = questLevel and GetRelativeDifficultyColor(DataStore:GetCharacterLevel(characterKey), questLevel)
	local prefix = questLevel and RGBTableToColorCode(color) .. questLevel .. '|r' or ''

	return isHeader, title, prefix, tags, not isHeader and questLink or nil
end

function quests:GetItemInfo(characterKey, index, itemIndex)
	local icon, link, tooltipText, count
	local numRewards = DataStore:GetQuestLogNumRewards(characterKey, index)
	local _, _, _, _, money = DataStore:GetQuestLogInfo(characterKey, index)
	local rewardsMoney = money and money > 0

	local rewardIndex = itemIndex - (rewardsMoney and 1 or 0)
	if itemIndex == 1 and rewardsMoney then
		icon, link, tooltipText = 'Interface\\MONEYFRAME\\UI-GoldIcon', nil, GetCoinTextureString(money)..' '
	elseif rewardIndex <= numRewards then
		local rewardType, rewardID
		      rewardType, rewardID, count = DataStore:GetQuestLogRewardInfo(characterKey, index, rewardIndex)
		if rewardType == 's' then
			_, _, icon = GetSpellInfo(rewardID)
			link = GetSpellLink(rewardID)
		else
			_, link, _, _, _, _, _, _, _, icon = GetItemInfo(rewardID)
		end
	end

	return icon, link, tooltipText, count
end

function quests:OnClickRow(btn, up)
	if not self.link then return end
	local questID, linkType = addon.GetLinkID(self.link)
	local questIndex = GetQuestLogIndexByID(questID)
	if linkType == 'quest' and questIndex then
		-- ShowUIPanel(QuestLogDetailFrame)
		QuestLog_SetSelection(QuestLogFrame.selectedIndex == questIndex and 0 or questIndex)
	end
end

local Search     = LibStub('CustomSearch-1.0')
local ItemSearch = LibStub('LibItemSearch-1.2')

local questFilters = {}
questFilters.tooltip = ItemSearch.Filters.tooltip
questFilters.name = {
  	tags      = {'n', 'name', 'title'},
	canSearch = function(self, operator, search) return not operator and search end,
	match     = function(self, link, operator, search)
		local name = link:match('%[(.-)%]')
		return Search:Find(search, name)
	end
}questFilters.level = {
	tags      = {'level', 'lvl', 'l'},
	canSearch = function(self, _, search) return tonumber(search) end,
	match     = function(self, link, operator, search)
		local _, level = link:match('quest:(%d+):(-?%d+)')
		         level = tonumber(level)
		if level then
			return Search:Compare(operator, level, search)
		end
	end
}
questFilters.active = { -- quest is active on logged-in character
	tags      = {'active'},
	canSearch = function(self, operator, search) return not operator and search end,
	match     = function(self, link, operator, search)
		local questID = link:match('quest:(%d+):(-?%d+)')
		      questID = tonumber(questID)
		local index = questID and GetQuestLogIndexByID(questID)
		return index
	end
}
-- filters depending on requested character
local requestCharacterKey = nil
questFilters.progress = {
  	tags      = {'p', 'progress'},
	canSearch = function(self, operator, search) return tonumber(search) end,
	match     = function(self, link, operator, search)
		local characterKey = requestCharacterKey or addon.GetSelectedCharacter()
		local questID = link:match('quest:(%d+):(-?%d+)')
		      questID = tonumber(questID)
		local progress = DataStore:GetQuestProgressPercentage(characterKey, questID)
		if progress then
			return Search:Compare(operator, progress, search)
		end
	end
}
questFilters.difficulty = {
	tags = {'q', 'quality', 'difficulty', 'diff'},
	canSearch = function(self, operator, search)
		if search == 'trivial' or search == 'gray' or search == 'grey' then
			return 0
		elseif search == 'standard' or search == 'green' then
			return 1
		elseif search == 'difficult' or search == 'yellow' then
			return 2
		elseif search == 'verydifficult' or search == 'orange' then
			return 3
		elseif search == 'impossible' or search == 'red' then
			return 4
		end
	end,
	match = function(self, link, operator, search)
		local characterKey = requestCharacterKey or addon.GetSelectedCharacter()
		local _, questLevel = link:match('quest:(%d+):(-?%d+)')
		         questLevel = tonumber(questLevel)
		local difficulty = GetRelativeDifficultyColor(DataStore:GetCharacterLevel(characterKey), questLevel)
		for label, data in pairs(QuestDifficultyColors) do
			if data == difficulty then
				difficulty = questFilters.difficulty.canSearch(nil, nil, label)
				break
			end
		end
		print('difficulty', link, operator, search, type(search), difficulty, type(difficulty))
		return Search:Compare(operator, difficulty, search)
	end
}
--[[ questFilters.reward = {
	tags      = {'reward', 'r'},
	canSearch = function(self, operator, search) return search end,
	match     = function(self, link, operator, search)
		-- find index in character's quest list
		--[ [ local numRewards = DataStore:GetQuestLogNumRewards(characterKey, index)
		local _, _, _, _, money = DataStore:GetQuestLogInfo(characterKey, index)
		local rewardsMoney = money and money > 0

		local rewardIndex = itemIndex - (rewardsMoney and 1 or 0)
		if itemIndex == 1 and rewardsMoney then
			icon, link, tooltipText = 'Interface\\MONEYFRAME\\UI-GoldIcon', nil, GetCoinTextureString(money)..' '
		elseif rewardIndex <= numRewards then
			local rewardType, rewardID
			      rewardType, rewardID, count = DataStore:GetQuestLogRewardInfo(characterKey, index, rewardIndex)
			if rewardType == 's' then
				_, _, icon = GetSpellInfo(rewardID)
				link = GetSpellLink(rewardID)
			else
				_, link, _, _, _, _, _, _, _, icon = GetItemInfo(rewardID)
			end
		end --] ]
	end
} --]]

local textFilter = {
	text = {
	  	tags = {'text'},
		canSearch = function(self, operator, search) return not operator and search end,
		match = function(self, text, _, search)
			return Search:Find(search, text)
		end
	},
}
local numberFilter = {
	number = {
		tags = {'number', 'no'},
		canSearch = function(self, operator, search) return tonumber(search) end,
		match = function(self, number, operator, search)
			number = number and tonumber(number)
			if number then
				return Search:Compare(operator, number, search)
			end
		end,
	},
}

function quests:Search(search, characterKey)
	local hasMatch = 0

	for index = 1, self:GetNumRows(characterKey) do
		local isHeader, questLink, questTag, groupSize, _, isComplete = DataStore:GetQuestLogInfo(characterKey, index)
		-- expose for search to work
		requestCharacterKey = characterKey
		if Search:Matches(questLink, search, questFilters)
			or (questTag and Search:Matches(questTag, search, textFilter))
			or (groupSize and Search:Matches(groupSize, search, numberFilter)) then
			hasMatch = hasMatch + 1
		end
	end

	return hasMatch
end
