local addonName, ns, _ = ...
local LPT = LibStub("LibPeriodicTable-3.1", true)
local LBFactions = LibStub("LibBabble-Faction-3.0"):GetLookupTable()

-- GLOBALS: _G, DataStore, ItemRefTooltip, GameTooltip, TRADESKILLS, FACTION_BAR_COLORS, TABARDVENDORCOST, UNKNOWN, ITEM_SPELL_KNOWN, RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, BATTLENET_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE, BATTLENET_FRIEND, DECLENSION_SET, ERR_IGNORE_ALREADY_S, AUCTIONS, TOTAL, MAIL_LABEL, BAGSLOT, ERR_QUEST_PUSH_ONQUEST_S, MINIMAP_TRACKING_BANKER, VOID_STORAGE, GUILD_BANK, STAT_AVERAGE_ITEM_LEVEL_EQUIPPED, HEARTHSTONE_ITEM_ID
-- GLOBALS: IsAddOnLoaded, IsShiftKeyDown, LoadAddOn, EJ_ClearSearch, EJ_SetSearch, EJ_GetNumSearchResults, EncounterJournal_GetSearchDisplay, GetItemInfo, GetSpellInfo, IsIgnored
-- GLOBALS: string, pairs, tonumber, table, type, wipe, tContains, ipairs, strtrim, hooksecurefunc

-- ================================================
-- Do stuffs!
-- ================================================
local WEAPON, ARMOR, BAG, CONSUMABLE, GLYPH, TRADESKILL, RECIPE, GEM, MISC, QUEST, BATTLEPET = GetAuctionItemClasses()
local _, LEATHERWORKING, TAILORING, ENGINEERING, BLACKSMITHING, COOKING, ALCHEMY, FIRSTAID, ENCHANTING, FISHING, JEWELCRAFTING, INSCRIPTION = GetAuctionItemSubClasses(7)
local _, _, VALOR = GetCurrencyInfo(VALOR_CURRENCY)
local _, _, CONQUEST = GetCurrencyInfo(CONQUEST_CURRENCY)
local PROFESSION_MIN_SKILL = '^' .. ns.GlobalStringToPattern(_G["ITEM_MIN_SKILL"]) .. '$'

local tradeskills = {
	["Alchemy"]			= 2259,		[ALCHEMY]			= 2259,
	["Blacksmithing"]	= 2018,		[BLACKSMITHING]		= 2018,
	["Enchanting"]		= 7411,		[ENCHANTING]		= 7411,
	["Engineering"]		= 4036,		[ENGINEERING]		= 4036,
	["Inscription"]		= 45357,	[INSCRIPTION]		= 45357,
	["Jewelcrafting"]	= 25229,	[JEWELCRAFTING]		= 25229,
	["Leatherworking"]	= 2108,		[LEATHERWORKING]	= 2108,
	["Tailoring"]		= 3908,		[TAILORING]			= 3908,
	["Herbalism"]		= 2366,
	["Mining"]			= 2575,
	["Skinning"]		= 8613,

	-- TODO: add "way of the X" as fake professions to track their levels? see item:87266
	["Cooking"]			= 2550,		[COOKING]			= 2550,
	["First Aid"]		= 3273,		[FIRSTAID]			= 3273,
	["Fishing"]			= 7620,		[FISHING]			= 7620,
	["Archaeology"]		= 78670,
}
-- TODO: brighten up
local reputationColors = { "|cFFA00000", "|cFFA00000", "|cFFA00000", "|cFFD2AC00", "|cFF51AB01", "|cFF51AB01", "|cFF51AB01", "|cFF00BE70" }

local characters = ns.data.GetCharacters()
local thisCharacter = ns.data.GetCurrentCharacter()

local function AddEmptyLine(tooltip, slim, force)
	local numLines = tooltip:NumLines()
	local lastText = _G[tooltip:GetName()..'TextLeft'..numLines]
	-- don't create multiple blank lines
	if force or (lastText and lastText:GetText() ~= nil) then
		tooltip:AddLine(' ')
		numLines = numLines + 1
	end
	if slim then
		_G[tooltip:GetName()..'TextLeft'..numLines]:SetText(nil)
	end
