local addonName, addon, _ = ...

-- GLOBALS: _G

local brokers = addon:GetModule('brokers')
local broker  = brokers:NewModule('Garrison')

--[[
local DataStore_Garrisons_PublicMethods = {
	GetFollowers = _GetFollowers,
	GetFollowerInfo = _GetFollowerInfo,
	GetFollowerSpellCounters = _GetFollowerSpellCounters,
	GetFollowerLink = _GetFollowerLink,
	GetFollowerID = _GetFollowerID,
	GetNumFollowers = _GetNumFollowers,
	GetNumFollowersAtLevel100 = _GetNumFollowersAtLevel100,
	GetNumFollowersAtiLevel615 = _GetNumFollowersAtiLevel615,
	GetNumFollowersAtiLevel630 = _GetNumFollowersAtiLevel630,
	GetNumFollowersAtiLevel645 = _GetNumFollowersAtiLevel645,
	GetNumRareFollowers = _GetNumRareFollowers,
	GetNumEpicFollowers = _GetNumEpicFollowers,
	GetBuildingInfo = _GetBuildingInfo,
	GetUncollectedResources = _GetUncollectedResources,
}
--]]

function broker:OnEnable()
	-- self:RegisterEvent('EVENT_NAME', self.Update, self)
	self:Update()
end
function broker:OnDisable()
	-- self:UnregisterEvent('EVENT_NAME')
end

function broker:OnClick(btn, down)
	-- do something, like show a UI
end

function broker:UpdateLDB()
	self.icon = 'Interface\\FriendsFrame\\UI-Toast-BroadcastIcon'
end

local COMPLETE = _G.GREEN_FONT_COLOR_CODE .. '%1$d|r'
local COMPLETE_ACTIVE = _G.GREEN_FONT_COLOR_CODE .. '%1$d|r/'.._G.NORMAL_FONT_COLOR_CODE .. '%2$d|r'
local COMPLETE_ACTIVE_INACTIVE = _G.GREEN_FONT_COLOR_CODE .. '%1$d|r/'.._G.NORMAL_FONT_COLOR_CODE .. '%2$d|r/'.._G.RED_FONT_COLOR_CODE .. '%3$d|r'
local INACTIVE = _G.GRAY_FONT_COLOR_CODE .. '%3$d|r'
local ZERO = _G.GRAY_FONT_COLOR_CODE .. '0|r'
function broker:UpdateTooltip()
	local numColumns = 4
	self:SetColumnLayout(numColumns, 'LEFT', 'CENTER', 'CENTER', 'LEFT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': Garrisons', 'LEFT', numColumns)

	lineNum = self:AddHeader(_G.CHARACTER, 'Builds', 'Missions', 'Work Orders')
	self:AddSeparator(2)

	-- character name, completed/active builds, completed/active missions, completed/active/inactive work orders

	local now, hasData = time(), false
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		-- shipments
		local shipments = ''
		for buildingID, nextBatch, active, completed, max in DataStore:IterateGarrisonShipments(characterKey) or nop do
			active = active - completed
			while nextBatch > 0 and active > 0 and nextBatch <= now do
				-- additional sets that have been completed
				active = active - 1
				completed  = (completed or 0) + 1
				nextBatch = nextBatch + 4*60*60
			end

			local _, _, _, icon = C_Garrison.GetBuildingInfo(buildingID)
			shipments = (shipments ~= '' and shipments..' ' or '') .. '|T'..icon..':0|t ' .. (active + completed > 0 and COMPLETE_ACTIVE_INACTIVE or INACTIVE):format(completed, active, max - active - completed)
		end

		-- builds
		local numActive, numCompleted = 0, 0
		for buildingID, expires in DataStore:IterateGarrisonBuilds(characterKey) or nop do
			if expires <= now then
				numCompleted = numCompleted + 1
			else
				numActive = numActive + 1
			end
		end
		local builds = (numActive > 0 or numCompleted > 0) and COMPLETE_ACTIVE:format(numCompleted, numActive) or ZERO

		-- missions
		local numActive, numCompleted = 0, 0
		for missionID, expires in DataStore:IterateGarrisonMissions(characterKey) or nop do
			if expires <= now then
				numCompleted = numCompleted + 1
			else
				numActive = numActive + 1
			end
		end
		local missions = (numActive > 0 or numCompleted > 0) and COMPLETE_ACTIVE:format(numCompleted, numActive) or ZERO

		if builds ~= '' or missions ~= '' or shipments ~= '' then
			local characterName = addon.data.GetCharacterText(characterKey)
			lineNum = self:AddLine(characterName, builds, missions, shipments)
			          self:SetLineScript(lineNum, 'OnEnter', nop) -- show highlight on row
			hasData = true
		end
	end
	return not hasData
end
