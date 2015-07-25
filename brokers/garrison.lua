local addonName, addon, _ = ...

-- GLOBALS: _G

local brokers = addon:GetModule('brokers')
local broker  = brokers:NewModule('Garrison')
local emptyTable = {}

local defaults = {
	profile = {
		cacheFullWarningPercent = 0.75,
	},
}

function broker:OnEnable()
	self.db = addon.db:RegisterNamespace('Garrison', defaults)
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

local COMPLETE = _G.GREEN_FONT_COLOR_CODE .. '%1$s|r'
local COMPLETE_ACTIVE = _G.GREEN_FONT_COLOR_CODE .. '%1$s|r+' .. _G.NORMAL_FONT_COLOR_CODE .. '%2$s|r'
local INACTIVE = _G.GRAY_FONT_COLOR_CODE .. '%3$s|r'
local ZERO = _G.GRAY_FONT_COLOR_CODE .. '0|r'
local COMPLETE_ICON = _G.GREEN_FONT_COLOR_CODE .. '%d|r|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t '
local ACTIVE_ICON = _G.NORMAL_FONT_COLOR_CODE .. '%d|r|TInterface\\FriendsFrame\\StatusIcon-Away:0|t '
function broker:UpdateTooltip()
	local numColumns = 7
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT', 'CENTER', 'RIGHT', 'CENTER', 'LEFT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': Garrisons', 'LEFT', numColumns)

	local resourceIcon = '|T'..(select(3, GetCurrencyInfo(824)))..':0|t'
	local oilIcon = '|T'..(select(3, GetCurrencyInfo(1101)))..':0|t'
	local missionIcon = '|TInterface\\HELPFRAME\\OpenTicketIcon:18|t'
	lineNum = self:AddHeader(_G.CHARACTER, resourceIcon, missionIcon, oilIcon, missionIcon, _G.CAPACITANCE_WORK_ORDERS)

	-- add header tooltips
	self.lines[lineNum].cells[2].link = 'currency:824'
	self:SetCellScript(lineNum, 2, 'OnEnter', addon.ShowTooltip, self)
	self:SetCellScript(lineNum, 2, 'OnLeave', addon.HideTooltip, self)
	self.lines[lineNum].cells[3].tiptext = _G.GARRISON_MISSIONS_TITLE
	self:SetCellScript(lineNum, 3, 'OnEnter', addon.ShowTooltip, self)
	self:SetCellScript(lineNum, 3, 'OnLeave', addon.HideTooltip, self)
	self.lines[lineNum].cells[4].link = 'currency:1101'
	self:SetCellScript(lineNum, 4, 'OnEnter', addon.ShowTooltip, self)
	self:SetCellScript(lineNum, 4, 'OnLeave', addon.HideTooltip, self)
	self.lines[lineNum].cells[5].tiptext = _G.SPLASH_NEW_6_2_FEATURE2_TITLE
	self:SetCellScript(lineNum, 5, 'OnEnter', addon.ShowTooltip, self)
	self:SetCellScript(lineNum, 5, 'OnLeave', addon.HideTooltip, self)

	self:AddSeparator(2)

	local now, hasData = time(), false
	local shipmentInterval = 4*60*60 -- every four hours
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		-- shipments
		local shipments = ''
		for buildingID, max, active, completed, nextBatch in DataStore:IterateShipments(characterKey) or nop do
			active = active - completed
			while nextBatch > 0 and active > 0 and nextBatch <= now do
				-- additional sets that have been completed
				active = active - 1
				completed = (completed or 0) + 1
				nextBatch = nextBatch + shipmentInterval
			end
			local fulfilled = active > 0 and (nextBatch + (active-1) * shipmentInterval) or nil
			      fulfilled = fulfilled and fulfilled - time()
			if fulfilled then
				local textFormat, value = SecondsToTimeAbbrev(fulfilled)
				fulfilled = (fulfilled < shipmentInterval and _G.RED_FONT_COLOR_CODE or _G.NORMAL_FONT_COLOR_CODE) .. textFormat:format(value) .. '|r'
			end

			local _, _, _, icon = C_Garrison.GetBuildingInfo(buildingID)
			if active > 0 or fulfilled then
				shipments = (shipments ~= '' and shipments..' ' or '') .. '|T'..icon..':0|t ' .. (completed > 0 and COMPLETE:format(completed)..' ' or '') .. fulfilled
			end
		end

		-- builds
		local numActive, numCompleted = 0, 0
		for _, buildingID, rank, _, _, expires in DataStore:IteratePlots(characterKey) or nop do
			if expires then
				local _, _, _, icon = C_Garrison.GetBuildingInfo(buildingID)
				if numActive + numCompleted == 0 then
					-- separate work orders and build progress
					shipments = (shipments ~= '' and shipments..'|n' or '')
				end
				shipments = shipments .. '+|T'..icon..':0|t'

				if expires <= now then
					numCompleted = numCompleted + 1
				else
					numActive = numActive + 1
					shipments = shipments .. '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t'
				end
			end
		end

		-- missions
		local numActive, numCompleted = 0, 0
		local shipyardActive, shipyardCompleted = 0, 0
		for missionID, expires in pairs(DataStore:GetMissions(characterKey, 'active') or emptyTable) do
			local followerType = DataStore:GetBasicMissionInfo(missionID)
			if followerType == _G.LE_FOLLOWER_TYPE_SHIPYARD_6_2 then
				shipyardCompleted = shipyardCompleted + (expires <= now and 1 or 0)
				shipyardActive    = shipyardActive    + (expires <= now and 0 or 1)
			else
				numCompleted = numCompleted + (expires <= now and 1 or 0)
				numActive    = numActive    + (expires <= now and 0 or 1)
			end
		end
		local missions, shipyardMissions = '', ''
		if numCompleted > 0 then missions = missions .. COMPLETE_ICON:format(numCompleted) end
		if numActive > 0 then missions = missions .. ACTIVE_ICON:format(numActive) end
		if shipyardCompleted > 0 then shipyardMissions = shipyardMissions .. COMPLETE_ICON:format(shipyardCompleted) end
		if shipyardActive > 0 then shipyardMissions = shipyardMissions .. ACTIVE_ICON:format(shipyardActive) end

		-- resources
		local _, _, numOil = addon.data.GetCurrencyInfo(characterKey, 1101)
		local _, _, numResources = addon.data.GetCurrencyInfo(characterKey, 824)
		local numUncollected, cacheSize = DataStore:GetUncollectedResources(characterKey)
		local warning = ''
		if (numUncollected or 0) / cacheSize >= broker.db.profile.cacheFullWarningPercent then
			warning = '|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t'
		end

		-- create tooltip row
		if builds ~= '' or missions ~= '' or shipments ~= '' or numResources > 0 or numUncollected > 0 then
			local characterName = addon.data.GetCharacterText(characterKey)
			lineNum = self:AddLine(characterName,
				warning .. addon.ColorizeText(AbbreviateLargeNumbers(numResources), 10000 - numResources, 10000),
				missions,
				_G.NORMAL_FONT_COLOR_CODE .. AbbreviateLargeNumbers(numOil) .. '|r',
				shipyardMissions,
				shipments .. '\32\32'
			)
			-- enable row highlight and tooltips
			self:SetLineScript(lineNum, 'OnEnter', nop)
			self.lines[lineNum].cells[2].tiptext = _G.GARRISON_RESOURCES_LOOT:format(numUncollected)
			self:SetCellScript(lineNum, 2, 'OnEnter', addon.ShowTooltip, self)
			self:SetCellScript(lineNum, 2, 'OnLeave', addon.HideTooltip, self)
			hasData = true
		end
	end

	return not hasData
end
