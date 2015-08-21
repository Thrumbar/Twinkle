local addonName, addon, _ = ...

local data = addon:NewModule('data', 'AceEvent-3.0')
addon.data = data

-- GLOBALS: _G, Twinkle, DataStore, BANK_CONTAINER, BATTLENET_FONT_COLOR_CODE, NUM_BAG_SLOTS
-- GLOBALS: GetRealmName, UnitName, UnitFullName, UnitRace, UnitClass, UnitLevel, UnitFactionGroup, UnitXP, UnitXPMax, GetXPExhaustion, GetItemInfo, GetNumClasses, GetClassInfo, GetMoney, GetZoneText, GetSubZoneText, GetAverageItemLevel, GetNumUnspentTalents, GetInventoryItemLink, GetActiveSpecGroup, GetContainerItemInfo, GetGuildInfo, IsResting, GetVoidItemInfo, GetCurrencyListSize, GetCurrencyListInfo, GetCurrencyInfo
-- GLOBALS: string, math, table, wipe, pairs, select, type, tonumber, setmetatable, rawget, rawset, strjoin, strsplit

local LibRealmInfo = LibStub('LibRealmInfo')
local emptyTable   = {}

local realms = {}
function data.GetAllCharacters(useTable, ...)
	wipe(realms)
	if ... then
		for i = 1, select('#', ...) do
			local realm = select(i, ...)
			local _, _, _, _, _, _, _, _, connected = LibRealmInfo:GetRealmInfo(realm)
			for _, realmID in pairs(connected or emptyTable) do
				realms[ (LibRealmInfo:GetRealmInfo(realmID)) ] = true
			end
			realms[realm] = true
		end
	end
	local allRealms = not next(realms)

	if useTable then wipe(useTable) else useTable = {} end
	for account in pairs(DataStore:GetAccounts() or emptyTable) do
		for realm in pairs(DataStore:GetRealms(account) or emptyTable) do
			if allRealms or realms[realm] then
				for _, characterKey in pairs(DataStore:GetCharacters(realm, account) or emptyTable) do
					table.insert(useTable, characterKey)
				end
			end
		end
	end
	table.sort(useTable)
	return useTable
end

local listRealms = {}
function data.GetCharacters(useTable)
	if useTable then wipe(useTable) else useTable = {} end
	local characters = data.GetAllCharacters(useTable) -- , unpack(listRealms))
	if addon.db then
		for i = #characters, 1, -1 do
			local characterKey = characters[i]
			local account, realm, character = strsplit('.', characterKey)
			local faction = data.GetCharacterFaction(characterKey)
			local level   = data.GetLevel(characterKey)
			level = level == MAX_PLAYER_LEVEL and 'maxLevel' or 'leveling'

			if not addon.db.profile.characterFilters.Account[account]
				or not addon.db.profile.characterFilters.Realm[realm]
				or not addon.db.profile.characterFilters.Faction[faction]
				or not addon.db.profile.characterFilters.Level[level] then
				tremove(characters, i)
			end
		end
	end
	table.sort(useTable)
	return characters
end

local thisCharacter = DataStore:GetCharacter() or UnitFullName('player')
local allCharacters = data.GetAllCharacters()

function data.CharacterFilters(filterOptions)
	filterOptions.Realm = DataStore:GetRealms()
	for realm in pairs(filterOptions.Realm) do filterOptions.Realm[realm] = realm end
	filterOptions.Account = DataStore:GetAccounts()
	for account in pairs(filterOptions.Account) do filterOptions.Account[account] = account end
	return filterOptions
end

function data.GetCurrentCharacter()
	return thisCharacter
end

function data.IsCharacter(key)
	if tContains(allCharacters, key) then
		return true
	end
end

function data.DeleteCharacter(key)
	if not key then return end
	local account, realm, character = strsplit('.', key)
	if not account or not realm or not character then return end
	local guildName = DataStore.db.global.Characters[key].guildName
	DataStore:DeleteCharacter(character, realm, account)

	if guildName then
		for characterKey, data in pairs(DataStore.db.global.Characters) do
			local _, charRealm = strsplit('.', characterKey)
			if charRealm == realm and data.guildName == guildName then
				guildName = nil
				break
			end
		end
		-- no more characters in this guild
		if guildName then
			DataStore:DeleteGuild(guildName, realm, account)
			Twinkle:SendMessage('TWINKLE_GUILD_DELETED', key)
		end
	end
	Twinkle:SendMessage('TWINKLE_CHARACTER_DELETED', key)
