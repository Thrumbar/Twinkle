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
local reputationColors = { -- TODO: brighten up
	[1] = "|cFFA00000", -- 861c10",
	[2] = "|cFFA00000", -- 994515",
	[3] = "|cFFA00000", -- aa7419",
	[4] = "|cFFD2AC00", -- a68818",
	[5] = "|cFF51AB01", -- 777601",
	[6] = "|cFF51AB01", -- 527001",
	[7] = "|cFF51AB01", -- 217201",
	[8] = "|cFF00BE70", -- 007564",
}


-- ================================================
--  Quests
-- ================================================
local questInfo = {}
local function GetOnQuestInfo(questID)
	wipe(questInfo)
	if not IsAddOnLoaded("DataStore_Quests") then
		return questInfo
	end

	-- TODO: abstract to ns.data
	for _, character in pairs(DataStore:GetCharacters()) do
		local numActiveQuests = DataStore:GetQuestLogSize(character)
		for i = 1, numActiveQuests do
			local isHeader, questLink, _, _, completed = DataStore:GetQuestLogInfo(i)
			local qID = ns.GetLinkID(questLink)
			if not isHeader and qID == questID and completed ~= 1 then
				table.insert(questInfo, ns.data.GetCharacterText(character))
			end
		end
	end
	return questInfo
end

local function AddOnQuestInfo(tooltip, questID)
	local questInfo = GetOnQuestInfo(questID)
	if #questInfo > 0 then
		-- QUEST_TOOLTIP_ACTIVE: "Ihr befindet Euch auf dieser Quest."
		-- ERR_QUEST_ACCEPTED_S: "Quest angenommen: ..."
		-- ERR_QUEST_PUSH_ONQUEST_S: "... hat diese Quest bereits"
		local text = string.format(ERR_QUEST_PUSH_ONQUEST_S, table.concat(questInfo, ", "))
		tooltip:AddLine(text, nil, nil, nil, true)
	end
end

-- ================================================
--  Social (Friends / Ignores)
-- ================================================
local friendInfo = {}
local function GetFriendsInfo(unitName)
	if not IsAddOnLoaded("DataStore_Agenda") then
		return friendInfo
	end

	wipe(friendInfo)
	for _, character in pairs(DataStore:GetCharacters()) do
		-- might just as well be <nil, nil, "">
		local _, _, note = DataStore:GetContactInfo(character, unitName)
		if note then
			friendInfo[ character ] = note
			break
		end
	end
	return friendInfo
end

local function AddSocialInfo(tooltip)
	local unitName = tooltip:GetUnit()
	if IsIgnored(unitName) then
		local text = string.format(ERR_IGNORE_ALREADY_S, unitName)
		tooltip:AddLine(text, nil, nil, nil, true)
	else
		local friends = GetFriendsInfo(unitName)
		local text
		for character, note in pairs(friends) do
			local char = ns.data.GetCharacterText(character)
			text = (text and text .. ', ' or '') .. char .. (note ~= '' and ' ('..note..')' or '')
		end
		if text then
			text = DECLENSION_SET:format(BATTLENET_FRIEND, text)
			tooltip:AddLine(text, nil, nil, nil, true)
		end
	end
end

-- ================================================
--  Glyphs
-- ================================================
local glyphKnown = {}
local glyphUnknown = {}
local function GetGlyphKnownInfo(itemID, onlyUnknown)
	wipe(glyphKnown)
	wipe(glyphUnknown)
	for _, character in pairs(DataStore:GetCharacters()) do
		local isKnown, canLearn = DataStore:IsGlyphKnown(character, itemID)
		if isKnown and not onlyUnknown then
			table.insert(glyphKnown, ns.data.GetCharacterText(character))
		elseif canLearn then
			table.insert(glyphUnknown, ns.data.GetCharacterText(character))
		end
	end
	-- glyphs only known/lernable for 1 class, so wie can sort by |cxxxxxxxxName|r
	table.sort(glyphKnown)
	table.sort(glyphUnknown)
	return glyphKnown, glyphUnknown
end

local function AddGlyphInfo(tooltip, itemID)
	local onlyUnknown = false -- TODO: config
	local known, unknown = GetGlyphKnownInfo(itemID, onlyUnknown)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		tooltip:AddLine(RED_FONT_COLOR_CODE..ITEM_SPELL_KNOWN..": "..FONT_COLOR_CODE_CLOSE..list, nil, nil, nil, true)
	end
	list = table.concat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(GREEN_FONT_COLOR_CODE..UNKNOWN..": "..FONT_COLOR_CODE_CLOSE..list, nil, nil, nil, true)
	end
end

-- ================================================
--  Recipes
-- ================================================
local recipeKnownCharacters, recipeUnknownCharacters = {}, {}
local function SortBySkill(a, b)
	local skillA = a:match("|r %((.-)%)$")
	local skillB = b:match("|r %((.-)%)$")
	return tonumber(skillA) > tonumber(skillB)
