local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, ItemRefTooltip, GameTooltip, TRADESKILLS, FACTION_BAR_COLORS, TABARDVENDORCOST, UNKNOWN, ITEM_SPELL_KNOWN, RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, BATTLENET_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE, BATTLENET_FRIEND, DECLENSION_SET, ERR_IGNORE_ALREADY_S, AUCTIONS, TOTAL, MAIL_LABEL, BAGSLOT, ERR_QUEST_PUSH_ONQUEST_S, MINIMAP_TRACKING_BANKER, VOID_STORAGE, GUILD_BANK, STAT_AVERAGE_ITEM_LEVEL_EQUIPPED, HEARTHSTONE_ITEM_ID
-- GLOBALS: IsAddOnLoaded, IsShiftKeyDown, LoadAddOn, EJ_ClearSearch, EJ_SetSearch, EJ_GetNumSearchResults, EncounterJournal_GetSearchDisplay, GetItemInfo, GetSpellInfo, IsIgnored
-- GLOBALS: string, pairs, tonumber, table, type, wipe, tContains, ipairs, strtrim, hooksecurefunc

local plugin = addon:NewModule('Tooltip')
local LPT = LibStub('LibPeriodicTable-3.1', true)
local PROFESSION_MIN_SKILL = '^' .. addon.GlobalStringToPattern(_G.ITEM_MIN_SKILL) .. '$'
local WEAPON, ARMOR, BAG, CONSUMABLE, GLYPH, TRADESKILL, RECIPE, GEM, MISC, QUEST, BATTLEPET = _G.AUCTION_CATEGORY_WEAPONS, _G.AUCTION_CATEGORY_ARMOR, _G.AUCTION_CATEGORY_CONTAINERS, _G.AUCTION_CATEGORY_CONSUMABLES, _G.AUCTION_CATEGORY_GLYPHS, _G.AUCTION_CATEGORY_TRADE_GOODS, _G.AUCTION_CATEGORY_RECIPES, _G.AUCTION_CATEGORY_GEMS, _G.AUCTION_CATEGORY_MISCELLANEOUS, _G.AUCTION_CATEGORY_QUEST_ITEMS, _G.AUCTION_CATEGORY_BATTLE_PETS
local PLUNDER = GetItemSubClassInfo(_G.LE_ITEM_CLASS_MISCELLANEOUS, 1)
local REAGENT = GetItemSubClassInfo(_G.LE_ITEM_CLASS_MISCELLANEOUS, 2)
local PET     = GetItemSubClassInfo(_G.LE_ITEM_CLASS_MISCELLANEOUS, 3)
local HOLIDAY = GetItemSubClassInfo(_G.LE_ITEM_CLASS_MISCELLANEOUS, 4)
local OTHER   = GetItemSubClassInfo(_G.LE_ITEM_CLASS_MISCELLANEOUS, 5)
local MOUNT   = GetItemSubClassInfo(_G.LE_ITEM_CLASS_MISCELLANEOUS, 6)

function addon.AddEmptyLine(tooltip, slim, force)
	local tipName, numLines = tooltip:GetName(), tooltip:NumLines()
	local lastLeft = _G[tipName..'TextLeft'..numLines]
	      lastLeft = string.trim(lastLeft and lastLeft:GetText() or '')
	local lastRight = _G[tipName..'TextRight'..numLines]
	      lastRight = string.trim(lastRight and lastRight:GetText() or '')
	if force or lastLeft ~= '' or lastRight ~= '' then
		-- don't create multiple blank lines
		tooltip:AddLine(' ')
		numLines = numLines + 1
	end
	local left = _G[tooltip:GetName()..'TextLeft'..numLines]
	if slim and left then
		left:SetText(nil)
	end
end

-- ================================================
--  Handlers
-- ================================================
local function ClearTooltipItem(self)
	self.twinkleDone = nil
end