end

-- ========================================
--  General Information
-- ========================================
function data.GetName(characterKey)
	if characterKey == thisCharacter then
		local characterName = UnitName('player')
		return characterName
	else
		return DataStore:GetCharacterName(characterKey) or characterKey
	end
end
function data.GetFullName(characterKey)
	if characterKey == thisCharacter then
		local fullName = strjoin('-', UnitFullName('player'))
	else
		local account, realm, characterKey = strsplit('.', characterKey)
		return characterKey..'-'..string.gsub(realm, ' ', '')
	end
end
function data.GetRealm(characterKey)
	if characterKey == thisCharacter then
		return GetRealmName()
	else
		local account, realm, characterKey = strsplit('.', characterKey)
		return realm
	end
end
function data.GetCharacterText(characterKey)
	if characterKey == thisCharacter then
		local characterName = UnitName('player')
		local _, className = UnitClass('player')
		return string.format('|c%s%s|r', _G.RAID_CLASS_COLORS[className].colorStr, characterName)
	else
		local characterName = DataStore:GetColoredCharacterName(characterKey)
		return characterName and characterName..'|r' or data.GetName(characterKey)
	end
end
function data.GetCharacterFaction(characterKey)
	local faction
	if characterKey == thisCharacter then
		faction = UnitFactionGroup('player')
	else
		faction = DataStore:GetCharacterFaction(characterKey)
	end
	return faction
end
function data.GetRace(characterKey)
	if characterKey == thisCharacter then
		local raceLocale, raceFileName = UnitRace('player')
		return raceLocale, raceFileName
	else
		local raceLocale, raceFileName = DataStore:GetCharacterRace(characterKey)
		return raceLocale, raceFileName
	end
end

local function GetClassID(class)
	for i = 1, GetNumClasses() do
		local className, classTag, classID = GetClassInfo(i)
		if classTag == class then
			return classID
		end
	end
end
function data.GetClass(characterKey)
	if characterKey == thisCharacter then
		local classLocale, className, classID = UnitClass('player')
		return classLocale, className, classID
	else
		local classLocale, className = DataStore:GetCharacterClass(characterKey)
		local classID = className and GetClassID(className) or nil
		return classLocale, className, classID
	end
end
function data.GetLevel(characterKey)
	if characterKey == thisCharacter then
		return UnitLevel('player')
	else
		return DataStore:GetCharacterLevel(characterKey) or 0
	end
end
function data.GetMoney(characterKey)
	if characterKey == thisCharacter then
		return GetMoney()
	else
		return DataStore:GetMoney(characterKey) or 0
	end
end
function data.GetAverageItemLevel(characterKey)
	if characterKey == thisCharacter then
		local total, equipped = GetAverageItemLevel()
		return math.floor(total)
	else
		local equipped, total = DataStore:GetAverageItemLevel(characterKey)
		return math.floor(total or 0)
	end
end
function data.GetXPInfo(characterKey)
	local levelProgress, restedRate
	if characterKey == thisCharacter then
		local restedXP = GetXPExhaustion() or 0 -- 475500
		local currentXP, maxXP = UnitXP('player'), UnitXPMax('player')
		levelProgress = math.floor(currentXP/maxXP * 100 + 0.5)
		restedRate = restedXP / maxXP / 1.5 * 100
	else
		-- also available: GetXP, GetXPMax, GetRestXP
		levelProgress = DataStore:GetXPRate(characterKey) or 0
		restedRate  = DataStore:GetRestXPRate(characterKey) or 0
	end

	if restedRate and restedRate > 0 then
		return string.format('%d%% (+%d%%)', levelProgress, restedRate*1.5)
	else
		return string.format('%d%%', levelProgress)
	end
end
function data.GetLocation(characterKey)
	if characterKey == thisCharacter then
		local zone, subZone = GetZoneText(), GetSubZoneText()
		local isResting = IsResting()
		return zone, isResting
	else
		local zone, subZone = DataStore:GetLocation(characterKey)
		local isResting = DataStore:IsResting(characterKey) or false
		return zone or '', isResting
	end
