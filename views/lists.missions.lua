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

local COMPONENT_ACTIVE, COMPONENT_AVAILABLE, COMPONENT_HISTORY = 1, 2, 3

-- Interface/ICONS/Creatureportrait_RopeLadder01
-- Interface/ICONS/Achievement_Arena_2v2_6
-- Interface/ICONS/INV_Misc_Map_01

function missions:OnEnable()
	-- self:RegisterEvent('USE_GLYPH', lists.Update, lists)
end
function missions:OnDisable()
	-- self:UnregisterEvent('USE_GLYPH')
end

local function GetNumRows(characterKey)
	local numActiveMissions    = DataStore:GetNumActiveMissions(characterKey) or 0
	local numAvailableMissions = DataStore:GetNumAvailableMissions(characterKey) or 0
	local historySize = 0
	-- TODO: fix lua error when character has no garrison
	for missionID, numHistoryMissions in DataStore:IterateHistoryMissions(characterKey) do
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

		local missions = DataStore:GetActiveMissions(characterKey)
		for missionID in pairs(missions) do
			if index == 1 then
				index = missionID
				break
			end
			index = index - 1
		end
	elseif rowIndex <= numActiveMissions + numAvailableMissions + COMPONENT_AVAILABLE then
		-- available missions
		component = COMPONENT_AVAILABLE
		index = rowIndex - numActiveMissions - COMPONENT_AVAILABLE

		local missions = DataStore:GetAvailableMissions(characterKey)
		for missionID in pairs(missions) do
			if index == 1 then
				index = missionID
				break
			end
			index = index - 1
		end
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

function missions:GetNumRows(characterKey)
	local numHeaders = 3 -- active missions, available missions, history missions
	local numActiveMissions, numAvailableMissions, historySize = GetNumRows(characterKey)
	return numHeaders + numActiveMissions + numAvailableMissions + historySize
end

function missions:GetRowInfo(characterKey, index)
	local headerLevel, name, prefix, suffix, link
	local component, missionID, subIndex = GetRowIndices(characterKey, index)

	if component == COMPONENT_ACTIVE then
		if missionID == 0 then
			headerLevel = 1
			-- GARRISON_LANDING_AVAILABLE
			name = 'Active Missions'
		else
			local missionType, typeAtlas, level, ilevel, cost, duration, followers, remainingTime, successChance = DataStore:GetActiveMissionInfo(characterKey, missionID)
			link = C_Garrison.GetMissionLink(missionID)
			name = C_Garrison.GetMissionName(missionID)
			local timeInfo = remainingTime <= 0 and _G.COMPLETE
				or SecondsToTime(remainingTime, true)
			suffix = timeInfo
			-- prefix = successChance
		end
	elseif component == COMPONENT_AVAILABLE then
		if missionID == 0 then
			headerLevel = 1
			-- GARRISON_LANDING_IN_PROGRESS
			name = 'Available Missions'
		else
			-- missionType, typeAtlas, level, ilevel, cost, duration = DataStore:GetAvailableMissionInfo(characterKey, missionID)
			name = C_Garrison.GetMissionName(missionID)
			link = C_Garrison.GetMissionLink(missionID)
		end
	else
		if missionID == 0 then
			headerLevel = 1
			name = 'Mission History'
		else
			if subIndex == 0 then
				headerLevel = 2
				name = C_Garrison.GetMissionName(missionID)
				link = C_Garrison.GetMissionLink(missionID)
			else
				local startTime, collectTime, successChance, success, followers, speedFactor, goldFactor, resourceFactor = DataStore:GetMissionHistoryInfo(characterKey, missionID, subIndex)
				name   = ('%s'):format(date('%Y-%m-%d %H:%M', startTime))
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
		for id, reward in pairs(C_Garrison.GetMissionRewardInfo(missionID)) do
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
					tooltipText = tooltipText .. '\n' .. (rewardInfo.tooltip or rewardInfo.name)
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