-- TODO: single-character pets+mounts / mounts learned by items (e.g. cloud serpent)
local function HandleTooltipItem(self, link)
	link = link or select(2, self:GetItem())
	if not link then return end
	local name, _, quality, iLevel, reqLevel, itemClass, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link)
	local itemID = addon.GetLinkID(link)

	local craftedName, professionName, professionRequiredSkill
	if itemClass == RECIPE then
		-- gather recipe information
		for line = 1, self:NumLines() do
			local left = _G[self:GetName() .. 'TextLeft'..line]:GetText()
			if left and left ~= '' then
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
			professionName = addon.GetProfessionName(itemClass, subClass)
		end
	elseif itemClass == GLYPH then
		professionName = addon.GetProfessionName('Inscription')
		craftedName = name
	end

	if itemClass == RECIPE and not craftedName then
		-- recipe does not seem to create an item
		craftedName = name:match('^[^:]+: (.+)$')
		self.twinkleDone = true
	elseif itemClass == RECIPE and not self.twinkleDone then
		-- show info of crafted item
		_, link = GetItemInfo(name)
		if link then
			itemID = addon.GetLinkID(link) or itemID
			name = craftedName
		end
	end

	local linesAdded = nil
	-- addon.AddEmptyLine(self, true)

	local isEquipment = IsEquippableItem(link) and equipSlot ~= 'INVTYPE_BAG'
	local isEquipmentToken = not isEquipment and (quality and quality >= 3) and itemClass == MISC and subClass == PLUNDER
	-- local isEquipmentToken = not isEquipment and not IsHelpfulItem(link) and not IsHarmfulItem(link)
	if isEquipment or isEquipmentToken then
		-- crafted items don't need source info - their source is the currently viewed recipe
		linesAdded = addon.AddItemSources(self, itemID or name, link)
	elseif itemClass == GLYPH or (itemClass == RECIPE and not self.twinkleDone) then
		-- glyphs can be shown on recipes, too
		linesAdded = addon.AddGlyphInfo(self, itemID or name)
	elseif itemClass == RECIPE and self.twinkleDone then
		-- only print crafting recipe info on second run
		linesAdded = addon.AddCraftInfo(self, professionName, craftedName, professionRequiredSkill)
	end
	-- if linesAdded then addon.AddEmptyLine(self, true) end

	if itemID and itemID ~= HEARTHSTONE_ITEM_ID and (itemClass ~= RECIPE or self.twinkleDone) then
		if not plugin.db.global.itemCounts.onSHIFT or IsShiftKeyDown() then
			linesAdded = addon.AddItemCounts(self, itemID)
			-- if linesAdded then addon.AddEmptyLine(self, true) end
		else
			self:AddLine(BATTLENET_FONT_COLOR_CODE..'<Hold down SHIFT for item counts>')
		end
	end

	self.twinkleDone = true
	self:Show()
end

local function HandleTradeSkillReagent(self, recipeID, reagentIndex)
	local itemLink = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex)
	HandleTooltipItem(self, itemLink)
end

local function HandleTooltipSpell(self)
	local spellName, _, spellID = self:GetSpell()
	local title = _G[self:GetName().."TextLeft1"]:GetText()

	if spellID and title ~= spellName then
		local craftedItem, profession
		-- check LPT first, it's more accurate and has more info
		if LPT then
			craftedItem, profession = LPT:ItemInSet(-1*spellID, 'Tradeskill.RecipeLinks')
			craftedItem = craftedItem and tonumber(craftedItem)
			profession  = profession  and string.match(profession, 'Tradeskill%.RecipeLinks%.([^.]+)')
			profession  = profession  and addon.GetProfessionName(profession)
		end

		-- try without LPT
		if not profession then
			profession = title:match("(.-): "..spellName)
			if not profession then return end
			local _, itemLink = GetItemInfo(spellName)
			craftedItem = itemLink and ( addon.GetLinkID(itemLink) )
		end

		if profession == addon.GetProfessionName('Inscription') then
			-- spell might create a glyph. tell us who knows it
			-- addon.AddEmptyLine(self, true)
			local isGlyph = addon.AddGlyphInfo(self, spellName)
		end

		if craftedItem then
			-- addon.AddEmptyLine(self, true)
			if not plugin.db.global.itemCounts.onSHIFT or IsShiftKeyDown() then
				addon.AddItemCounts(self, craftedItem)
			else
				self:AddLine(BATTLENET_FONT_COLOR_CODE..'<Hold down SHIFT for item counts>')
			end
			-- addon.AddEmptyLine(self, true)
		end

		-- displayed spell is a craft we know
		addon.AddCraftInfo(self, profession, spellName)
		self:Show()
	end
end

local function HandleTooltipHyperlink(self, hyperlink)
	local id, linkType = addon.GetLinkID(hyperlink)
	-- print('SetHyperlink', hyperlink, linkType, id)
	if linkType == 'quest' then
		-- would use OnTooltipSetQuest but that doesn't supply id
		addon.AddOnQuestInfo(self, id)
	elseif linkType == 'achievement' then
		-- TODO: FIXME: conflicts with TipTacItemRef
		addon.AddAchievementInfo(self, id)
	elseif linkType == 'currency' then
		addon.AddCurrencyInfo(self, id)
	else
		-- print('SetHyperlink', hyperlink)
	end
	self:Show()
end

-- ================================================
--  Events
-- ================================================
-- GLOBALS: GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3
local defaults = {
	global = {
		itemCounts = {
			onSHIFT = false,
			showTotals = true,
			showGuilds = true,
			includeGuildCountInTotal = true,
			onlyThisCharOnBOP = true,
			-- onlyCurrentFaction = false, -- TODO
		},
	},
}

local function OnTooltipSetQuestItem(self, itemType, index)
	local link = GetQuestItemLink(itemType, index)
	HandleTooltipItem(self, link)
end