end
function data.GetAuctionState(characterKey)
	local auctions, bids = DataStore:GetNumAuctions(characterKey), DataStore:GetNumBids(characterKey)
	local lastVisit = DataStore:GetAuctionHouseLastVisit(characterKey)
	return auctions or 0, bids or 0, lastVisit or 0
end
function data.GetAuctionInfo(characterKey, list, index)
	-- TODO: FIXME: this is probably outdated with WoD
	if list == 'owner' then list = 'Auctions'
	elseif list == 'bidder' then list = 'Bids' end

	-- isGoblin, itemID, count, name, bidPrice, buyoutPrice, timeLeft
	return DataStore:GetAuctionHouseItemInfo(characterKey, list, index)
end
function data.GetNumMails(characterKey, expiresInDays)
	-- returns the number of item attachments in mails
	local numMails = DataStore:GetNumMails(characterKey) or 0
	local numExpired = DataStore:GetNumExpiredMails(characterKey, expiresInDays or 7) or 0
	return numMails, numExpired
end
function data.GetMailInfo(characterKey, index)
	local _, expires = DataStore:GetMailExpiry(characterKey, index)
	local sender     = DataStore:GetMailSender(characterKey, index)
	return sender, expires, DataStore:GetMailInfo(characterKey, index)
end
function data.GetGuild(characterKey)
	local guildName = data.GetGuildInfo(characterKey)
	local charAccount, charRealm = strsplit('.', characterKey)
	return DataStore:GetGuild(guildName, charRealm, charAccount)
end
function data.GetGuildInfo(characterKey)
	if characterKey == thisCharacter then
		local guildName, guildRank, rankID, _ = GetGuildInfo('player')
		return guildName, guildRank, rankID
	else
		local guildName, guildRank, rankID = DataStore:GetGuildInfo(characterKey)
		return guildName, guildRank, rankID
	end
end
function data.GetNumUnspentTalents(characterKey)
	local primary   = DataStore:GetNumUnspentTalents(characterKey, 1) or 0
	local secondary = DataStore:GetNumUnspentTalents(characterKey, 2) or 0
	if characterKey == thisCharacter then
		local active = GetActiveSpecGroup()
		if active == 1 then primary = GetNumUnspentTalents() else secondary = GetNumUnspentTalents() end
	end
	return primary or 0, secondary or 0
end
-- ========================================
--  Containers & Inventory
-- ========================================
local itemCountCache = setmetatable({}, {
	__mode = 'kv',
	__index = function(self, itemID)
		local itemTable = {}
		setmetatable(itemTable, {
			__mode = 'kv',
			__index = function(self, key)
				local info
				if data.IsCharacter(key) then
					info = {}
					info[1], info[2], info[3], info[7] = DataStore:GetContainerItemCount(key, itemID)
					info[4] = DataStore:GetAuctionHouseItemCount(key, itemID)
					info[5] = DataStore:GetInventoryItemCount(key, itemID)
					info[6] = DataStore:GetMailItemCount(key, itemID) or 0
				else
					-- this key identifies a guild
					info = DataStore:GetGuildBankItemCount(key, itemID)
				end

				self[key] = info
				return info
			end
		})
		self[itemID] = itemTable
		return itemTable
	end
})

local function ClearCacheItemCount(itemID, characterKey)
	-- remove previously cached data
	local itemData = rawget(itemCountCache, itemID)
	if itemData then
		if characterKey then
			-- clear data for this key
			if rawget(itemData, characterKey) then
				rawset(itemData, characterKey, nil)
			end
		else
			-- clear data for all keys
			for k, v in pairs(itemData) do
				rawset(itemData, k, nil)
			end
		end
	end
end

local function ClearCache(characterKey)
	local charData
	for itemID, data in pairs(itemCountCache) do
		charData = rawget(data, characterKey)
		if charData then
			wipe(charData)
			rawset(data, characterKey, nil)
		end
	end
end

--[[-- gets handled by BAG_UPDATE_DELAYED handler
data:RegisterEvent('CHAT_MSG_LOOT', function(self, event, message)
	local id, linkType = Twinkle.GetLinkID(message)
	if id and linkType == 'item' then
		ClearCacheItemCount(id, thisCharacter)
	end
end) --]]
data:RegisterEvent('BAG_UPDATE_DELAYED', function(self, event)
	ClearCache(thisCharacter)
end)
data:RegisterEvent('REAGENTBANK_UPDATE', function()
	ClearCache(thisCharacter)
end)

