local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, QuestLogFrame, QuestLog_SetSelection
-- GLOBALS: CreateFrame, RGBToColorCode, RGBTableToColorCode, GetItemInfo, GetSpellInfo, GetSpellLink, GetCoinTextureString, GetRelativeDifficultyColor, GetItemQualityColor, GetQuestLogIndexByID
-- GLOBALS: ipairs, tonumber, math

local views  = addon:GetModule('views')
local lists  = views:GetModule('lists')
local reputation = lists:NewModule('reputation', 'AceEvent-3.0')
      reputation.icon = 'Interface\\Icons\\Achievement_Reputation_01'
      reputation.title = 'Reputation'

function reputation:OnEnable()
	-- self:RegisterEvent('QUEST_LOG_UPDATE', lists.Update, self)
end
function reputation:OnDisable()
	-- self:UnregisterEvent('QUEST_LOG_UPDATE')
end

function reputation:GetNumRows(characterKey)
	local reputations = DataStore:GetReputations(characterKey)
	return addon.Count(reputations)
end

function reputation:GetRowInfo(characterKey, index)
	-- local min, max, current = DataStore:GetRawReputationInfo(characterKey, factionName)

	-- local isHeader, questLink, questTag, groupSize, _, isComplete = DataStore:GetQuestLogInfo(characterKey, index)
	local isHeader, title, link, prefix, tags = false, 'Sample '..index
	return isHeader, title, not isHeader and link or nil, prefix, tags
end

function reputation:GetItemInfo(characterKey, index, itemIndex)
	local icon, link, tooltipText, count
	--[[ local numRewards = DataStore:GetQuestLogNumRewards(characterKey, index)
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
	end --]]

	return icon, link, tooltipText, count
end

--[[ function reputation:OnClickRow(btn, up)
	if not self.link then return end
	local questID, linkType = addon.GetLinkID(self.link)
	local questIndex = GetQuestLogIndexByID(questID)
	if linkType == 'quest' and questIndex then
		-- ShowUIPanel(QuestLogDetailFrame)
		QuestLog_SetSelection(QuestLogFrame.selectedIndex == questIndex and 0 or questIndex)
	end
end --]]

--[[
commendations = {
    -- itemid = factionid
    [93220] = 1270, -- shado-pan
    [92522] = 1337, -- klaxxi
    [93230] = 1345, -- lorewalkers
    [93226] = 1272, -- tillers
    [93229] = 1271, -- cloud serpent
    [93215] = 1269, -- golden lotus
    [93224] = 1341, -- august celestials
    [93225] = 1302, -- anglers
    [95548] = 1388, -- sunreaver onslaught
    [93232] = 1375, -- dominance offensive
    [95545] = 1387, -- kirin tor offensive
    [93231] = 1376, -- operation shieldwall
}
--]]
