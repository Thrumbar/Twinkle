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

--[[
local PublicMethods = {
	-- general functions
	GetFriendshipStanding = factions.GetFriendshipStanding,
	GetReputationStanding = factions.GetReputationStanding,
	-- character functions
	GetNumFactions        = factions.GetNumFactions,
	GetFactionInfoGuild   = factions.GetFactionInfoGuild,
	GetFactionInfoByName  = factions.GetFactionInfoByName,
	GetFactionInfoByID    = factions.GetFactionInfoByID,
	GetFactionInfo        = factions.GetFactionInfo,
}
--]]

function reputation:GetNumRows(characterKey)
	-- local reputations = DataStore:GetReputations(characterKey)
	-- return addon.Count(reputations)
	return DataStore:GetNumFactions(characterKey)
end

function reputation:GetRowInfo(characterKey, index)
	local factionID, reputation, standingID, standingText, low, high = DataStore:GetFactionInfo(characterKey, index)
	local title, description, _, _, _, _, _, _, isHeader, _, hasRep, _, isIndented = GetFactionInfoByID(factionID)

	local info
	if standingID then
		info = string.format('%s/%s', AbbreviateLargeNumbers(reputation - low), AbbreviateLargeNumbers(high - low))
	end

	return isHeader, title, nil, info, nil, description
end

local commendations = {
    [1270] = 93220, -- shado-pan
    [1337] = 92522, -- klaxxi
    [1345] = 93230, -- lorewalkers
    [1272] = 93226, -- tillers
    [1271] = 93229, -- cloud serpent
    [1269] = 93215, -- golden lotus
    [1341] = 93224, -- august celestials
    [1302] = 93225, -- anglers
    [1388] = 95548, -- sunreaver onslaught
    [1375] = 93232, -- dominance offensive
    [1387] = 95545, -- kirin tor offensive
    [1376] = 93231, -- operation shieldwall
}
function reputation:GetItemInfo(characterKey, index, itemIndex)
	local icon, link, tiptext
	local factionID = DataStore:GetFactionInfo(characterKey, index)
	local _, _, _, _, _, _, _, _, _, _, _, _, _, _, hasBonus = GetFactionInfoByID(factionID)

	if itemIndex == 1 and factionID and commendations[factionID] then
		_, link, _, _, _, _, _, _, _, icon = GetItemInfo(commendations[factionID])
	elseif itemIndex == 2 and hasBonus then
		icon = 'Interface\\RAIDFRAME\\ReadyCheck-Ready'
		tiptext = _G.BONUS_REPUTATION_TOOLTIP
	end
	return icon, link, tiptext
end