end
local function GetRecipeKnownInfo(professionName, craftedName, onlyUnknown)
	wipe(recipeKnownCharacters)
	wipe(recipeUnknownCharacters)
	if not IsAddOnLoaded("DataStore_Crafts") then
		return recipeKnownCharacters, recipeUnknownCharacters
	end

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

			local charName = ns.data.GetCharacterText(character)
			if isKnown and not onlyUnknown then
				table.insert(recipeKnownCharacters, charName)
			elseif not isKnown and numCrafts > 0 then
				local skillLevel = DataStore:GetProfessionInfo(profession)
				local characterText = string.format("%s (%d)", charName, skillLevel)
				table.insert(recipeUnknownCharacters, characterText)
			end
		end
	end
	table.sort(recipeKnownCharacters)
	table.sort(recipeUnknownCharacters, SortBySkill)
	return recipeKnownCharacters, recipeUnknownCharacters
end

local function AddCraftInfo(tooltip, professionName, craftedName)
	local onlyUnknown = false -- TODO: config
	local known, unknown = GetRecipeKnownInfo(professionName, craftedName, onlyUnknown)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		tooltip:AddLine(RED_FONT_COLOR_CODE..ITEM_SPELL_KNOWN..": "..FONT_COLOR_CODE_CLOSE..list, 1, 1, 1, true)
	end
	list = table.concat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(GREEN_FONT_COLOR_CODE..UNKNOWN..": "..FONT_COLOR_CODE_CLOSE..list, 1, 1, 1, true)
	end
end

-- ================================================
--  Item Sources
-- ================================================
local itemSources = {}
local function GetItemSources(item)
	LoadAddOn("Blizzard_EncounterJournal")

	wipe(itemSources)
	local itemName, link, quality, iLevel = GetItemInfo(item)
	itemName = type(item) == "string" and item or itemName
	-- local exactMatch = type(item) == "number" -- TODO: causes issues with thunderforged etc
	if not itemName then return itemSources end

	EJ_SetSearch(itemName)
	for index = 1, EJ_GetNumSearchResults() do
		local resultName, _, path, _, _, resultItemID = EncounterJournal_GetSearchDisplay(index)
		if item == resultItemID or resultName == itemName then
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

			-- local format = currency and "|cFFFF7F00%1$s:|r |cFF%2$.2x%3$.2x%4$.2x%5$s|r (%6$s)" or "|cFFFF7F00%s:|r |cFF%.2x%.2x%.2x%s|r"
			local format = currency and "|cFFFF7F00%s:|r %s%s|r (%s)" or "|cFFFF7F00%s:|r %s%s|r"
			local text = format:format(faction and LBFactions[faction] or faction,
				-- FACTION_BAR_COLORS[standing].r*255, FACTION_BAR_COLORS[standing].g*255, FACTION_BAR_COLORS[standing].b*255,
				reputationColors[standing],
				_G["FACTION_STANDING_LABEL"..standing],
				currency)

			tooltip:AddLine(text)
		elseif currency then
			tooltip:AddLine(TABARDVENDORCOST .. " ".. currency)
		end

		-- found sources already
		if currency or standing then return end

		local skillLevel, profession = LPT:ItemInSet(itemID, "Tradeskill.Crafted")
		if skillLevel then
			profession = profession:match("Tradeskill%.Crafted%.([^.]+)")
			profession = GetSpellInfo(tradeskills[profession] or profession) or profession

			local text
			if skillLevel ~= '0' then
				text = string.format("|cFFFF7F00%s:|r %s (%d)", TRADESKILLS, profession, skillLevel)
			else
				text = string.format("|cFFFF7F00%s:|r %s", TRADESKILLS, profession)
			end

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
	if not link then return end
	local _, _, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link)
	local itemID, _ = ns.GetLinkID(link)
	-- isMount, isPet, ownedInfo

	self:AddLine(" ")
	if class == GLYPH then
		-- subclass => class name
		AddGlyphInfo(self, itemID)
	elseif class == RECIPE then
		local craftedName = name:match(".-: (.+)")
		AddCraftInfo(self, subclass, craftedName)
	elseif equipSlot ~= "" and equipSlot ~= "INVTYPE_BAG" then
		AddItemSources(self, itemID)
	end
	-- self:AddLine(" ")

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
		GameTooltip:HookScript("OnTooltipCleared",    ClearTooltipItem)
		ItemRefTooltip:HookScript("OnTooltipCleared", ClearTooltipItem)

		GameTooltip:HookScript("OnTooltipSetItem",    HandleTooltipItem)
		ItemRefTooltip:HookScript("OnTooltipSetItem", HandleTooltipItem)

		GameTooltip:HookScript("OnTooltipSetUnit",    AddSocialInfo)
		ItemRefTooltip:HookScript("OnTooltipSetUnit", AddSocialInfo)

		hooksecurefunc(GameTooltip, "SetHyperlink", function(self, hyperlink)
			local id, linkType = ns.GetLinkID(hyperlink)
			if linkType == "quest" then
				-- would use OnTooltipSetQuest but doesn't supply id
				AddOnQuestInfo(self, id)
			end
		end)

		-- GameTooltip:HookScript("OnTooltipSetSpell", HandleTooltipSpell)
		--GameTooltip:HookScript("OnTooltipSetAchievement", function(self) end) -- list max progress char/char completion states
		--GameTooltip:HookScript("OnTooltipSetEquipmentSet", function(self) end) -- ??

		-- hooksecurefunc(GameTooltip, "SetCurrencyByID", function(currencyID) end) -- list owned
		-- hooksecurefunc(GameTooltip, "SetCurrencyToken", function(listIndex) end) -- -"-

		ns.UnregisterEvent('ADDON_LOADED', 'tooltip_init')
	end
end, 'tooltip_init')
