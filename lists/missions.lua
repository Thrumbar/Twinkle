local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local _, class = UnitClass('player')
local views    = addon:GetModule('views')
local lists    = views:GetModule('lists')
local missions = lists:NewModule('Missions', 'AceEvent-3.0')
      missions.icon  = 'Interface/ICONS/Achievement_Arena_2v2_6'
      missions.title = _G.GARRISON_MISSIONS -- _TITLE
      missions.excludeItemSearch = false

local emptyTable = {}
local COMPONENT_ACTIVE, COMPONENT_AVAILABLE, COMPONENT_HISTORY = 1, 2, 3
local activeMissions, availableMissions, historyMissions = {}, {}, {}

-- Interface/ICONS/Creatureportrait_RopeLadder01
-- Interface/ICONS/Achievement_Arena_2v2_6
-- Interface/ICONS/INV_Misc_Map_01

function missions:OnEnable()
	-- self:RegisterEvent('USE_GLYPH', 'Update')
end
function missions:OnDisable()
	-- self:UnregisterEvent('USE_GLYPH')
end

local function GetNumRows(characterKey)
	local numActiveMissions    = DataStore:GetNumActiveMissions(characterKey) or 0
	local numAvailableMissions = DataStore:GetNumAvailableMissions(characterKey) or 0
	local historySize = 0
	for missionID, numHistoryMissions in DataStore:IterateHistoryMissions(characterKey) or nop do
		historySize = historySize + 1 + numHistoryMissions -- also adds a sub header
	end
	return numActiveMissions, numAvailableMissions, historySize
end

local function GetRowIndices(characterKey, rowIndex)
	local component, index, subIndex
	local numActiveMissions, numAvailableMissions, historySize = GetNumRows(characterKey)
	if rowIndex <= numActiveMissions + COMPONENT_ACTIVE then
		-- active missions
		component = COMPONENT_ACTIVE
		index = rowIndex - COMPONENT_ACTIVE
		index = activeMissions[index] or 0
	elseif rowIndex <= numActiveMissions + numAvailableMissions + COMPONENT_AVAILABLE then
		-- available missions
		component = COMPONENT_AVAILABLE
		index = rowIndex - numActiveMissions - COMPONENT_AVAILABLE
		index = availableMissions[index] or 0
	else
		-- mission history
		component = COMPONENT_HISTORY
		index = rowIndex - numActiveMissions - numAvailableMissions - COMPONENT_HISTORY
		if index > 0 then
			-- figure out missionID (index) and history index (subIndex)
			subIndex = index - 1
			for missionID, numRecords in DataStore:IterateHistoryMissions(characterKey) do
				if subIndex <= numRecords then
					index = missionID
					if subIndex > 0 then
						-- show newest first
						subIndex = numRecords - subIndex + 1
					end
					break
				end
				subIndex = subIndex - numRecords - 1
			end
		end
	end
	return component, index > 0 and index or 0, subIndex
end

local function SortActiveMissions(a, b)
	local characterKey = DataStore:GetCurrentCharacterKey()
	local aExpiry = DataStore:GetGarrisonMissionExpiry(characterKey, a) or math.huge
	local bExpiry = DataStore:GetGarrisonMissionExpiry(characterKey, b) or math.huge
	if aExpiry ~= bExpiry then return aExpiry < bExpiry
	else
		return C_Garrison.GetMissionName(a) < C_Garrison.GetMissionName(b)
	end
end
local function SortMissions(a, b)
	local aType, _, _, aLevel, aILevel, _, aDuration, aIsRare = DataStore:GetBasicMissionInfo(a)
	local bType, _, _, bLevel, bILevel, _, bDuration, bIsRare = DataStore:GetBasicMissionInfo(b)
	if aType ~= bType then return aType > bType
	elseif aIsRare ~= bIsRare then return aIsRare
	else
		return C_Garrison.GetMissionName(a) < C_Garrison.GetMissionName(b)
	end
end

function missions:GetNumRows(characterKey)
	wipe(activeMissions)
	for missionID in pairs(DataStore:GetActiveMissions(characterKey) or emptyTable) do
		table.insert(activeMissions, missionID)
	end
	table.sort(activeMissions, SortActiveMissions)
	wipe(availableMissions)
	for missionID in pairs(DataStore:GetAvailableMissions(characterKey) or emptyTable) do
		table.insert(availableMissions, missionID)
	end
	table.sort(availableMissions, SortMissions)
	wipe(historyMissions)
	for missionID in (DataStore:IterateHistoryMissions(characterKey) or nop) do
		if DataStore:GetBasicMissionInfo(missionID) then
			table.insert(historyMissions, missionID)
		end
	end
	table.sort(historyMissions, SortMissions)

	local numHeaders = 3 -- active missions, available missions, history missions
	local numActiveMissions, numAvailableMissions, historySize = GetNumRows(characterKey)
	return numHeaders + numActiveMissions + numAvailableMissions + historySize
end