end

-- ================================================
--  Quests
-- ================================================
local questInfo = {}
-- TODO: return list of characters that completed quest, too
local function GetOnQuestInfo(questID, onlyActive)
	wipe(questInfo)
	if not IsAddOnLoaded("DataStore_Quests") then
		return questInfo
	end

	-- TODO: abstract to ns.data
	for _, character in ipairs(characters) do
		local numActiveQuests = DataStore:GetQuestLogSize(character)
		for i = 1, numActiveQuests do
			local isHeader, questLink, _, _, completed = DataStore:GetQuestLogInfo(character, i)
			local qID = ns.GetLinkID(questLink)
			if not isHeader and qID == questID and completed ~= 1 then
				table.insert(questInfo, ns.data.GetCharacterText(character))
			end
		end
	end

	-- ERR_QUEST_PUSH_ACCEPTED_S = "%1$s hat Eure Quest angenommen."
	-- ERR_QUEST_PUSH_ALREADY_DONE_S = "%s hat die Quest abgeschlossen"
	-- QUEST_COMPLETE = "Quest abgeschlossen"

	return questInfo
end

local function AddOnQuestInfo(tooltip, questID)
	local linesAdded = nil
	local onlyActive = false -- TODO: config
	local questInfo = GetOnQuestInfo(questID, onlyActive)
	if #questInfo > 0 then
		-- QUEST_TOOLTIP_ACTIVE: "Ihr befindet Euch auf dieser Quest."
		-- ERR_QUEST_ACCEPTED_S: "Quest angenommen: ..."
		-- ERR_QUEST_PUSH_ONQUEST_S: "... hat diese Quest bereits"
		local text = string.format(ERR_QUEST_ACCEPTED_S, table.concat(questInfo, ", "))
		tooltip:AddLine(text, nil, nil, nil, true)
		linesAdded = true
	end
	return linesAdded
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
	for _, character in ipairs(characters) do
		-- might just as well be <nil, nil, "">
		local _, _, note = DataStore:GetContactInfo(character, unitName)
		if note then
			friendInfo[ character ] = note
			break
		end
	end
	return friendInfo
end

local function AddSocialInfo(self)
	local unitName = self:GetUnit()
	if IsIgnored(unitName) then
		local text = string.format(ERR_IGNORE_ALREADY_S, unitName)
		self:AddLine(text, 1, 0, 0, true)
	else
		local friends = GetFriendsInfo(unitName)
		local text
		for character, note in pairs(friends) do
			local char = ns.data.GetCharacterText(character)
			text = (text and text .. ', ' or '') .. char .. (note ~= '' and ' ('..note..')' or '')
		end
		if text then
			text = DECLENSION_SET:format(BATTLENET_FRIEND, text)
			self:AddLine(text, 0, 1, 0, true)
		end
	end
	self:Show()
end

-- ================================================
--  Currencies
-- ================================================
local currencyInfo = {}
local function GetCurrencyInfo(currencyID)
	wipe(currencyInfo)
	for _, character in ipairs(characters) do
		for i = 1, ns.data.GetNumCurrencies(character) do
			local isHeader, _, count, _ = ns.data.GetCurrencyInfo(character, currencyID)
			if not isHeader and count and count > 0 then
				currencyInfo[character] = count
			end
		end
	end
	return currencyInfo
end

local function AddCurrencyInfo(tooltip, currencyID)
	local showTotals = true -- TODO: config

	local linesAdded, overallCount = nil, 0
	local data = GetCurrencyInfo(currencyID)
	for characterKey, count in pairs(data) do
		local characterText = ns.data.GetCharacterText(characterKey)
		overallCount = overallCount + count
		tooltip:AddDoubleLine(characterText, count)
		linesAdded = (linesAdded or 0) + 1
	end
	if showTotals and linesAdded and linesAdded > 1 then
		tooltip:AddDoubleLine(' ', string.format('%s: %d', TOTAL, overallCount), nil, nil, nil, 1, 1, 1)
	end

	return linesAdded
