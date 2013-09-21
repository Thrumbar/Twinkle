local addonName, ns, _ = ...
local LPT = LibStub("LibPeriodicTable-3.1", true)
local LBFactions = LibStub("LibBabble-Faction-3.0"):GetLookupTable()

-- GLOBALS: _G, DataStore, ItemRefTooltip, GameTooltip, TRADESKILLS, FACTION_BAR_COLORS, TABARDVENDORCOST, UNKNOWN, ITEM_SPELL_KNOWN, RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE, BATTLENET_FRIEND, DECLENSION_SET, ERR_IGNORE_ALREADY_S, AUCTIONS, TOTAL, MAIL_LABEL, BAGSLOT, ERR_QUEST_PUSH_ONQUEST_S, MINIMAP_TRACKING_BANKER, VOID_STORAGE, STAT_AVERAGE_ITEM_LEVEL_EQUIPPED
-- GLOBALS: IsAddOnLoaded, LoadAddOn, EJ_ClearSearch, EJ_SetSearch, EJ_GetNumSearchResults, EncounterJournal_GetSearchDisplay, GetItemInfo, GetSpellInfo, IsIgnored
-- GLOBALS: string, pairs, tonumber, table, type, wipe, tContains, ipairs, strtrim, hooksecurefunc

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

local characters = ns.data.GetCharacters()

local function AddEmptyLine(tooltip, slim)
	tooltip:AddLine(' ')
	if slim then
		_G[tooltip:GetName()..'TextLeft'..tooltip:NumLines()]:SetText(nil)
	end
end

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
		tooltip:AddLine(text, 1, 0, 0, true)
	else
		local friends = GetFriendsInfo(unitName)
		local text
		for character, note in pairs(friends) do
			local char = ns.data.GetCharacterText(character)
			text = (text and text .. ', ' or '') .. char .. (note ~= '' and ' ('..note..')' or '')
		end
		if text then
			text = DECLENSION_SET:format(BATTLENET_FRIEND, text)
			tooltip:AddLine(text, 0, 1, 0, true)
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
	local linesAdded = false
	local known, unknown = GetGlyphKnownInfo(itemID, onlyUnknown)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		tooltip:AddLine(RED_FONT_COLOR_CODE..ITEM_SPELL_KNOWN..": "..FONT_COLOR_CODE_CLOSE..list, nil, nil, nil, true)
		linesAdded = true
	end
	list = table.concat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(GREEN_FONT_COLOR_CODE..UNKNOWN..": "..FONT_COLOR_CODE_CLOSE..list, nil, nil, nil, true)
		linesAdded = true
	end
	return linesAdded
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
	local linesAdded = false
	local known, unknown = GetRecipeKnownInfo(professionName, craftedName, onlyUnknown)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		tooltip:AddLine(RED_FONT_COLOR_CODE..ITEM_SPELL_KNOWN..": "..FONT_COLOR_CODE_CLOSE..list, 1, 1, 1, true)
		linesAdded = true
	end
	list = table.concat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(GREEN_FONT_COLOR_CODE..UNKNOWN..": "..FONT_COLOR_CODE_CLOSE..list, 1, 1, 1, true)
		linesAdded = true
	end
	return linesAdded
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
	local linesAdded = false
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
			tooltip:AddLine(TABARDVENDORCOST .. " ".. currency)
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
				text = string.format("|cFFFF7F00%s:|r %s (%d)", TRADESKILLS, profession, skillLevel)
			else
				text = string.format("|cFFFF7F00%s:|r %s", TRADESKILLS, profession)
			end

			tooltip:AddLine(text, nil, nil, nil, true)
			linesAdded = true
		end
	end
	return linesAdded