function data.GetItemCounts(key, itemID, uncached)
	if uncached then
		ClearCacheItemCount(itemID, key)
	end
	-- automagically fills cache
	return itemCountCache[itemID][key]
end
local guildCounts = {}
function data.GetGuildsItemCounts(itemID, uncached)
	wipe(guildCounts)
	for guild, identifier in pairs(DataStore:GetGuilds() or emptyTable) do
		-- DataStore:GetGuildFaction(guild) == 'Horde' and
		local guildText = string.format('%s%s|r', BATTLENET_FONT_COLOR_CODE,  guild)
		local count = data.GetItemCounts(identifier, itemID)
		if count > 0 then
			guildCounts[ guildText ] = count
		end
	end
	return guildCounts
end
function data.GetInventoryItemLink(characterKey, slotID, rawOnly)
	local item, _
	if characterKey == thisCharacter and slotID <= _G.BANK_CONTAINER_INVENTORY_OFFSET then
		-- bank containers is only available when at the bank, use stored data
		item = GetInventoryItemLink('player', slotID)
	elseif slotID >= _G.INVSLOT_FIRST_EQUIPPED and slotID <= _G.INVSLOT_LAST_EQUIPPED then
		-- equipment is saved in DataStore_Inventory
		item = DataStore:GetInventoryItem(characterKey, slotID)
		if item and type(item) == 'number' and not rawOnly then
			_, item = GetItemInfo(item)
		end
	else
		-- DataStore saves equipped bags within its Containers module
		_, _, item = data.GetContainerInfo(characterKey, slotID)
	end
	item = item and select(2, GetItemInfo(item))
	return item
end

-- map containers to DataStore internal names
local LibItemLocations = LibStub('LibItemLocations', true) -- provides globals
local containerNames = {
	[0] = 'Bag0', -- backpack (bags main)
	[BANK_CONTAINER]        = 'Bag100', -- bank (bank main)
	[KEYRING_CONTAINER]     = 'Bag-2', -- keyring (unused)
	[REAGENTBANK_CONTAINER] = 'Bag-3', -- reagents (reagent bank main)
	[VOIDSTORAGE_CONTAINER] = 'VoidStorage',
	['VoidStorage1']        = 'VoidStorage.Tab1',
	['VoidStorage2']        = 'VoidStorage.Tab2',
	-- ['GuildBank1'] for guild bank tab 1
}
for i = 1, _G.NUM_BAG_SLOTS do -- bags
	containerNames[i] = 'Bag'..i
end
for i = 1, _G.NUM_BANKBAGSLOTS do -- bank bags
	local bagIndex = _G.NUM_BAG_SLOTS + i
	containerNames[bagIndex] = 'Bag'..bagIndex
	-- also map inventory ids
	containerNames[_G.BANK_CONTAINER_INVENTORY_OFFSET + _G.NUM_BANKGENERIC_SLOTS + i] = 'Bag'..bagIndex
end

local function GetGuildBankContainer(characterKey, container)
	local tab = container:match('^GuildBank(%d+)')
	      tab = tab and tonumber(tab)
	local guildKey = data.GetGuild(characterKey)
	return DataStore:GetGuildBankTab(guildKey, tab)
end

