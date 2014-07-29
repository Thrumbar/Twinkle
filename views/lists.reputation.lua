local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: AbbreviateLargeNumbers, GetFactionInfoByID, GetItemInfo
-- GLOBALS: string

local views  = addon:GetModule('views')
local lists  = views:GetModule('lists')
local reputation = lists:NewModule('Reputation', 'AceEvent-3.0')
      reputation.icon = 'Interface\\Icons\\Achievement_Reputation_01'
      reputation.title = 'Reputations'

-- taken from wowpedia.org/reputation also see _G.FACTION_BAR_COLORS
local standingColors = {
	{ r = 0.80, g = 0.13, b = 0.13 },
	{ r = 1.00, g = 0.00, b = 0.00 },
	{ r = 0.93, g = 0.40, b = 0.13 },
	{ r = 1.00, g = 1.00, b = 0.00 },
	{ r = 0.00, g = 1.00, b = 0.00 },
	{ r = 0.00, g = 1.00, b = 0.53 },
	{ r = 0.00, g = 1.00, b = 0.80 },
	{ r = 0.00, g = 1.00, b = 1.00 },
}

function reputation:OnEnable()
	-- self:RegisterEvent('UNIT_FACTION', lists.Update, self)
end
function reputation:OnDisable()
	-- self:UnregisterEvent('UNIT_FACTION')
end

function reputation:GetNumRows(characterKey)
	return DataStore:GetNumFactions(characterKey) or 0
end

function reputation:GetRowInfo(characterKey, index)
	local factionID, reputation, standingID, standingText, low, high = DataStore:GetFactionInfo(characterKey, index)
	local title, description, _, _, _, _, _, _, isHeader, _, hasRep, _, isIndented, _, hasBonus = GetFactionInfoByID(factionID)

	local color = standingID and standingColors[standingID]
	if GetFriendshipReputation(factionID) then
		color = standingColors[standingID + 1] -- standingColors[5]
	end

	local info
	-- local prefix = hasBonus and '|TInterface\\COMMON\\ReputationStar:16:16:0:0:32:32:16:32:16:32|t' or nil
	local tiptext = description
	if standingID then
		local lowBoundary, highBoundary = reputation - low, high - low
		info = RGBTableToColorCode(color) .. (standingText or '?') .. '|r'
		if reputation < high - 1 then
			tiptext = string.format('%s|n%s%s: %s/%s|r', tiptext, RGBTableToColorCode(color),
				standingText or '', AbbreviateLargeNumbers(lowBoundary), AbbreviateLargeNumbers(highBoundary))
		end
	end

	return isHeader, title, nil, info, nil, tiptext
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
