local addonName, ns, _ = ...
local LPT = LibStub("LibPeriodicTable-3.1", true)
local LBFactions = LibStub("LibBabble-Faction-3.0"):GetLookupTable()

-- GLOBALS: _G, DataStore, ItemRefTooltip, GameTooltip, TRADESKILLS, FACTION_BAR_COLORS, TABARDVENDORCOST, UNKNOWN, ITEM_SPELL_KNOWN
-- GLOBALS: LoadAddOn, EJ_ClearSearch, EJ_SetSearch, EJ_GetNumSearchResults, EncounterJournal_GetSearchDisplay, GetItemInfo, GetSpellInfo
-- GLOBALS: string, pairs, tonumber, table, type, wipe, tContains

-- ================================================
-- Do stuffs!
-- ================================================
local WEAPON, ARMOR, BAG, CONSUMABLE, GLYPH, TRADESKILL, RECIPE, GEM, MISC, QUEST, BATTLEPET = GetAuctionItemClasses()
local _, _, VALOR = GetCurrencyInfo(VALOR_CURRENCY)
local _, _, CONQUEST = GetCurrencyInfo(CONQUEST_CURRENCY)

local recipeKnownCharacters, recipeUnknownCharacters = {}, {}
local function GetRecipeKnownInfo(professionName, craftedName, onlyUnknown)
	wipe(recipeKnownCharacters)
	wipe(recipeUnknownCharacters)
	for _, character in pairs(DataStore:GetCharacters()) do
		local profession = DataStore:GetProfession(character, professionName)
		if profession then
			local numCrafts = DataStore:GetNumCraftLines(profession)
			local isKnown = nil
			for i = 1, numCrafts do
				local isHeader, _, spellID = DataStore:GetCraftLineInfo(profession, i)
				if not isHeader then
					local skillName = GetSpellInfo(spellID) or ""
					if skillName == craftedName then
						isKnown = true
						break
					end
				end
			end

			if isKnown and not onlyUnknown then
				table.insert(recipeKnownCharacters, ns.data.GetCharacterText(character, true))
			elseif not isKnown and numCrafts > 0 then
				local skillLevel = DataStore:GetProfessionInfo(profession)
				local characterText = string.format("%s (%d)", ns.data.GetCharacterText(character, true), skillLevel)
				table.insert(recipeUnknownCharacters, characterText)
			end
		end
	end

	return recipeKnownCharacters, recipeUnknownCharacters
end

local function AddCraftInfo(tooltip, professionName, craftedName)
	local onlyUnknown = false -- TODO: config
	local known, unknown = GetRecipeKnownInfo(professionName, craftedName, onlyUnknown)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		tooltip:AddLine(ITEM_SPELL_KNOWN..": "..list, nil, nil, nil, true)
	end
	list = table.concat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(UNKNOWN..": "..list, nil, nil, nil, true)
	end
end

-- ================================================
--  Item Sources
-- ================================================
local tradeskills = {
	["Alchemy"] = 2259,
	["Blacksmithing"] = 2018,
	["Enchanting"] = 7411,
	["Engineering"] = 4036,
	["Herbalism"] = 2366,
	["Inscription"] = 45357,
	["Jewelcrafting"] = 25229,
	["Leatherworking"] = 2108,
	["Mining"] = 2575,
	["Skinning"] = 8613,
	["Tailoring"] = 3908,
	["Archaeology"] = 78670,
	["Cooking"] = 2550,
	["First Aid"] = 3273,
	["Fishing"] = 7620,
}

