local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, QuestLogFrame, QuestLog_SetSelection
-- GLOBALS: CreateFrame, RGBToColorCode, RGBTableToColorCode, GetItemInfo, GetSpellInfo, GetSpellLink, GetCoinTextureString, GetRelativeDifficultyColor, GetItemQualityColor, GetQuestLogIndexByID
-- GLOBALS: ipairs, tonumber, math

local views  = addon:GetModule('views')
local lists  = views:GetModule('lists')
local quests = lists:NewModule('quests', 'AceEvent-3.0')
      quests.icon = 'Interface\\LFGFrame\\LFGIcon-Quest' -- grids: Ability_Ensnare
      quests.title = 'Quests'

local shortTags = {
	[_G.FAILED] = '|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t',
	[_G.COMPLETE] = '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t',
	[_G.DAILY] = '•',
	[_G.ELITE] = '+',
	[_G.PLAYER_V_PLAYER] = 'PvP',
	[_G.GROUP] = 'G',
	[_G.GUILD_CHALLENGE_TYPE1] = 'D',
	[_G.GUILD_CHALLENGE_TYPE2] = 'R',
	[_G.GUILD_CHALLENGE_TYPE4] = 'SC',
	[_G.GUILD_CHALLENGE_TYPE3] = 'RBG',
	-- [_G.REPEATABLE] = '∞',
	-- [_G.ITEM_QUALITY5_DESC] = 'L',
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

	return isHeader, title, not isHeader and questLink or nil, prefix, tags
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

--[[ local ItemSearch = LibStub('LibItemSearch-1.2')
function quests:Search(what, onWhom)
	-- TODO: relay to provider
	local hasMatch = 0
	if what and what ~= '' and what ~= _G.SEARCH then
		-- find results
		-- if ItemSearch:Matches(link, what) then
		-- 	hasMatch = hasMatch + 1
		-- end
	end

	local character = addon.GetSelectedCharacter()
	if self.panel:IsVisible() and character == onWhom then
		-- this panel is active, display filtered results
		-- ListUpdate(self.panel.scrollFrame)
	end

	return hasMatch
end
--]]