end
-- ================================================
--  Item counts
-- ================================================
-- GUILD_BANK, CURRENTLY_EQUIPPED / INVENTORY_TOOLTIP, CURRENCY
local equipped = strtrim(STAT_AVERAGE_ITEM_LEVEL_EQUIPPED, '()'):gsub(': %%d', '')
local locationLabels = { BAGSLOT, MINIMAP_TRACKING_BANKER, VOID_STORAGE, AUCTIONS, equipped, MAIL_LABEL }
local function AddItemCounts(tooltip, itemID)
	local separator, showTotals, showGuilds, includeGuildCountInTotal = ', ', true, true, true -- TODO: config

	local overallCount, numLines = 0, 0
	for i, character in ipairs(characters) do
		local baseCount, text = overallCount, nil
		for i, count in ipairs( ns.data.GetItemCounts(character, itemID) ) do
			if count > 0 then
				overallCount = overallCount + count
				text = (text and text..separator or '') .. string.format('%s: %s%d|r', locationLabels[i], GREEN_FONT_COLOR_CODE, count)
			end
		end

		if overallCount - baseCount > 0 then
			tooltip:AddDoubleLine( ns.data.GetCharacterText(character) , text)
			numLines = numLines + 1
		end
	end
	if showGuilds then
		for guild, count in pairs( ns.data.GetGuildsItemCounts(itemID) ) do
			tooltip:AddDoubleLine(guild , string.format('%s: %s%d|r', GUILD_BANK, GREEN_FONT_COLOR_CODE, count))
			numLines = numLines + 1
			if includeGuildCountInTotal then
				overallCount = overallCount + count
			end
		end
	end
	if showTotals and numLines > 1 then
		tooltip:AddDoubleLine(' ', string.format('%s: %d', TOTAL, overallCount), nil, nil, nil, 1, 1, 1)
	end

	return numLines > 0
end

-- ================================================
--  Handlers
-- ================================================
local function ClearTooltipItem(self)
	self.twinkleDone = nil
end

local function HandleTooltipItem(self)
	if self.twinkleDone then return end
	self.twinkleDone = true

	local name, link = self:GetItem()
	if not link then return end
	local _, _, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link)
	local itemID, _ = ns.GetLinkID(link)
	-- TODO: single-character pets+mounts / mounts learned by items (e.g. cloud serpent)

	AddEmptyLine(self, true)

	local linesAdded
	if class == GLYPH then
		linesAdded = AddGlyphInfo(self, itemID)
	elseif class == RECIPE then
		local craftedName = name:match(".-: (.+)")
		linesAdded = AddCraftInfo(self, subclass, craftedName)
	elseif equipSlot ~= "" and equipSlot ~= "INVTYPE_BAG" then
		linesAdded = AddItemSources(self, itemID)
	end

	if linesAdded then AddEmptyLine(self, true) end

	if itemID ~= HEARTHSTONE_ITEM_ID then
		local itemCountsOnSHIFT = nil -- TODO: config
		if not itemCountsOnSHIFT or IsShiftKeyDown() then
			linesAdded = AddItemCounts(self, itemID)
			if linesAdded then
				AddEmptyLine(self, true)
			end
		else
			self:AddLine(BATTLENET_FONT_COLOR_CODE..'<Hold down SHIFT for item counts>')
		end
	end

	self:Show()
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
			if self.type then print('data', self.type, self.data) end
			local id, linkType = ns.GetLinkID(hyperlink)
			-- print('SetHyperlink', hyperlink, linkType, id)
			if linkType == "quest" then
				-- would use OnTooltipSetQuest but doesn't supply id
				AddOnQuestInfo(self, id)
			end
		end)

		-- GameTooltip:HookScript("OnTooltipSetSpell", HandleTooltipSpell)
		--GameTooltip:HookScript("OnTooltipSetAchievement", function(self) end) -- list max progress char/char completion states
		--GameTooltip:HookScript("OnTooltipSetEquipmentSet", function(self) end) -- ??

		hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, currencyID)
			-- print('SetCurrencyByID', currencyID)
		end)
		hooksecurefunc(GameTooltip, "SetCurrencyToken", function(self, listIndex)
			-- local _, _, count = DataStore:GetCurrencyInfoByName(character, currency)
			-- print('SetCurrencyToken', listIndex)
		end)

		ns.UnregisterEvent('ADDON_LOADED', 'tooltip_init')
	end
end, 'tooltip_init')
