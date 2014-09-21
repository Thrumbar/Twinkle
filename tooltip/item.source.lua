local addonName, ns, _ = ...

local LPT = LibStub("LibPeriodicTable-3.1", true)
local LBFactions = LibStub("LibBabble-Faction-3.0"):GetLookupTable()

local _, _, VALOR = GetCurrencyInfo(VALOR_CURRENCY)
local _, _, CONQUEST = GetCurrencyInfo(CONQUEST_CURRENCY)
local _, LEATHERWORKING, TAILORING, ENGINEERING, BLACKSMITHING, COOKING, ALCHEMY, FIRSTAID, ENCHANTING, FISHING, JEWELCRAFTING, INSCRIPTION = GetAuctionItemSubClasses(7)

-- TODO: brighten up
local reputationColors = { "|cFFA00000", "|cFFA00000", "|cFFA00000", "|cFFD2AC00", "|cFF51AB01", "|cFF51AB01", "|cFF51AB01", "|cFF00BE70" }
local tradeskills = {
	["Alchemy"]			=  2259,	[ALCHEMY]			=  2259,
	["Blacksmithing"]	=  2018,	[BLACKSMITHING]		=  2018,
	["Enchanting"]		=  7411,	[ENCHANTING]		=  7411,
	["Engineering"]		=  4036,	[ENGINEERING]		=  4036,
	["Inscription"]		= 45357,	[INSCRIPTION]		= 45357,
	["Jewelcrafting"]	= 25229,	[JEWELCRAFTING]		= 25229,
	["Leatherworking"]	=  2108,	[LEATHERWORKING]	=  2108,
	["Tailoring"]		=  3908,	[TAILORING]			=  3908,
	["Herbalism"]		=  2366,
	["Mining"]			=  2575,
	["Skinning"]		=  8613,

	-- TODO: add "way of the X" as fake professions to track their levels? see item:87266
	["Cooking"]			=  2550,	[COOKING]			=  2550,
	["First Aid"]		=  3273,	[FIRSTAID]			=  3273,
	["Fishing"]			=  7620,	[FISHING]			=  7620,
	["Archaeology"]		= 78670,
}

function ns.GetProfessionName(itemClass, subClass)
	local spellID = subClass and tradeskills[subClass] or tradeskills[itemClass]
	return spellID and GetSpellInfo(spellID) or subClass
end

-- ================================================
--  Item Sources
-- ================================================
local itemSources = {}
local function GetItemSources(item)
	wipe(itemSources)
	LoadAddOn("Blizzard_EncounterJournal")

	local itemName, link, quality, iLevel = GetItemInfo(item)
	itemName = type(item) == "string" and item or itemName
	-- local exactMatch = type(item) == "number" -- TODO: causes issues with thunderforged etc
	if not itemName then return itemSources end

	EJ_SetSearch(itemName)
	for index = 1, EJ_GetNumSearchResults() do
		local resultName, _, path, _, _, resultItemID = EncounterJournal_GetSearchDisplay(index)
		if resultItemID == item or resultName == itemName then
			-- print('search for', item, link, 'result', resultName, resultItemID, path)
			if not tContains(itemSources, path) then
				table.insert(itemSources, path)
			end
		end
	end
	EJ_ClearSearch()

	table.sort(itemSources)
	return itemSources
end

-- TODO: mapping item -> token -> source
function ns.AddItemSources(tooltip, itemID)
	local linesAdded = false
	local sources = GetItemSources(itemID)
	if #sources > 0 then
		tooltip:AddLine(' ')
		local lastInstance, encounters
		for _, path in pairs(sources) do
			local instance, encounter = path:match("(.-) | (.+)")
			if not lastInstance or instance == lastInstance then
				encounters = (encounters and encounters..", " or "") .. encounter
			else
				tooltip:AddLine(string.format("|cFFFF7F00%s:|r %s", lastInstance, encounters), nil, nil, nil, true)
				encounters = encounter
			end
			lastInstance = instance
		end
		tooltip:AddLine(string.format("|cFFFF7F00%s:|r %s", lastInstance, encounters), nil, nil, nil, true)
		linesAdded = true
	elseif LPT then
		local amount, currency
		amount = LPT:ItemInSet(itemID, "CurrencyItems.Valor Points")
		if amount then
			currency = string.format("%s |T%s:0|t", amount, VALOR)
		end
		amount = LPT:ItemInSet(itemID, "CurrencyItems.Conquest Points")
		if amount then
			currency = string.format("%s |T%s:0|t", amount, CONQUEST)
		end

		local standing, faction = LPT:ItemInSet(itemID, "Reputation.Reward")
		if standing then
			faction = faction:sub(19)
			standing = tonumber(standing)

			-- local format = currency and "|cFFFF7F00%1$s:|r |cFF%2$.2x%3$.2x%4$.2x%5$s|r (%6$s)" or "|cFFFF7F00%s:|r |cFF%.2x%.2x%.2x%s|r"
			local format = currency and "|cFFFF7F00%s:|r %s%s|r (%s)" or "|cFFFF7F00%s:|r %s%s|r"
			local text = format:format(faction and LBFactions[faction] or faction,
				-- FACTION_BAR_COLORS[standing].r*255, FACTION_BAR_COLORS[standing].g*255, FACTION_BAR_COLORS[standing].b*255,
				reputationColors[standing],
				_G["FACTION_STANDING_LABEL"..standing],
				currency)

			tooltip:AddLine(text)
			linesAdded = true
		elseif currency then
			tooltip:AddLine(_G.TABARDVENDORCOST .. " ".. currency)
			linesAdded = true
		end

		-- found sources already
		if currency or standing then return end

		local skillLevel, profession = LPT:ItemInSet(itemID, "Tradeskill.Crafted")
		if skillLevel then
			profession = profession:match("Tradeskill%.Crafted%.([^.]+)")
			profession = GetSpellInfo(tradeskills[profession] or profession) or profession

			local text
			if skillLevel ~= '0' then
				text = string.format("|cFFFF7F00%s:|r %s (%d)", _G.TRADESKILLS, profession, skillLevel)
			else
				text = string.format("|cFFFF7F00%s:|r %s", _G.TRADESKILLS, profession)
			end

			tooltip:AddLine(text, nil, nil, nil, true)
			linesAdded = true
		end
	end
	return linesAdded
end
