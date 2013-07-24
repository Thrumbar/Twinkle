local addonName, ns, _ = ...
local data = {}
ns.data = data

function data.GetCharacters(useTable)
	if useTable then wipe(useTable) else useTable = {} end
	for characterName, characterKey in pairs(DataStore:GetCharacters()) do
		table.insert(useTable, characterKey)
	end
	table.sort(useTable)
	return useTable
end

function data.GetCurrentCharacter()
	return DataStore:GetCharacter()
end

function data.GetCharacterText(characterKey, noIcon)
	local text
	if IsAddOnLoaded('DataStore_Characters') then
		if noIcon then
			text = ''
		else
			local faction = DataStore:GetCharacterFaction(characterKey)
			if faction == "Horde" then
				text = '|TInterface\\WorldStateFrame\\HordeIcon.png:22|t '
			elseif faction == "Alliance" then
				text = '|TInterface\\WorldStateFrame\\AllianceIcon.png:22|t '
			else
				text = '|TInterface\\MINIMAP\\TRACKING\\BattleMaster:22|t '
			end
		end
		text = text .. (DataStore:GetColoredCharacterName(characterKey) or '') .. '|r'
	else
		local _, _, characterName = strsplit('.', characterKey)
		text = characterName
	end
	return text
end

-- list icon: 						Interface\\FriendsFrame\\UI-FriendsList-Small-Up
-- cogwheel icon: 					Interface\\Scenarios\\ScenarioIcon-Interact
-- boss skull icon: 				Interface\\Scenarios\\ScenarioIcon-Boss
-- sword icon: 						Interface\\TUTORIALFRAME\\UI-TutorialFrame-AttackCursor
-- crossed swords: 					Interface\\WorldStateFrame\\CombatSwords
-- hand icon: 						Interface\\TUTORIALFRAME\\UI-TutorialFrame-GloveCursor
-- dog bone: 						Interface\\PetPaperDollFrame\\PetStable-DietIcon
-- pergament bg: 					Interface\\TALENTFRAME\\spec-paper-bg
-- pet type badges: 				Interface\\TARGETINGFRAME\\PetBadge-Water
-- green arrow ^: 					Interface\\PetBattles\\BattleBar-AbilityBadge-Strong-Small
-- red arrow v: 					Interface\\PetBattles\\BattleBar-AbilityBadge-Weak-Small
-- arrows down (green, red, yellow: Interface\\Buttons\\UI-MicroStream-Green
-- gold lock icon: 					Interface\\PetBattles\\PetBattle-LockIcon
-- yellow exclamation: 				Interface\\OPTIONSFRAME\\UI-OptionsFrame-NewFeatureIcon
-- stack of gold coins: 			Interface\\MINIMAP\\TRACKING\\Auctioneer
-- bags: 							Interface\\MINIMAP\\TRACKING\\Banker
-- hearthstone: 					Interface\\MINIMAP\\TRACKING\\Innkeeper
-- mail: 							Interface\\MINIMAP\\TRACKING\\Mailbox
-- magnifier: 						Interface\\MINIMAP\\TRACKING\\None
-- treasure chest: 					Interface\\WorldMap\\TreasureChest_64
-- lfr eye: 						Interface\\LFGFRAME\\BattlenetWorking18
-- helmet bw: 						Interface\\GUILDFRAME\\GuildLogo-NoLogo
-- gold crown: 						Interface\\GROUPFRAME\\UI-Group-LeaderIcon
-- bag w/ gold coin: 				Interface\\GossipFrame\\BankerGossipIcon
-- armor icon (1/6 MID): 			Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs

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
function data.GetLevel(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		return DataStore:GetCharacterLevel(characterKey)
	else
		return 0
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
function data.GetRace(characterKey)
	if IsAddOnLoaded("DataStore_Characters") then
		local locale, english = DataStore:GetCharacterRace(characterKey)
		return locale, english
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
		return ''
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
					complete = status
				})
			end
		end
	end
	return useTable
end
