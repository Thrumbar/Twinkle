local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, ItemRefTooltip, GameTooltip, TRADESKILLS, FACTION_BAR_COLORS, TABARDVENDORCOST, UNKNOWN, ITEM_SPELL_KNOWN, RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, BATTLENET_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE, BATTLENET_FRIEND, DECLENSION_SET, ERR_IGNORE_ALREADY_S, AUCTIONS, TOTAL, MAIL_LABEL, BAGSLOT, ERR_QUEST_PUSH_ONQUEST_S, MINIMAP_TRACKING_BANKER, VOID_STORAGE, GUILD_BANK, STAT_AVERAGE_ITEM_LEVEL_EQUIPPED, HEARTHSTONE_ITEM_ID
-- GLOBALS: IsAddOnLoaded, IsShiftKeyDown, LoadAddOn, EJ_ClearSearch, EJ_SetSearch, EJ_GetNumSearchResults, EncounterJournal_GetSearchDisplay, GetItemInfo, GetSpellInfo, IsIgnored
-- GLOBALS: string, pairs, tonumber, table, type, wipe, tContains, ipairs, strtrim, hooksecurefunc

local plugin = addon:NewModule('tooltip')
local LPT = LibStub('LibPeriodicTable-3.1', true)
local WEAPON, ARMOR, BAG, CONSUMABLE, GLYPH, TRADESKILL, RECIPE, GEM, MISC, QUEST, BATTLEPET = GetAuctionItemClasses()
local PROFESSION_MIN_SKILL = '^' .. addon.GlobalStringToPattern(_G.ITEM_MIN_SKILL) .. '$'

function addon.AddEmptyLine(tooltip, slim, force)
	local numLines = tooltip:NumLines()
	local lastText = _G[tooltip:GetName()..'TextLeft'..numLines]
	      lastText = lastText and lastText:GetText()
	-- don't create multiple blank lines
	if force or (lastText and lastText ~= ' ') then
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
local function HandleTooltipItem(self)
	-- avoid script running out of time
	if InCombatLockdown() then return end

	local name, link = self:GetItem()
	if not link then return end
	local _, _, quality, iLevel, reqLevel, itemClass, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link)
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
	addon.AddEmptyLine(self, true)

	if (equipSlot ~= '' and equipSlot ~= 'INVTYPE_BAG') or (quality >= 3 and itemClass == MISC) then
		-- crafted items don't need source info - their source is the currently viewed recipe
		linesAdded = addon.AddItemSources(self, itemID or name)
	elseif itemClass == GLYPH or (itemClass == RECIPE and not self.twinkleDone) then
		-- glyphs can be shown on recipes, too
		linesAdded = addon.AddGlyphInfo(self, itemID or name)
	elseif itemClass == RECIPE and self.twinkleDone then
		-- only print crafting recipe info on second run
		linesAdded = addon.AddCraftInfo(self, professionName, craftedName, professionRequiredSkill)
	end
	if linesAdded then addon.AddEmptyLine(self, true) end

	if itemID and itemID ~= HEARTHSTONE_ITEM_ID and (itemClass ~= RECIPE or self.twinkleDone) then
		local itemCountsOnSHIFT = nil -- TODO: config
		if not itemCountsOnSHIFT or IsShiftKeyDown() then
			linesAdded = addon.AddItemCounts(self, itemID)
			if linesAdded then addon.AddEmptyLine(self, true) end
		else
			self:AddLine(BATTLENET_FONT_COLOR_CODE..'<Hold down SHIFT for item counts>')
		end
	end

	self.twinkleDone = true
	self:Show()
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
			addon.AddEmptyLine(self, true)
			local isGlyph = addon.AddGlyphInfo(self, spellName)
		end

		if craftedItem then
			addon.AddEmptyLine(self, true)
			local itemCountsOnSHIFT = nil -- TODO: config
			if not itemCountsOnSHIFT or IsShiftKeyDown() then
				addon.AddItemCounts(self, craftedItem)
			else
				self:AddLine(BATTLENET_FONT_COLOR_CODE..'<Hold down SHIFT for item counts>')
			end
			addon.AddEmptyLine(self, true)
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
		local linesAdded = nil
		addon.AddEmptyLine(self, true)

		linesAdded = addon.AddOnQuestInfo(self, id)
		if linesAdded then addon.AddEmptyLine(self, true) end
	elseif linkType == 'achievement' then
		-- TODO: FIXME: conflicts with TipTacItemRef
		addon.AddAchievementInfo(self, id)
	else
		-- print('SetHyperlink', hyperlink)
	end
	self:Show()
end

-- ================================================
--  Events
-- ================================================
-- GLOBALS: GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3
function plugin.OnEnable()
	GameTooltip:HookScript('OnTooltipCleared',       ClearTooltipItem)
	GameTooltip:HookScript('OnTooltipSetItem',       HandleTooltipItem)
	GameTooltip:HookScript('OnTooltipSetUnit',       addon.AddSocialInfo)
	GameTooltip:HookScript('OnTooltipSetSpell',      HandleTooltipSpell)
	-- GameTooltip:HookScript('OnTooltipSetEquipmentSet', function(self) end) -- ??
	hooksecurefunc(GameTooltip, 'SetHyperlink',      HandleTooltipHyperlink)

	ItemRefTooltip:HookScript('OnTooltipCleared',    ClearTooltipItem)
	ItemRefTooltip:HookScript('OnTooltipSetItem',    HandleTooltipItem)
	ItemRefTooltip:HookScript('OnTooltipSetUnit',    addon.AddSocialInfo)

	if ShoppingTooltip1 then
		ShoppingTooltip1:HookScript('OnTooltipSetItem',  HandleTooltipItem)
		hooksecurefunc(ShoppingTooltip1, 'SetHyperlink', HandleTooltipHyperlink)
	end
	if ShoppingTooltip2 then
		ShoppingTooltip2:HookScript('OnTooltipSetItem',  HandleTooltipItem)
		hooksecurefunc(ShoppingTooltip2, 'SetHyperlink', HandleTooltipHyperlink)
	end
	if ShoppingTooltip3 then
		ShoppingTooltip3:HookScript('OnTooltipSetItem',  HandleTooltipItem)
		hooksecurefunc(ShoppingTooltip3, 'SetHyperlink', HandleTooltipHyperlink)
	end

	hooksecurefunc(GameTooltip, 'SetGlyphByID', function(self, glyphID)
		-- shown when hovering a glyph in the talent ui
		local professionName = addon.GetProfessionName('Inscription')
		local craftedName = _G[self:GetName()..'TextLeft1']:GetText()
		addon.AddCraftInfo(self, professionName, craftedName)
		self:Show()
	end)
	hooksecurefunc(GameTooltip, 'SetCurrencyByID', function(self, currencyID)
		addon.AddCurrencyInfo(self, currencyID)
		self:Show()
	end)
	hooksecurefunc(GameTooltip, 'SetCurrencyToken', function(self, index)
		local currencyLink = GetCurrencyListLink(index)
		local currencyID = addon.GetLinkID(currencyLink)
		addon.AddCurrencyInfo(self, currencyID)
		self:Show()
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
