local addonName, addon, _ = ...

-- GLOBALS: _G

local brokers = addon:GetModule('brokers')
local broker  = brokers:NewModule('Garrison')
local emptyTable = {}

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

local COMPLETE = _G.GREEN_FONT_COLOR_CODE .. '%1$s|r'
local COMPLETE_ACTIVE = _G.GREEN_FONT_COLOR_CODE .. '%1$s|r/'.._G.NORMAL_FONT_COLOR_CODE .. '%2$s|r'
local INACTIVE = _G.GRAY_FONT_COLOR_CODE .. '%3$s|r'
local ZERO = _G.GRAY_FONT_COLOR_CODE .. '0|r'
function broker:UpdateTooltip()
	local numColumns = 6
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT', 'RIGHT', 'CENTER', 'CENTER', 'LEFT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': Garrisons', 'LEFT', numColumns)

	-- lineNum = self:AddHeader(_G.CHARACTER, 'Resources', 'Builds', 'Missions', 'Work Orders')
	local _, _, resourceIcon = GetCurrencyInfo(824)
	            resourceIcon = '|T'..resourceIcon..':0|t'
	local missionIcon = '|TInterface\\HELPFRAME\\OpenTicketIcon:18|t'
	local buildIcon = '|TInterface\\WorldStateFrame\\NeutralTower:0:0:0:0:32:32:3:19:2:18|t'
	lineNum = self:AddHeader(_G.CHARACTER, resourceIcon, '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t', buildIcon, missionIcon, 'Work Orders')
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
				fulfilled = '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t' .. (fulfilled < shipmentInterval and _G.RED_FONT_COLOR_CODE or _G.NORMAL_FONT_COLOR_CODE) .. textFormat:format(value) .. '|r'
			end

			local _, _, _, icon = C_Garrison.GetBuildingInfo(buildingID)
			shipments = (shipments ~= '' and shipments..' ' or '')
				.. '|T'..icon..':0|t '
				.. (completed > 0 and COMPLETE:format(completed)..' ' or '')
				.. (fulfilled or INACTIVE:format(nil, nil, max))
		end

		-- builds
		local numActive, numCompleted = 0, 0
		for _, buildingID, rank, _, _, expires in DataStore:IteratePlots(characterKey) or nop do
			if expires then
				if expires <= now then
					numCompleted = numCompleted + 1
				else
					numActive = numActive + 1
				end
			end
		end
		local builds = (numActive > 0 or numCompleted > 0) and COMPLETE_ACTIVE:format(numCompleted, numActive) or ZERO

		-- missions
		local numActive, numCompleted = 0, 0
		for missionID, expires in pairs(DataStore:GetMissions(characterKey, 'active') or emptyTable) do
			if expires <= now then
				numCompleted = numCompleted + 1
			else
				numActive = numActive + 1
			end
		end
		local missions = (numActive > 0 or numCompleted > 0) and COMPLETE_ACTIVE:format(numCompleted, numActive) or ZERO

		-- resources
		local _, _, numResources, _, numUncollectedResources = addon.data.GetCurrencyInfo(characterKey, 824)

		-- create tooltip row
		if builds ~= '' or missions ~= '' or shipments ~= ''
			or numResources > 0 or numUncollectedResources > 0 then
			local characterName = addon.data.GetCharacterText(characterKey)
			lineNum = self:AddLine(characterName,
				addon.ColorizeText(AbbreviateLargeNumbers(numResources), 10000 - numResources, 10000),
				addon.ColorizeText(numUncollectedResources, 500 - numUncollectedResources, 500),
				builds,
				missions,
				shipments .. '\32\32'
			)
			-- enable row highlight
			self:SetLineScript(lineNum, 'OnEnter', nop)
			hasData = true
		end
	end

	return not hasData
end
