local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, QuestLogFrame, QuestLog_SetSelection
-- GLOBALS: CreateFrame, RGBToColorCode, RGBTableToColorCode, GetItemInfo, GetSpellInfo, GetSpellLink, GetCoinTextureString, GetRelativeDifficultyColor, GetItemQualityColor, GetQuestLogIndexByID
-- GLOBALS: ipairs, tonumber, math

local views  = addon:GetModule('views')
local lists  = views:GetModule('lists')
local currencies = lists:NewModule('currencies', 'AceEvent-3.0')
      currencies.icon = 'Interface\\Icons\\PVECurrency-Justice' -- INV_Misc_Token_Darkmoon_01
      currencies.title = 'Currencies'

-- copied from wowhead.com/currencies
local currencyIDs = {
	 61, -- Dalaran Jewelcrafter's Token
	 81, -- Epicurean's Award
	241, -- Champion's Seal
	361, -- Illustrious Jewelcrafter's Token
	384, -- Dwarf Archaeology Fragment
	385, -- Troll Archaeology Fragment
	390, -- Conquest Points
	391, -- Tol Barad Commendation
	392, -- Honor Points
	393, -- Fossil Archaeology Fragment
	394, -- Night Elf Archaeology Fragment
	395, -- Justice Points
	396, -- Valor Points
	397, -- Orc Archaeology Fragment
	398, -- Draenei Archaeology Fragment
	399, -- Vrykul Archaeology Fragment
	400, -- Nerubian Archaeology Fragment
	401, -- Tol'vir Archaeology Fragment
	402, -- Ironpaw Token
	416, -- Mark of the World Tree
	515, -- Darkmoon Prize Ticket
	614, -- Mote of Darkness
	615, -- Essence of Corrupted Deathwing
	676, -- Pandaren Archaeology Fragment
	677, -- Mogu Archaeology Fragment
	697, -- Elder Charm of Good Fortune
	738, -- Lesser Charm of Good Fortune
	752, -- Mogu Rune of Fate
	754, -- Mantid Archaeology Fragment
	776, -- Warforged Seal
	777, -- Timeless Coin
	789, -- Bloody Coin
}

function currencies:OnEnable()
	for _, currencyID in ipairs(currencyIDs) do
		local currencyName = GetCurrencyInfo(currencyID)
		currencyIDs[currencyName] = currencyID
	end
	-- self:RegisterEvent('QUEST_LOG_UPDATE', lists.Update, self)
end
function currencies:OnDisable()
	-- self:UnregisterEvent('QUEST_LOG_UPDATE')
end

function currencies:GetNumRows(characterKey)
	return DataStore:GetNumCurrencies(characterKey)
end

function currencies:GetRowInfo(characterKey, index)
	local isHeader, title, count, icon = DataStore:GetCurrencyInfo(characterKey, index)
	local prefix -- = '|T'..icon..':0|t'
	local suffix = AbbreviateLargeNumbers(count)
	local currencyID = not isHeader and currencyIDs[title]

	return isHeader, title, currencyID and GetCurrencyLink(currencyID), prefix, suffix
end

function currencies:GetItemInfo(characterKey, index, itemIndex)
	local icon, link, tooltipText, count
	if itemIndex == 1 then
		local isHeader, title
		_, title, _, icon = DataStore:GetCurrencyInfo(characterKey, index)
		if not isHeader and currencyIDs[title] then
			link = GetCurrencyLink(currencyIDs[title])
		end
	end --]]

	return icon, link, tooltipText, count
end