end

-- ================================================
--  Glyphs
-- ================================================
local glyphKnown = {}
local glyphUnknown = {}
local function GetGlyphKnownInfo(glyph, onlyUnknown)
	wipe(glyphKnown)
	wipe(glyphUnknown)
	-- TODO: add level learnable info "Mychar (60)"
	for _, character in ipairs(characters) do
		local isKnown, canLearn = DataStore:IsGlyphKnown(character, glyph)
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

-- <glyph: itemID | glyph name>
local function AddGlyphInfo(tooltip, glyph)
	local onlyUnknown = false -- TODO: config
	local linesAdded = false
	local known, unknown = GetGlyphKnownInfo(glyph, onlyUnknown)

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
local function SortByName(a, b)
	local nameA = a:gsub('|c........', ''):gsub('|r', '')
	local nameB = b:gsub('|c........', ''):gsub('|r', '')
	return nameA < nameB
end
local function SortBySkill(a, b)
	local skillA = a:match("%((.-)%)") or math.huge
	local skillB = b:match("%((.-)%)") or math.huge
	if skillA ~= skillB then
		return tonumber(skillA) > tonumber(skillB)
	else
		return SortByName(a, b)
	end
end
local function GetRecipeKnownInfo(craftedName, professionName, requiredSkill)
	local onlyUnknown = false -- TODO: config

	wipe(recipeKnownCharacters)
	wipe(recipeUnknownCharacters)
	if not IsAddOnLoaded("DataStore_Crafts") then
		return recipeKnownCharacters, recipeUnknownCharacters
	end

	local selfKnown = nil
	for _, character in ipairs(characters) do
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

			if isKnown and character == thisCharacter then
				selfKnown = true
			end

			local charName = ns.data.GetCharacterText(character)
			if isKnown and not onlyUnknown then
				table.insert(recipeKnownCharacters, charName)
			elseif not isKnown and numCrafts > 0 then
				local skillLevel = DataStore:GetProfessionInfo(profession)
				--[[ local learnableColor = (not requiredSkill and HIGHLIGHT_FONT_COLOR_CODE)
					or (skillLevel >= requiredSkill and GREEN_FONT_COLOR_CODE)
					or RED_FONT_COLOR_CODE --]]

				local characterText
				if not requiredSkill or skillLevel >= requiredSkill then
					characterText = charName
				else
					characterText = string.format("%s %s(%d)|r", charName, RED_FONT_COLOR_CODE, skillLevel)
				end
				-- local characterText = string.format("%s %s(%d)|r", charName, learnableColor, skillLevel)
				table.insert(recipeUnknownCharacters, characterText)
			end
		end
	end
	table.sort(recipeKnownCharacters, SortByName)
	table.sort(recipeUnknownCharacters, SortBySkill)
	return recipeKnownCharacters, recipeUnknownCharacters, selfKnown
end

local function AddCraftInfo(tooltip, professionName, craftedName, requiredSkill)
	local onlyUnknown = false -- TODO: config
	local linesAdded = false
	local known, unknown, selfKnown = GetRecipeKnownInfo(craftedName, professionName, requiredSkill)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		if selfKnown then
			-- don't show duplicate ITEM_SPELL_KNOWN line
			local line, text
			for lineNum = tooltip:NumLines(), 1, -1 do
				line = _G[tooltip:GetName().."TextLeft"..lineNum]
				text = line:GetText()
				if text and text == ITEM_SPELL_KNOWN then
					line:SetText(nil)
					break
				end
			end
		end

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
	for _, character in ipairs(characters) do
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

