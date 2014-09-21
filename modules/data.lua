local addonName, addon, _ = ...

local data = addon:NewModule('data', 'AceEvent-3.0')
addon.data = data

local LibRealmInfo    = LibStub('LibRealmInfo')
local thisCharacter   = DataStore:GetCharacter()
local realmCharacters = DataStore:GetCharacters()
local emptyTable      = {}

local gameRegion
local function GetGameRegion()
	if gameRegion then return gameRegion end
	local realmID, _
	local _, _, _, tocVersion = GetBuildInfo()
	if tocVersion >= 60000 then
		_, _, _, _, realmID = BNGetToonInfo(BNGetInfo())
	else
		_, realmID = strsplit(':', UnitGUID('player'))
	end

	local _, _, _, _, _, region = LibRealmInfo:GetRealmInfo(realmID)
	gameRegion = region or GetCVar('portal')
	-- TODO: FIXME: make sure GetCharacters gets called later ...
	return gameRegion or 'EU'
end

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
		local _, _, _, _, _, _, _, _, connected = LibRealmInfo:GetRealmInfoByName(realm, GetGameRegion())
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
		local restedXP = GetXPExhaustion() -- 475500
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
	if DataStore:GetMethodOwner('GetNumAuctions') and DataStore:GetMethodOwner('GetNumBids') then
		local auctions, bids = DataStore:GetNumAuctions(characterKey), DataStore:GetNumBids(characterKey)
		return auctions or 0, bids or 0
	else
		return 0, 0
	end
end
function data.GetAuctionInfo(characterKey, list, index)
	if DataStore:GetMethodOwner('GetAuctionHouseItemInfo') then
		return DataStore:GetAuctionHouseItemInfo(characterKey, list, index)
	end
end
function data.GetNumMails(characterKey)
	if DataStore:GetMethodOwner('GetNumMails') then
		-- returns the number of item attachments in mails
		return DataStore:GetNumMails(characterKey) or 0
	else
		return 0
	end
end
function data.GetMailInfo(characterKey, index)
	if DataStore:GetMethodOwner('GetMailExpiry') and DataStore:GetMethodOwner('GetMailSender') and DataStore:GetMethodOwner('GetMailInfo') then
		local _, expires = DataStore:GetMailExpiry(characterKey, index)
		local sender     = DataStore:GetMailSender(characterKey, index)
		return sender, expires, DataStore:GetMailInfo(characterKey, index)
	end
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
	local primary, secondary
	if DataStore:GetMethodOwner('GetNumUnspentTalents') then
		primary, secondary = DataStore:GetNumUnspentTalents(characterKey, 1), DataStore:GetNumUnspentTalents(characterKey, 2)
	end
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
					info[1], info[2], info[3] = DataStore:GetContainerItemCount(key, itemID)
					info[4] = DataStore:GetAuctionHouseItemCount(key, itemID)
					info[5] = DataStore:GetInventoryItemCount(key, itemID)
					info[6] = DataStore:GetMailItemCount(key, itemID)
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

local function ClearCacheItemCount(itemID, key)
	-- remove previously cached data
	local itemData = rawget(itemCountCache, itemID)
	if itemData then
		if key then
			-- clear data for this key
			if rawget(itemData, key) then
				rawset(itemData, key, nil)
			end
		else
			-- clear data for all keys
			for k, v in pairs(itemData) do
				rawset(itemData, k, nil)
			end
		end
	end
end

local function ClearCache(key)
	local charData
	for itemID, data in pairs(itemCountCache) do
		charData = rawget(data, key)
		if charData then
			wipe(charData)
			rawset(data, key, nil)
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
	if characterKey == thisCharacter then
		local item = GetInventoryItemLink('player', slotID)
		return item
	else
		local item = DataStore:GetInventoryItem(characterKey, slotID)
		if item and type(item) == 'number' and not rawOnly then
			_, item = GetItemInfo(item)
		end
		return item
	end
end

--[[
function data.GetContainerSlotInfo(characterKey, bag, slot)
	if DataStore:GetMethodOwner('GetContainerInfo') and DataStore:GetMethodOwner('GetSlotInfo') then
		local container = DataStore:GetContainerInfo(characterKey, bag)
		return DataStore_Containers:GetSlotInfo(container, slot)
	else
		return nil
	end
end
--]]

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