-- local anchorIcon = '|TInterface\\Garrison\\GarrisonShipMapIcons:16:16:0:0:512:512:296:328:189:221|t'
local shipyardFontColor = _G.BATTLENET_FONT_COLOR_CODE
function missions:GetRowInfo(characterKey, index)
	local headerLevel, name, prefix, suffix, link
	local component, missionID, subIndex = GetRowIndices(characterKey, index)

	if component == COMPONENT_ACTIVE then
		if missionID == 0 then
			headerLevel = 1
			name = _G.WINTERGRASP_IN_PROGRESS
		else
			local missionType, typeAtlas, level, ilevel, cost, duration, followers, remainingTime, successChance, followerType = DataStore:GetActiveMissionInfo(characterKey, missionID)
			link = C_Garrison.GetMissionLink(missionID)
			name = C_Garrison.GetMissionName(missionID)
			if (followerType or LE_FOLLOWER_TYPE_GARRISON_6_0) == LE_FOLLOWER_TYPE_SHIPYARD_6_2 then
				name = shipyardFontColor .. name .. '|r'
			end

			if remainingTime <= 0 then
				prefix = '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t'
			else
				local color = (remainingTime <= 15*60 and GREEN_FONT_COLOR)
					or (remainingTime <= 30*60 and NORMAL_FONT_COLOR)
					or RED_FONT_COLOR
				-- TODO fix icon size
				prefix = ('|T%s:0:0:0:0:16:16:0:16:0:16:%d:%d:%d|t'):format(
					'Interface\\FriendsFrame\\StatusIcon-Away',
					color.r*255, color.g*255, color.b*255
				)
			end
			suffix = successChance .. '%'
		end
	elseif component == COMPONENT_AVAILABLE then
		if missionID == 0 then
			headerLevel = 1
			name = _G.AVAILABLE
		else
			local missionType, typeAtlas, level, ilevel, cost, duration, followers, remainingTime, successChance, followerType = DataStore:GetMissionInfo(characterKey, missionID)
			name = C_Garrison.GetMissionName(missionID)
			if (followerType or LE_FOLLOWER_TYPE_GARRISON_6_0) == LE_FOLLOWER_TYPE_SHIPYARD_6_2 then
				name = shipyardFontColor .. name .. '|r'
			end
			link = C_Garrison.GetMissionLink(missionID)
			suffix, remainingTime = SecondsToTimeAbbrev(remainingTime)
			suffix = suffix:format(remainingTime)
		end
	else
		if missionID == 0 then
			headerLevel = -1
			name = 'Mission History'
		else
			if subIndex == 0 then
				headerLevel = -2
				name = C_Garrison.GetMissionName(missionID)
				link = C_Garrison.GetMissionLink(missionID)
				local size = DataStore:GetMissionHistorySize(characterKey, missionID)
				local startTime, collectTime = DataStore:GetMissionHistoryInfo(characterKey, missionID, size)
				suffix = BNET_BROADCAST_SENT_TIME:gsub('[%(%)]', ''):format(FriendsFrame_GetLastOnline(collectTime))
			else
				local startTime, collectTime, successChance, success, followers, speedFactor, goldFactor, resourceFactor = DataStore:GetMissionHistoryInfo(characterKey, missionID, subIndex)
				name   = ('%s'):format(date('%Y-%m-%d %H:%M', collectTime))
				suffix = ('%s%3d%%'):format(success and GREEN_FONT_COLOR_CODE or RED_FONT_COLOR_CODE, successChance)
			end
		end
	end
	return headerLevel or nil, name, prefix, suffix, link
end

function missions:GetItemInfo(characterKey, index, itemIndex)
	local icon, link, tooltipText, count
	local component, missionID, subIndex = GetRowIndices(characterKey, index)

	if missions and missionID > 0 and (not subIndex or subIndex == 0) then
		local rewardInfo
		local rewards = C_Garrison.GetMissionRewardInfo(missionID) or emptyTable
		for id, reward in pairs(rewards) do
			if itemIndex == 1 then
				rewardInfo = reward
				break
			end
			itemIndex = itemIndex - 1
		end
		if rewardInfo then
			icon = rewardInfo.icon or GetItemIcon(rewardInfo.itemID)
			if rewardInfo.itemID then
				-- item
				_, link = GetItemInfo(rewardInfo.itemID)
			elseif rewardInfo.currencyID == 0 then
				-- gold
				icon        = 'Interface\\MONEYFRAME\\UI-GoldIcon'
				tooltipText = GetCoinTextureString(rewardInfo.quantity)..' '
			elseif rewardInfo.currencyID then
				-- currency
				_, _, icon  = GetCurrencyInfo(rewardInfo.currencyID)
				link        = GetCurrencyLink(rewardInfo.currencyID)
			else
				tooltipText = rewardInfo.title
				if rewardInfo.tooltip or rewardInfo.name then
					tooltipText = (tooltipText and tooltipText .. '\n' or '')
						.. (rewardInfo.tooltip or rewardInfo.name)
				end
			end
		end
	end
	return icon, link, tooltipText, count
end

--[[ local CustomSearch = LibStub('CustomSearch-1.0')
local linkFilters  = {
	known = {
		tags       = {},
		canSearch  = function(self, operator, search) return not operator and search == 'known' end,
		match      = function(self, text)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')

			-- glyph specific search
			local glyphID = addon.GetLinkID(hyperlink or '')
			local isKnown = DataStore:IsGlyphKnown(characterKey, glyphID)
			return isKnown
		end,
	},
}
for tag, handler in pairs(lists.filters) do
	linkFilters[tag] = handler
end
missions.filters = linkFilters --]]
