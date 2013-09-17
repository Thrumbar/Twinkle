local addonName, ns, _ = ...
local data = {}
ns.data = data

local thisCharacter = DataStore:GetCharacter()

function data.GetCharacters(useTable)
	if useTable then wipe(useTable) else useTable = {} end
	for characterName, characterKey in pairs(DataStore:GetCharacters()) do
		table.insert(useTable, characterKey)
	end
	table.sort(useTable)
	return useTable
end

function data.GetCurrentCharacter()
	return thisCharacter
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
		if faction == "Horde" then
			text = '|TInterface\\WorldStateFrame\\HordeIcon.png:22|t'
		elseif faction == "Alliance" then
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
function data.GetClass(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		local locale, english = DataStore:GetCharacterClass(characterKey)
		return locale, english
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
		return (DataStore:GetLocation(characterKey)), DataStore:IsResting(characterKey)
	else
		return ''
	end
end
function data.GetAuctionState(characterKey)
	if IsAddOnLoaded("DataStore_Auctions") then
		return DataStore:GetNumAuctions(characterKey), DataStore:GetNumBids(characterKey)
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
		return DataStore:GetNumMails(characterKey)
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
-- ========================================
--  Containers & Inventory
-- ========================================
--[[ local itemCountCache = setmetatable({}, {
	__mode = "kv",
	__index = function(self, item)
		return characterCounts
	end
}) --]]
local itemCounts = {}
function data.GetItemCounts(characterKey, itemID, uncached)
	wipe(itemCounts)
	-- TODO: cross-faction, cross-realm, ...
	itemCounts[1], itemCounts[2], itemCounts[3] = DataStore:GetContainerItemCount(characterKey, itemID)
	itemCounts[4] = DataStore:GetAuctionHouseItemCount(characterKey, itemID)
	itemCounts[5] = DataStore:GetInventoryItemCount(characterKey, itemID)
	itemCounts[6] = DataStore:GetMailItemCount(characterKey, itemID)
	return itemCounts
end
local guildCounts = {}
function data.GetGuildItemCounts(itemID, uncached)
	wipe(guildCounts)
	for guild, identifier in pairs( DataStore:GetGuilds() ) do
		-- DataStore:GetGuildFaction(guild) == 'Horde' and
		local guildText = string.format('%s%s|r', BATTLENET_FONT_COLOR_CODE,  guild)
		local count = DataStore:GetGuildBankItemCount(identifier, itemID)
		if count > 0 then
			guildCounts[ guildText ] = count
		end
	end
	return guildCounts
end
function data.GetInventoryItemLink(characterKey, slotID)
	if characterKey == thisCharacter then
		return GetInventoryItemLink("player", slotID)
	elseif IsAddOnLoaded("DataStore_Inventory") then
		-- FIXME: DataStore doesn't save upgraded items
		local item = DataStore:GetInventoryItem(characterKey, slotID)
		if type(item) == "number" then
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
