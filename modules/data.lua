local addonName, addon, _ = ...

local data = addon:NewModule('data', 'AceEvent-3.0')
addon.data = data

local thisCharacter = DataStore:GetCharacter()
local realmCharacters = DataStore:GetCharacters()

function data.GetCharacters(useTable)
	if useTable then wipe(useTable) else useTable = {} end
	for characterName, characterKey in pairs(realmCharacters) do
		table.insert(useTable, characterKey)
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
	if IsAddOnLoaded('DataStore_Characters') then
		return DataStore:GetCharacterName(characterKey)
	else
		return characterKey
	end
end
function data.GetFullName(characterKey)
	if IsAddOnLoaded('DataStore_Characters') then
		-- return DataStore:GetCharacterName(characterKey)
		local account, realm, character = strsplit('.', characterKey)
		return character..'-'..string.gsub(realm, ' ', '')
	else
		return characterKey
	end
end
function data.GetCharacterText(characterKey)
	local text
	if IsAddOnLoaded('DataStore_Characters') then
		text = DataStore:GetColoredCharacterName(characterKey) .. '|r'
	else
		local _, _, characterName = strsplit('.', characterKey)
		text = characterName
	end
	return text or ''
end
function data.GetCharacterFactionIcon(characterKey)
	local text
	if IsAddOnLoaded('DataStore_Characters') then
		local faction = DataStore:GetCharacterFaction(characterKey)
		if faction == 'Horde' then
			text = '|TInterface\\WorldStateFrame\\HordeIcon.png:22|t'
		elseif faction == 'Alliance' then
			text = '|TInterface\\WorldStateFrame\\AllianceIcon.png:22|t'
		else
			text = '|TInterface\\MINIMAP\\TRACKING\\BattleMaster:22|t'
		end
	end
	return text or ''
end
function data.GetRace(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		local locale, english = DataStore:GetCharacterRace(characterKey)
		return locale, english
	else
		return ''
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
		return UnitClass("player")
	elseif IsAddOnLoaded("DataStore_Characters") then
		local locale, english = DataStore:GetCharacterClass(characterKey)
		local classID = GetClassID(english)
		return locale, english, classID
	else
		return ''
	end
end
function data.GetLevel(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		return DataStore:GetCharacterLevel(characterKey)
	else
		return 0
	end
end
function data.GetMoney(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		return DataStore:GetMoney(characterKey)
	elseif characterKey == data.GetCurrentCharacter() then
		return GetMoney()
	else
		return 0
	end
end
function data.GetAverageItemLevel(characterKey)
	if IsAddOnLoaded("DataStore_Inventory") then
		return math.floor(DataStore:GetAverageItemLevel(characterKey) + 0.5)
	else
		return 0
	end
end
function data.GetXPInfo(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		-- GetXP, GetXPMax, GetRestXP
		local currentXP = DataStore:GetXPRate(characterKey)
		local restedXP = DataStore:GetRestXPRate(characterKey)

		if restedXP and restedXP > 0 then
			return string.format("%d%% (+%d%%)", currentXP, restedXP*1.5)
		else
			return string.format("%d%%", currentXP)
		end
	else
		return ''
	end
end
function data.GetLocation(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		local location = DataStore:GetLocation(characterKey)
		local isResting = DataStore:IsResting(characterKey)
		return location or '', isResting
	else
		return ''
	end
end
function data.GetAuctionState(characterKey)
	if IsAddOnLoaded("DataStore_Auctions") then
		local auctions, bids = DataStore:GetNumAuctions(characterKey), DataStore:GetNumBids(characterKey)
		return auctions or 0, bids or 0
	else
		return 0, 0
	end
end
function data.GetAuctionInfo(characterKey, list, index)
	if IsAddOnLoaded("DataStore_Auctions") then
		return DataStore:GetAuctionHouseItemInfo(characterKey, list, index)
	end
end
function data.GetNumMails(characterKey)
	if IsAddOnLoaded("DataStore_Mails") then
		return DataStore:GetNumMails(characterKey) or 0
	else
		return 0
	end
end
function data.GetMailInfo(characterKey, index)
	if IsAddOnLoaded("DataStore_Mails") then
		local _, expires = DataStore:GetMailExpiry(characterKey, index)
		local sender = DataStore:GetMailSender(characterKey, index)
		return sender, expires, DataStore:GetMailInfo(characterKey, index)
	end
end
function data.GetGuildInfo(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		local guildName, guildRank, rankID = DataStore:GetGuildInfo(characterKey)
		return guildName, guildRank, rankID
	else
		return '', '', -1
	end
end
function data.GetNumUnspentTalents(characterKey)
	local primary, secondary
	if IsAddOnLoaded("DataStore_Talents") then
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
data:RegisterEvent("CHAT_MSG_LOOT", function(self, event, message)
	local id, linkType = addon.GetLinkID(message)
	if id and linkType == "item" then
		ClearCacheItemCount(id, thisCharacter)
	end
end) --]]
data:RegisterEvent("BAG_UPDATE_DELAYED", function(self, event)
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
		return GetInventoryItemLink("player", slotID)
	elseif IsAddOnLoaded("DataStore_Inventory") then
		-- FIXME: DataStore doesn't save upgraded items
		local item = DataStore:GetInventoryItem(characterKey, slotID)
		if not rawOnly and type(item) == "number" then
			_, item = GetItemInfo(item)
		end
		return item
	end
end

--[[
function data.GetContainerSlotInfo(characterKey, bag, slot)
	if IsAddOnLoaded("DataStore_Containers") then
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
	elseif IsAddOnLoaded("DataStore_Currencies") then
		return DataStore:GetCurrencyInfo(characterKey, index)
	end
end

-- identifier may be currencyID or currencyName
function data.GetCurrencyInfo(characterKey, identifier)
	local weekly = DataStore:GetCurrencyWeeklyAmount(characterKey, identifier)
	local compareName = type(identifier) == 'number' and GetCurrencyInfo(identifier) or identifier

	for index = 1, data.GetNumCurrencies(characterKey) do
		local isHeader, name, count, icon = data.GetCurrencyInfoByIndex(characterKey, index)
		if name == compareName then
			return isHeader, name, count, icon, weekly
		end
	end

	local name, _, texturePath = GetCurrencyInfo(identifier)
	return nil, name, nil, texturePath, nil
end

-- ========================================
--  Activity
-- ========================================
function data.GetRandomLFGState(characterKey, useTable)
	useTable = useTable or {}
	wipe(useTable)

	if IsAddOnLoaded("Broker_DataStore") then
		for dungeonID, status, resetTime, numDefeated in DataStore:GetLFGs(characterKey) do
			local dungeon, typeID = GetLFGDungeonInfo(dungeonID)
			if typeID == TYPEID_RANDOM_DUNGEON and type(status) == "boolean" then
				table.insert(useTable, {
					id = dungeonID,
					name = dungeon,
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

	if IsAddOnLoaded("Broker_DataStore") then
		for dungeonID, status, resetTime, numDefeated in DataStore:GetLFGs(characterKey) do
			local dungeon, typeID, subTypeID = GetLFGDungeonInfo(dungeonID)
			if typeID == TYPEID_DUNGEON and subTypeID == LFG_SUBTYPEID_RAID and type(status) == "boolean" then
				table.insert(useTable, {
					id = dungeonID,
					name = dungeon,
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

	if IsAddOnLoaded("DataStore_Quests") then
		for i = 1, DataStore:GetDailiesHistorySize(characterKey) do
			local _, title = DataStore:GetDailiesHistoryInfo(characterKey, i)
			table.insert(useTable, title)
		end
	end
	return useTable
end