-- @returns <int:containerSize>, <int:numFreeSlots>, <string:itemLink>, <string:translatedTypeLabel>
function data.GetContainerInfo(characterKey, container)
	if type(container) == 'string' and container:find('^GuildBank') then
		local tab = GetGuildBankContainer(characterKey, container)
		local numFreeSlots = tab and tab.size and (tab.size - #tab.ids)
		-- we have MAX_GUILDBANK_SLOTS_PER_TAB slots, but if DS doesn't know them, we can't display anything anyways
		return tab and tab.size or 0, numFreeSlots or 0, nil, nil
	else
		local containerName = containerNames[container] or container or ''
		local _, containerLink, numSlots, numFreeSlots, bagTypeLabel = DataStore:GetContainerInfo(characterKey, containerName)
		return numSlots or 0, numFreeSlots or 0, containerLink, bagTypeLabel
	end
end

-- @returns nil or <int:itemID>, <string:itemLink>, <int:itemCount>
function data.GetContainerSlotInfo(characterKey, bag, slot)
	local container
	if bag and type(bag) == 'string' and bag:find('^GuildBank') then
		container = GetGuildBankContainer(characterKey, bag)
	elseif characterKey == thisCharacter then
		-- get live data for logged in character where possible
		if (''..bag):find('VoidStorage') then
			local tab = 1*(bag:match('%d+') or 1)
			local itemID = GetVoidItemInfo(tab, slot), nil
			if itemID then
				local _, itemLink = GetItemInfo(itemID)
				return itemID, itemLink, 1
			end
		elseif type(bag) == 'number' and bag ~= BANK_CONTAINER and bag <= NUM_BAG_SLOTS then
			-- note: bank and bank bags are not readily available, use db for those
			local _, count, _, _, _, _, itemLink = GetContainerItemInfo(bag, slot)
			local itemID = itemLink and Twinkle.GetLinkID(itemLink) or nil
			return itemID, itemLink, count
		end
	end

	container = container or DataStore:GetContainer(characterKey, containerNames[bag] or bag or '')
	if container then
		return DataStore:GetSlotInfo(container, slot)
	end
end

-- ========================================
--  Equipment Sets
-- ========================================
function data.GetEquipmentSets(characterKey, useTable)
	return DataStore:GetEquipmentSetNames(characterKey) or emptyTable
end

function data.GetEquipmentSet(characterKey, setName)
	local name, icon, items = DataStore:GetEquipmentSet(characterKey, setName)
	return name or _G.UNKNOWN, icon or 'Interface\\Icons\\Inv_misc_questionmark', items
end

function data.GetEquipmentSetItems(characterKey, setName)
	return DataStore:GetEquipmentSetItems(characterKey, setName) or emptyTable
end

-- ========================================
--  Currencies
-- ========================================
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
	 821, -- Draenor Clans Archaeology Fragment
	 823, -- Apexis Crystal
	 824, -- Garrison Resources
	 828, -- Ogre Archaeology Fragment
	 829, -- Arakkoa Archaeology Fragment
	 910, -- Secret of Draenor Alchemy
	 944, -- Artifact Fragment
	 980, -- Dingy Iron Coins
	 994, -- Seal of Tempered Fate
	 999, -- Secret of Draenor Tailoring
	1008, -- Secret of Draenor Jewelcrafting
	1017, -- Secret of Draenor Leatherworking
	1020, -- Secret of Draenor Blacksmithing
}
for index, currencyID in ipairs(currencyIDs) do
	local currencyName = GetCurrencyInfo(currencyID)
	currencyIDs[currencyName] = currencyID
	currencyIDs[index] = nil
end

function data.GetNumCurrencies(characterKey)
	if characterKey == thisCharacter then
		return GetCurrencyListSize()
	else
		return DataStore:GetNumCurrencies(characterKey)
	end
end

function data.GetCurrencyInfoByIndex(characterKey, index)
	local isHeader, name, count, icon, weekly
	if characterKey == thisCharacter then
		name, isHeader, _, _, _, count, icon, _, _, weekly = GetCurrencyListInfo(index)
	else
		isHeader, name, count, icon = DataStore:GetCurrencyInfo(characterKey, index)
	end
	local currencyID = not isHeader and name and currencyIDs[name]
	if currencyID then
		-- avoid duplicate code
		isHeader, name, count, icon = data.GetCurrencyInfo(characterKey, currencyID)
	end
	return isHeader, name, count, icon, weekly, currencyID
end

