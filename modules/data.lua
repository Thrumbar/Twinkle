local addonName, addon, _ = ...

local data = addon:NewModule('data', 'AceEvent-3.0')
addon.data = data

-- GLOBALS: DataStore

local LibRealmInfo    = LibStub('LibRealmInfo')
local thisCharacter   = DataStore:GetCharacter()
local realmCharacters = DataStore:GetCharacters() -- TODO: this is bsh*t
local emptyTable      = {}

function data.GetCharacters(useTable)
	if useTable then wipe(useTable) else useTable = {} end
	--[[ for characterName, characterKey in pairs(realmCharacters) do
		table.insert(useTable, characterKey)
	end
	table.sort(useTable)
	return useTable --]]
	return data.GetAllCharacters(useTable, GetRealmName())
end

local realms = {}
function data.GetAllCharacters(useTable, realm)
	wipe(realms)
	if realm then
		local _, _, _, _, _, _, _, _, connected = LibRealmInfo:GetRealmInfoByName(realm)
		for _, realmID in pairs(connected or emptyTable) do
			realms[ (LibRealmInfo:GetRealmInfo(realmID)) ] = true
		end
	end
	realms[ realm or (GetRealmName()) ] = true

	if useTable then wipe(useTable) else useTable = {} end
	for account in pairs(DataStore:GetAccounts()) do
		for realm in pairs(DataStore:GetRealms(account)) do
			if realms[realm] then
				for _, characterKey in pairs(DataStore:GetCharacters(realm, account)) do
					table.insert(useTable, characterKey)
				end
			end
		end
	end
	table.sort(useTable)
	return useTable
end

function data.GetCurrentCharacter()
	return thisCharacter
end

function data.IsCharacter(key)
	if addon.Find(realmCharacters, key) then
		return true
	end
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
	if character == thisCharacter then
		local fullName = strjoin('-', UnitFullName('player'))
	else
		local account, realm, character = strsplit('.', characterKey)
		return character..'-'..string.gsub(realm, ' ', '')
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
function data.GetCharacterFactionIcon(characterKey)
	local faction
	if characterKey == thisCharacter then
		faction = UnitFactionGroup('player')
	else
		faction = DataStore:GetCharacterFaction(characterKey)
	end

	if faction == 'Horde' then
		return '|TInterface\\WorldStateFrame\\HordeIcon.png:22|t'    -- Interface\\PVPFrame\\PVPCurrency-Honor-Horde'
	elseif faction == 'Alliance' then
		return '|TInterface\\WorldStateFrame\\AllianceIcon.png:22|t' -- Interface\\PVPFrame\\PVPCurrency-Honor-Alliance'
	else
		return '|TInterface\\MINIMAP\\TRACKING\\BattleMaster:22|t'   -- Interface\\ICONS\\FactionChange
	end
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
		return math.floor(total + 0.5)
	else
		local equipped, total = DataStore:GetAverageItemLevel(characterKey)
		return math.floor((total or 0) + 0.5)
	end
end
function data.GetXPInfo(characterKey)
	local levelProgress, restedRate
	if characterKey == thisCharacter then
		local restedXP = GetXPExhaustion() or 0 -- 475500
		local currentXP, maxXP = UnitXP('player'), UnitXPMax('player')
		levelProgress = math.floor(currentXP/maxXP + 0.5) * 100
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
		local resting = IsResting()
		return zone, isResting
	else
		local zone, subZone = DataStore:GetLocation(characterKey)
		local isResting = DataStore:IsResting(characterKey) or false
		return zone or '', isResting
	end
end
function data.GetAuctionState(characterKey)
	local auctions, bids = DataStore:GetNumAuctions(characterKey), DataStore:GetNumBids(characterKey)
	return auctions or 0, bids or 0
end
function data.GetAuctionInfo(characterKey, list, index)
	-- TODO: FIXME: this is probably outdated with WoD
	if list == 'owner' then list = 'Auctions'
	elseif list == 'bidder' then list = 'Bids' end

	-- isGoblin, itemID, count, name, bidPrice, buyoutPrice, timeLeft
	return DataStore:GetAuctionHouseItemInfo(characterKey, list, index)
end
function data.GetNumMails(characterKey)
	-- returns the number of item attachments in mails
	return DataStore:GetNumMails(characterKey) or 0
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
	local id, linkType = addon.GetLinkID(message)
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
	for guild, identifier in pairs( DataStore:GetGuilds() ) do
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
		local numFreeSlots = tab.size and (tab.size - #tab.ids)
		-- we have MAX_GUILDBANK_SLOTS_PER_TAB slots, but if DS doesn't know them, we can't display anything anyways
		return tab.size or 0, numFreeSlots or 0, nil, nil
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
	elseif characterKey == thisCharacter and bag ~= BANK_CONTAINER then
		-- get live data for logged in character, but bank is tricky
		if (''..bag):find('VoidStorage') then
			local tab = 1*(bag:match('%d+') or 1)
			local itemID = GetVoidItemInfo(tab, slot), nil
			if itemID then
				local _, itemLink = GetItemInfo(itemID)
				return itemID, itemLink, 1
			end
		elseif type(bag) == 'number' then
			-- this works with pretty much anything :)
			local _, count, _, _, _, _, itemLink = GetContainerItemInfo(bag, slot)
			local itemID = itemLink and addon:GetLinkID(itemLink) or nil
			return itemID, itemLink, count
		end
	end

	container = container or DataStore:GetContainer(characterKey, containerNames[bag] or bag or '')
	if container then
		return DataStore:GetSlotInfo(container, slot)
	end
end

-- ========================================
--  Currencies
-- ========================================
function data.GetNumCurrencies(characterKey)
	if characterKey == thisCharacter then
		return GetCurrencyListSize()
	else
		return DataStore:GetNumCurrencies(characterKey)
	end
end

function data.GetCurrencyInfoByIndex(characterKey, index)
	if characterKey == thisCharacter then
		local name, isHeader, _, _, _, count, icon = GetCurrencyListInfo(index)
		return isHeader, name, count, icon
	else
		return DataStore:GetCurrencyInfo(characterKey, index)
	end
end

-- identifier may be currencyID or currencyName
function data.GetCurrencyInfo(characterKey, identifier)
	local count, weekly, isHeader, name, icon
	local hasData = false
	if type(identifier) == 'number' then
		name, _, icon = GetCurrencyInfo(identifier)
		local weeklyMax, totalMax
		count, weekly, weeklyMax, totalMax = DataStore:GetCurrencyTotals(characterKey, identifier)
		if count and not (count == 0 and weekly == 0 and weeklyMax == 0 and totalMax == 0) then
			hasData = true
		end

		if characterKey == thisCharacter then
			name, count, icon, weekly = GetCurrencyInfo(identifier)
			isHeader = not name
			hasData = true
		end
	end

	if not hasData then
		identifier = type(identifier) == 'number' and GetCurrencyInfo(identifier) or identifier
		for index = 1, data.GetNumCurrencies(characterKey) do
			local _isHeader, _name, _count, _icon = data.GetCurrencyInfoByIndex(characterKey, index)
			if _name == identifier then
				isHeader, name, count, icon = _isHeader, _name, _count, _icon
				break
			end
		end
	end
	return isHeader, name, count, icon, weekly
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