local itemSources = {}
local function GetItemSources(item)
	LoadAddOn("Blizzard_EncounterJournal")

	wipe(itemSources)
	local itemName, link, quality, iLevel = GetItemInfo(item)
	local exactMatch = type(item) == "number"

	EJ_SetSearch(itemName)
	for index = 1, EJ_GetNumSearchResults() do
		local resultName, _, path, _, _, resultItemID = EncounterJournal_GetSearchDisplay(index)
		if (exactMatch and item == resultItemID) or (not exactMatch and resultName == itemName) then
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
local function AddItemSources(tooltip, itemID)
	local sources = GetItemSources(itemID)
	if #sources > 0 then
		local lastInstance, encounters

		for _, path in pairs(sources) do
			local instance, encounter = path:match("(.-) | (.+)")
			if not lastInstance or instance == lastInstance then
				encounters = (encounters and encounters..", " or "") .. encounter
			else
				local text = string.format("|cFFFF7F00%s:|r %s", instance, encounters)
				tooltip:AddLine(text, nil, nil, nil, true)
			end
			lastInstance = instance
		end
		local text = string.format("|cFFFF7F00%s:|r %s", lastInstance, encounters)
		tooltip:AddLine(text, nil, nil, nil, true)
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

			local format = currency and "|cFFFF7F00%1$s:|r |cFF%2$.2x%3$.2x%4$.2x%5$s|r (%6$s)" or "|cFFFF7F00%s:|r |cFF%.2x%.2x%.2x%s|r"
			local text = string.format(format, faction and LBFactions[faction] or faction,
				FACTION_BAR_COLORS[standing].r*255, FACTION_BAR_COLORS[standing].g*255, FACTION_BAR_COLORS[standing].b*255,
				_G["FACTION_STANDING_LABEL"..standing],
				currency)

			tooltip:AddLine(text, nil, nil, nil, true)
		elseif currency then
			tooltip:AddLine(TABARDVENDORCOST .. " ".. currency, nil, nil, nil, true)
		end

		-- found sources already
		if currency or standing then return end

		local skillLevel, profession = LPT:ItemInSet(itemID, "Tradeskill.Crafted")
		if skillLevel then
			profession = profession:match("Tradeskill%.Crafted%.([^.]+)")
			profession = GetSpellInfo(tradeskills[profession] or profession) or profession
			local text = string.format("|cFFFF7F00%s:|r %s (%d)", TRADESKILLS, profession, skillLevel)

			tooltip:AddLine(text, nil, nil, nil, true)
		end
	end
end
-- ================================================
--  Handlers
-- ================================================
local function ClearTooltipItem(self)
	self.twinkleDone = nil
end

local function HandleTooltipItem(self)
	if self.twinkleDone then return end

	local name, link = self:GetItem()
	local _, _, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link)
	local itemID, _ = ns.GetLinkID(link)
	-- isGlyph, isRecipe, isMount, isPet, ownedInfo, dropInfo

	if class == GLYPH then
		-- subclass => class name
	elseif class == RECIPE then
		local craftedName = name:match(".-: (.+)")
		AddCraftInfo(self, subclass, craftedName)
	elseif class == WEAPON or class == ARMOR then
		AddItemSources(self, itemID)
	end

	-- TODO: list owned
	self.twinkleDone = true
end

local function HandleTooltipSpell(self)
	local name, spellID = self:GetSpell()
	local title = _G[self:GetName().."TextLeft1"]:GetText()
	if title ~= name then
		local profession = title:match("(.-): "..name)
		if profession then
			AddCraftInfo(self, profession, name)
		end
	end
end

-- ================================================
--  Events
-- ================================================
ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 == addonName then
		GameTooltip:HookScript("OnTooltipCleared", ClearTooltipItem)
		ItemRefTooltip:HookScript("OnTooltipCleared", ClearTooltipItem)

		GameTooltip:HookScript("OnTooltipSetItem", HandleTooltipItem)
		ItemRefTooltip:HookScript("OnTooltipSetItem", HandleTooltipItem)

		-- GameTooltip:HookScript("OnTooltipSetSpell", HandleTooltipSpell)

		--GameTooltip:HookScript("OnTooltipSetUnit", function(self) end) -- list ignored/friend info?
		--GameTooltip:HookScript("OnTooltipSetQuest", function(self) end) -- list characters on this quest
		--GameTooltip:HookScript("OnTooltipSetAchievement", function(self) end) -- list max progress char/char completion states
		--GameTooltip:HookScript("OnTooltipSetEquipmentSet", function(self) end) -- ??

		-- hooksecurefunc(GameTooltip, "SetCurrencyByID", function(currencyID) end) -- list owned
		-- hooksecurefunc(GameTooltip, "SetCurrencyToken", function(listIndex) end) -- -"-

		ns.UnregisterEvent('ADDON_LOADED', 'tooltip_init')
	end
end, 'tooltip_init')