-- TODO: single-character pets+mounts / mounts learned by items (e.g. cloud serpent)
local function HandleTooltipItem(self)
	local name, link = self:GetItem()
	if not link then return end
	local _, _, quality, iLevel, reqLevel, itemClass, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link)
	local itemID = ns.GetLinkID(link)

	local craftedName, professionName, professionRequiredSkill
	if itemClass == RECIPE then
		-- gather recipe information
		for line = 1, self:NumLines() do
			local left = _G[self:GetName() .. "TextLeft"..line]:GetText()
			if left and left ~= "" then
				if not craftedName then
					craftedName = left:match("^\n(.+)")
				end

				if not professionName then
					local profession, requiredSkill = left:match(PROFESSION_MIN_SKILL)
					if profession and requiredSkill then
						professionName = profession
						professionRequiredSkill = tonumber(requiredSkill)
					end
				end

				if craftedName and professionName then break end
			end
		end

		if not professionName then
			professionName = tradeskills[subclass] and GetSpellInfo(tradeskills[subclass]) or subclass
		end
	elseif itemClass == GLYPH then
		professionName = GetSpellInfo(tradeskills['Inscription'])
		craftedName = name
	end

	if not self.twinkleDone and craftedName then
		-- show info of crafted item
		name = craftedName
		_, link = GetItemInfo(name)
		itemID = link and ns.GetLinkID(link)
	end

	local linesAdded = nil
	AddEmptyLine(self, true)

	if (equipSlot ~= "" and equipSlot ~= "INVTYPE_BAG") or (quality >= 3 and itemClass == MISC) then
		-- crafted items don't need source info - their source is the currently viewed recipe
		linesAdded = AddItemSources(self, itemID or name)
	elseif itemClass == GLYPH or (itemClass == RECIPE and not self.twinkleDone) then
		-- glyphs can be shown on recipes, too
		linesAdded = AddGlyphInfo(self, itemID or name)
	elseif itemClass == RECIPE and self.twinkleDone then
		-- only print crafting recipe info on second run
		linesAdded = AddCraftInfo(self, professionName, craftedName, professionRequiredSkill)
	end
	if linesAdded then AddEmptyLine(self, true) end

	if itemID and itemID ~= HEARTHSTONE_ITEM_ID then
		local itemCountsOnSHIFT = nil -- TODO: config
		if not itemCountsOnSHIFT or IsShiftKeyDown() then
			linesAdded = AddItemCounts(self, itemID)
			if linesAdded then AddEmptyLine(self, true) end
		else
			self:AddLine(BATTLENET_FONT_COLOR_CODE..'<Hold down SHIFT for item counts>')
		end
	end

	self.twinkleDone = true
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

	self:Show()
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
			-- print('SetHyperlink', hyperlink, linkType, id)
			if linkType == "quest" then
				-- would use OnTooltipSetQuest but doesn't supply id
				local linesAdded = nil
				AddEmptyLine(self, true)

				linesAdded = AddOnQuestInfo(self, id)
				if linesAdded then AddEmptyLine(self, true) end
			else
				-- print('SetHyperlink', hyperlink)
			end
			self:Show()
		end)

		-- GameTooltip:HookScript("OnTooltipSetSpell", HandleTooltipSpell)
		-- GameTooltip:HookScript("OnTooltipSetAchievement", function(self) end) -- list max progress char/char completion states
		-- GameTooltip:HookScript("OnTooltipSetEquipmentSet", function(self) end) -- ??

		hooksecurefunc(GameTooltip, "SetGlyphByID", function(self, glyphID)
			-- shown when hovering a glyph in the talent ui
			local professionName = GetSpellInfo(tradeskills['Inscription'])
			local craftedName = _G[self:GetName().."TextLeft1"]:GetText()
			AddCraftInfo(self, professionName, craftedName)
			self:Show()
		end)
		hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, currencyID)
			AddCurrencyInfo(self, currencyID)
			self:Show()
		end)
		hooksecurefunc(GameTooltip, "SetCurrencyToken", function(self, index)
			local currencyID = ns.GetLinkID( GetCurrencyListLink(index) )
			AddCurrencyInfo(self, currencyID)
			self:Show()
		end)

		ns.UnregisterEvent('ADDON_LOADED', 'tooltip_init')
	end
end, 'tooltip_init')
