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
	[_G.FAILED]   = '|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t',
	[_G.COMPLETE] = '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t',
	[_G.DAILY]    = '•', -- daily
	[_G.ELITE]    = '+', -- elite
	[_G.GROUP]    = 'G', -- group
	[_G.GUILD_CHALLENGE_TYPE1] = 'D', -- dungeon
	[_G.GUILD_CHALLENGE_TYPE2] = 'R', -- raid
	[_G.GUILD_CHALLENGE_TYPE4] = 'SC', -- scenario
	[_G.GUILD_CHALLENGE_TYPE3] = 'RBG', -- rated battle ground
	[_G.ITEM_QUALITY5_DESC]    = 'L', -- legendary
	[_G.PLAYER_V_PLAYER]       = 'PvP', -- player vs. player
	-- [_G.REPEATABLE] = '∞', -- repeatable
}

function quests:OnEnable()
	self:RegisterEvent('QUEST_LOG_UPDATE', 'Update')
end
function quests:OnDisable()
	self:UnregisterEvent('QUEST_LOG_UPDATE')
end

function quests:GetNumRows(characterKey)
	return DataStore:GetQuestLogSize(characterKey)
end

function quests:GetRowInfo(characterKey, index)
	local tags, prefix = '', ''
	local isHeader, questLink, groupSize, _, isComplete = DataStore:GetQuestLogInfo(characterKey, index)


	local questID, questLevel, title = nil, nil, questLink or ''
	if questLink and not isHeader or isHeader == 0 then
		questID, questLevel = questLink:match("quest:(%d+):(-?%d+)")
		questID, questLevel = tonumber(questID), tonumber(questLevel)
		title = questLink:gsub('[%[%]]', ''):gsub('\124c........', ''):gsub('\124r', '')
		if groupSize and groupSize > 0 then
			tags = '['..groupSize..']'
		end
	end

	if questLevel and questLevel > 0 then
		local color = GetRelativeDifficultyColor(DataStore:GetCharacterLevel(characterKey), questLevel)
		title = RGBTableToColorCode(color) .. title .. '|r'
	end

	local progress = questID and DataStore:GetQuestProgressPercentage(characterKey, questID)
	if isComplete == 1 --[[or progress == 1--]]then
		prefix = shortTags[_G.COMPLETE]
	elseif progress and progress > 0 then
		local r, g, b = addon.GetGradientColor(progress)
		prefix = ('|T%s:0:0:0:0:16:16:0:16:0:16:%d:%d:%d|t'):format('Interface\\AddOns\\Twinkle\\StatusIcon', r*255, g*255, b*255)
	end

	return isHeader and 1 or nil, title, prefix, tags, not isHeader and questLink or nil
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
	if linkType == 'quest' and questIndex > 0 then
		QuestMapFrame_OpenToQuestDetails(questID)
	end
end

local CustomSearch = LibStub('CustomSearch-1.0')
local linkFilters  = {
	level = {
		tags      = {'level', 'lvl', 'l', 'no', 'number'},
		canSearch = function(self, operator, search) return tonumber(search) end,
		match     = function(self, text, operator, search)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')
			local _, number = hyperlink:match('quest:(%d+):(-?%d+)')
			         number = tonumber(number)
			if number then
				return CustomSearch:Compare(operator, number, search)
			end
		end
	},
	--[[ active = { -- TODO: filter for any character's active quests
		tags      = {'active'},
		canSearch = function(self, operator, search) return not operator and search end,
		match     = function(self, text, operator, search)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')
			local questID = hyperlink:match('quest:(%d+):(-?%d+)')
			      questID = tonumber(questID)
			return questID and GetQuestLogIndexByID(questID)
		end
	}, --]]
	progress = {
		tags      = {'p', 'progress'},
		canSearch = function(self, operator, search)
			search = tonumber((search:gsub('%%', '')))
			if search and search < 1 then search = search * 100 end
			return search
		end,
		match     = function(self, text, operator, search)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')
			local questID = hyperlink:match('quest:(%d+):(-?%d+)')
			      questID = tonumber(questID)

			local progress = DataStore:GetQuestProgressPercentage(characterKey, questID)
			if progress then
				return CustomSearch:Compare(operator, progress * 100, search)
			end
		end
	},
	group = {
		-- TODO: rework this, since there is no more "quest tags"
		tags      = {'g', 'group', 'party', 'raid'},
		canSearch = function(self, operator, search) return not operator and search end,
		match     = function(self, text, _, search)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')
			local groupSize
			for index = 1, DataStore:GetQuestLogSize(characterKey) do
				local isHeader, questLink, size = DataStore:GetQuestLogInfo(characterKey, index)
				if questLink == hyperlink then
					groupSize = size
					break
				end
			end
			return CustomSearch:Find(search, tostring(groupSize) or '')
		end,
	},
	--[[ reward = {
		tags      = {'r', 'reward'},
		canSearch = function(self, operator, search) return search end,
		match     = function(self, text, operator, search)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')
			-- find index in character's quest list
			--[ [ local numRewards = DataStore:GetQuestLogNumRewards(characterKey, index)
			local _, _, _, money = DataStore:GetQuestLogInfo(characterKey, index)
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
}
linkFilters.difficulty = {
	tags      = {'q', 'quality', 'difficulty', 'diff'},
	canSearch = function(self, operator, search)
		if type(search) == 'number' then return (search >= 0 and search <= 4) and search or nil end
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
	match = function(self, text, operator, search)
		local characterKey, hyperlink = text:match('^([^:]-): (.*)')
		local _, questLevel = hyperlink:match('quest:(%d+):(-?%d+)')
		         questLevel = tonumber(questLevel)
		local difficulty = GetRelativeDifficultyColor(DataStore:GetCharacterLevel(characterKey), questLevel)
		for label, data in pairs(QuestDifficultyColors) do
			if data == difficulty then
				difficulty = linkFilters.difficulty.canSearch(nil, nil, label)
				break
			end
		end
		return CustomSearch:Compare(operator, difficulty, search)
	end
}
for tag, handler in pairs(lists.filters) do
	linkFilters[tag] = handler
end
quests.filters = linkFilters