local function OnTooltipSetQuestLogItem(self, itemType, index)
	local link = GetQuestLogItemLink(itemType, index)
	HandleTooltipItem(self, link)
end

local function HookTooltip(tooltip)
	if not tooltip then return end
	if tooltip:GetScript('OnTooltipCleared') then
		tooltip:HookScript('OnTooltipCleared', ClearTooltipItem)
	end
	if tooltip:GetScript('OnTooltipSetItem') then
		tooltip:HookScript('OnTooltipSetItem', HandleTooltipItem)
	end
	if tooltip:GetScript('OnTooltipSetUnit') then
		tooltip:HookScript('OnTooltipSetUnit', addon.AddSocialInfo)
	end
	if tooltip:GetScript('OnTooltipSetSpell') then
		tooltip:HookScript('OnTooltipSetSpell', HandleTooltipSpell)
	end
	-- tooltip:HookScript('OnTooltipSetEquipmentSet', function(self) end) -- ??

	if tooltip.SetRecipeReagentItem then hooksecurefunc(tooltip, 'SetRecipeReagentItem', HandleTradeSkillReagent) end
	if tooltip.SetHyperlink then hooksecurefunc(tooltip, 'SetHyperlink', HandleTooltipHyperlink) end
	-- if tooltip.SetItemByID then hooksecurefunc(tooltip, 'SetItemByID', HandleTooltipItem) end
	if tooltip.SetQuestLogItem then hooksecurefunc(tooltip, 'SetQuestLogItem', OnTooltipSetQuestLogItem) end
	if tooltip.SetQuestItem then hooksecurefunc(tooltip, 'SetQuestItem', OnTooltipSetQuestItem) end
end

function plugin:OnEnable()
	self.db = addon.db:RegisterNamespace('Tooltip', defaults)

	HookTooltip(GameTooltip)
	HookTooltip(ItemRefTooltip)
	HookTooltip(ShoppingTooltip1)
	HookTooltip(ShoppingTooltip2)

	local extraTips = {}
	hooksecurefunc('EmbeddedItemTooltip_SetItemByID', function(self, id)
		if extraTips[self.Tooltip] then return end
		HookTooltip(self.Tooltip)
		extraTips[self.Tooltip] = true
		EmbeddedItemTooltip_SetItemByID(self, id)
	end)

	--[[ hooksecurefunc(GameTooltip, 'SetGlyphByID', function(tooltip, glyphID)
		-- shown when hovering a glyph in the talent ui
		local professionName = addon.GetProfessionName('Inscription')
		local craftedName = _G[tooltip:GetName()..'TextLeft1']:GetText()
		addon.AddCraftInfo(tooltip, professionName, craftedName)
		tooltip:Show()
	end) --]]
	hooksecurefunc(GameTooltip, 'SetCurrencyByID', function(tooltip, currencyID)
		addon.AddCurrencyInfo(tooltip, currencyID)
		tooltip:Show()
	end)
	hooksecurefunc(GameTooltip, 'SetCurrencyToken', function(tooltip, index)
		local currencyLink = GetCurrencyListLink(index)
		local currencyID = addon.GetLinkID(currencyLink)
		addon.AddCurrencyInfo(tooltip, currencyID)
		tooltip:Show()
	end)
	hooksecurefunc('SetTooltipMoney', function(tooltip, money, type, prefix, suffix)
		-- we add a marker for money frames as their texts are all empty
		_G[tooltip:GetName()..'TextRight'..tooltip:NumLines()]:SetText('*')
	end)

	-- TODO: does not trigger on zone quest lists
	hooksecurefunc('QuestMapLogTitleButton_OnEnter', function(self)
		local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(self.questLogIndex)
		local tooltip = GameTooltip
		if not isHeader and questID and tooltip:IsShown() then
			addon.AddOnQuestInfo(tooltip, questID)
			tooltip:Show()
		end
	end)
end


--[[
-- speciesId, petGUID = C_PetJournal.FindPetIDByName("petName")
-- numCollected, limit = C_PetJournal.GetNumCollectedInfo(speciesId)

local function AddPetOwners(companionSpellID, companionType, tooltip)
	local know = {}				-- list of alts who know this pet
	local couldLearn = {}		-- list of alts who could learn it

	for characterName, character in pairs(DataStore:GetCharacters()) do
		if DataStore:IsPetKnown(character, companionType, companionSpellID) then
			table.insert(know, characterName)
		else
			table.insert(couldLearn, characterName)
		end
	end

	if #know > 0 then
		tooltip:AddLine(TEAL .. L["Already known by "] ..": ".. WHITE.. table.concat(know, ", "), 1, 1, 1, 1);
	end

	if #couldLearn > 0 then
		tooltip:AddLine(YELLOW .. L["Could be learned by "] ..": ".. WHITE.. table.concat(couldLearn, ", "), 1, 1, 1, 1);
	end
end
--]]