-- identifier may be currencyID or currencyName
function data.GetCurrencyInfo(characterKey, currencyID)
	if type(currencyID) == 'string' then currencyID = currencyIDs[currencyID] end
	if not currencyID then return end

	local name, count, icon, weekly = GetCurrencyInfo(currencyID)
	local isHeader = not name
	if characterKey ~= thisCharacter then
		local weeklyMax, totalMax
		count, weekly, weeklyMax, totalMax = DataStore:GetCurrencyTotals(characterKey, currencyID)
		if count == 0 and weekly == 0 and weeklyMax == 0 and totalMax == 0 then
			-- currency totals are only available for some currencies
			_, _, count = DataStore:GetCurrencyInfoByName(characterKey, name)
		end
	end

	if currencyID == 824 then -- garrison resource
		weekly = DataStore:GetUncollectedResources(characterKey) or 0
	-- elseif currencyID == 994 then -- seal of tempered fate
	elseif currencyID == 1129 then -- Seal of Inevitable Fate
		weekly = data.GetNumQuestsCompleted(characterKey, 36058, -- war mill/dwarven bunker
			36054, 37454, 37455, -- gold
			36056, 37456, 37457, -- garrison resource
			36057, 37458, 37459, -- honor
			36055, 37452, 37453) -- apexis
	end

	return isHeader, name, count or 0, icon, weekly
end

-- ========================================
--  Garrison
-- ========================================
function data.GetGarrisonLevel(characterKey)
	local id, rank = DataStore:GetBuildingInfo(characterKey, 'TownHall')
	return rank or 0
end

function data.GetNumFollowers(characterKey)
	return DataStore:GetNumFollowers(characterKey)
end

local followerList
function data.GetFollowers(characterKey, useTable)
	return DataStore:GetFollowers(characterKey)
end

function data.GetFollowerInfo(characterKey, garrFollowerID)
	return DataStore:GetFollowerInfo(characterKey, garrFollowerID)
end

function data.GetFollowerLink(characterKey, garrFollowerID)
	return DataStore:GetFollowerLink(characterKey, garrFollowerID)
end

-- ========================================
--  Activity
-- ========================================
function data.GetRandomLFGState(characterKey, useTable)
	useTable = useTable or {}
	wipe(useTable)

	local iterator = DataStore:IterateLFGs(characterKey, _G.TYPEID_RANDOM_DUNGEON)
	if iterator then
		for dungeonID, dungeonName, status, resetTime, numDefeated, numBosses in iterator do
			if type(status) ~= 'string' then
				table.insert(useTable, {
					id = dungeonID,
					name = dungeonName,
					complete = status
				})
			end
		end
	end
	return useTable
end

function data.GetLFRState(characterKey, useTable)
	useTable = useTable or {}
	wipe(useTable)

	local iterator = DataStore:IterateLFGs(characterKey, _G.TYPEID_DUNGEON, _G.LFG_SUBTYPEID_RAID)
	if iterator then
		for dungeonID, dungeonName, status, resetTime, numDefeated, numBosses in iterator do
			if type(status) ~= 'string' then
				table.insert(useTable, {
					id = dungeonID,
					name = dungeonName,
					killed = numDefeated,
					complete = status
				})
			end
		end
	end
	return useTable
end

function data.GetDailyQuests(characterKey, useTable)
	useTable = useTable or {}
	wipe(useTable)

	for i = 1, DataStore:GetDailiesHistorySize(characterKey) or 0 do
		local _, title = DataStore:GetDailiesHistoryInfo(characterKey, i)
		if title then
			table.insert(useTable, title)
		end
	end
	return useTable
end

function data.GetNumQuestsCompleted(characterKey, ...)
	local count = 0
	for i = 1, select('#', ...) do
		local questID = select(i, ...)
		-- TODO: does this work correctly with weekly quest resets?
		count = count + (DataStore:IsQuestCompletedBy(characterKey, questID) and 1 or 0)
	end
	return count
end

function data.GetQuestProgress(characterKey, questID)
	local hasQuest, progress = DataStore:GetQuestProgress(characterKey, questID)
	if hasQuest then
		return progress
	else
		for i = 1, DataStore:GetQuestLogSize(characterKey) or 0 do
			local isHeader, questLink, _, _, completed = DataStore:GetQuestLogInfo(characterKey, i)
			local qID = questLink and Twinkle.GetLinkID(questLink)
			if not isHeader and qID == questID and completed ~= 1 then
				return 0
			end
		end
	end
end

function data.GetNumSavedWorldBosses(characterKey)
	return DataStore:GetNumSavedWorldBosses(characterKey) or 0
end

function data.GetSavedWorldBosses(characterKey)
	return DataStore:GetSavedWorldBosses(characterKey) or emptyTable
end

function data.IsWorldBossKilledBy(characterKey, bossID)
	return DataStore:IsWorldBossKilledBy(characterKey, bossID) or false
end
