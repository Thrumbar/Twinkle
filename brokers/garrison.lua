local addonName, addon, _ = ...

-- GLOBALS: _G

local brokers = addon:GetModule('brokers')
local broker  = brokers:NewModule('Garrison')
local characters = {}
local emptyTable = {}

local defaults = {
	profile = {
		cacheFullWarningPercent = 0.75,
		 followerTypes = {
		 	-- Available types are extracted in :OnEnable.
			-- [_G.LE_FOLLOWER_TYPE_GARRISON_6_0] = true,
			-- [_G.LE_FOLLOWER_TYPE_SHIPYARD_6_2] = true,
			-- [_G.LE_FOLLOWER_TYPE_GARRISON_7_0] = true,
			-- [_G.LE_FOLLOWER_TYPE_GARRISON_8_0] = true,
		},
	},
}

function broker:OnEnable()
	-- Gather garrison type lookup data.
	for garrisonFollowerType, _ in pairs(_G.GarrisonFollowerOptions) do
		-- Enable by default.
		defaults.profile.followerTypes[garrisonFollowerType] = true
	end
	self.db = addon.db:RegisterNamespace('Garrison', defaults)
	-- self:RegisterEvent('EVENT_NAME', self.Update, self)

	self:Update()
end
function broker:OnDisable()
	-- self:UnregisterEvent('EVENT_NAME')
end

function broker:OnClick(btn, down)
	if btn == 'RightButton' then
		InterfaceOptionsFrame_OpenToCategory(addonName)
	else
		GarrisonLandingPage_Toggle()
	end
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

local layout, garrisonFollowerTypes = {}, {}
local currencyCounts, missionCounts = {}, {}
function broker:UpdateTooltip()
	wipe(garrisonFollowerTypes)
	for followerType, enabled in pairs(broker.db.profile.followerTypes) do
		if enabled then table.insert(garrisonFollowerTypes, followerType) end
	end
	table.sort(garrisonFollowerTypes)

	local missionIcon = '|TInterface\\HELPFRAME\\OpenTicketIcon:18|t'
	wipe(layout)
	table.insert(layout, 'LEFT') -- character
	for i, garrisonFollowerType in ipairs(garrisonFollowerTypes) do
		table.insert(layout, 'RIGHT') -- currency
		table.insert(layout, 'LEFT') -- missions
	end
	table.insert(layout, 'LEFT') -- work orders

	local column = #layout
	self:SetColumnLayout(column, unpack(layout))

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': Garrisons', 'LEFT', column)
	lineNum = self:AddHeader(_G.CHARACTER)

	column = 2
	for i, garrisonFollowerType in ipairs(garrisonFollowerTypes) do
		-- Garrison types can have up to two associated currencies.
		local primary, secondary = C_Garrison.GetCurrencyTypes(_G.GarrisonFollowerOptions[garrisonFollowerType].garrisonType)
		local currencyID = garrisonFollowerType == _G.LE_FOLLOWER_TYPE_SHIPYARD_6_2 and secondary or primary

		local currencyIcon = '|T'..(select(3, GetCurrencyInfo(currencyID)))..':0|t'
		self:SetCell(lineNum, column, currencyIcon, 'RIGHT')
		self:SetCellScript(lineNum, column, 'OnEnter', addon.ShowTooltip, self)
		self:SetCellScript(lineNum, column, 'OnLeave', addon.HideTooltip, self)
		self.lines[lineNum].cells[column].link = 'currency:' .. currencyID
		column = column + 1

		self:SetCell(lineNum, column, missionIcon, 'CENTER')
		self.lines[lineNum].cells[column].tiptext = _G.GARRISON_MISSIONS
		column = column + 1
	end
	self:SetCell(lineNum, column, _G.CAPACITANCE_WORK_ORDERS, 'LEFT')

	self:AddSeparator(2)

	addon.data.GetCharacters(characters)

	local now, hasData = time(), false
	local shipmentInterval = 4*60*60 -- every four hours
	for _, characterKey in ipairs(characters) do
		-- shipments
		local shipments = ''
		for buildingID, max, active, completed, nextBatch in DataStore:IterateShipments(characterKey) or nop do
			active = active - completed
			while nextBatch > 0 and active > 0 and nextBatch <= now do
				-- additional sets that have been completed
				active = active - 1
				completed = completed + 1
				nextBatch = nextBatch + shipmentInterval
			end
			local fulfilled = active > 0 and (nextBatch + (active-1) * shipmentInterval) or nil
			      fulfilled = fulfilled and fulfilled - time()
			if fulfilled then
				local textFormat, value = SecondsToTimeAbbrev(fulfilled)
				fulfilled = (fulfilled < shipmentInterval and _G.RED_FONT_COLOR_CODE or _G.NORMAL_FONT_COLOR_CODE) .. textFormat:format(value) .. '|r'
			end

			local _, _, _, icon = C_Garrison.GetBuildingInfo(buildingID)
			if active > 0 or completed > 0 or fulfilled then
				shipments = (shipments ~= '' and shipments..' ' or '') .. '|T'..icon..':0|t ' .. (completed > 0 and COMPLETE:format(completed)..' ' or '') .. (fulfilled or '')
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
		for followerType, info in pairs(missionCounts) do
			info.active = 0
			info.completed = 0
			info.text = nil
		end
		for missionID, expires in pairs(DataStore:GetMissions(characterKey, 'active') or emptyTable) do
			local followerType = DataStore:GetBasicMissionInfo(missionID)
			if not missionCounts[followerType] then
				missionCounts[followerType] = {}
			end
			if expires <= now then
				missionCounts[followerType].completed = (missionCounts[followerType].completed or 0) + 1
			else
				missionCounts[followerType].active = (missionCounts[followerType].active or 0) + 1
			end
		end

		local hasMissionData = false
		for followerType, info in pairs(missionCounts) do
			if info.completed and info.completed > 0 then
				info.text = (info.text or '') .. COMPLETE_ICON:format(info.completed)
			end
			if info.active and info.active > 0 then
				info.text = (info.text or '') .. ACTIVE_ICON:format(info.active)
			end
			hasMissionData = hasMissionData or (info.text and info.text ~= '')
		end

		-- resources
		wipe(currencyCounts)
		for i, garrisonFollowerType in ipairs(garrisonFollowerTypes) do
			local currencyID, otherCurrencyID = C_Garrison.GetCurrencyTypes(_G.GarrisonFollowerOptions[garrisonFollowerType].garrisonType)

			local count = select(3, addon.data.GetCurrencyInfo(characterKey, currencyID))
			table.insert(currencyCounts, count)

			if otherCurrencyID > 0 then
				count = select(3, addon.data.GetCurrencyInfo(characterKey, otherCurrencyID))
				table.insert(currencyCounts, count)
			end
		end
		local hasResourceData = #currencyCounts > 0

		local warning = ''
		local numUncollected, cacheSize = DataStore:GetUncollectedResources(characterKey)
		numUncollected, cacheSize = numUncollected or 0, cacheSize or 500
		if numUncollected / cacheSize >= broker.db.profile.cacheFullWarningPercent then
			warning = '|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t'
		end

		-- create tooltip row
		if hasMissionData or hasResourceData or shipments ~= '' then
			local characterName = addon.data.GetCharacterText(characterKey)
			lineNum = self:AddLine(characterName)

			-- enable row highlight and tooltips
			self:SetLineScript(lineNum, 'OnEnter', nop)
			hasData = true

			column = 2
			for i, garrisonFollowerType in ipairs(garrisonFollowerTypes) do
				-- currency
				local currencyText = AbbreviateLargeNumbers(currencyCounts[i])
				if garrisonFollowerType == _G.LE_FOLLOWER_TYPE_GARRISON_6_0 then
					currencyText = warning .. addon.ColorizeText(currencyText, 10000 - currencyCounts[i], 10000)
					self:SetCell(lineNum, column, currencyText, 'RIGHT')

					self.lines[lineNum].cells[column].tiptext = _G.GARRISON_RESOURCES_LOOT:format(numUncollected)
					self:SetCellScript(lineNum, column, 'OnEnter', addon.ShowTooltip, self)
					self:SetCellScript(lineNum, column, 'OnLeave', addon.HideTooltip, self)
				else
					currencyText = _G.NORMAL_FONT_COLOR_CODE .. currencyText .. '|r'
					self:SetCell(lineNum, column, currencyText, 'RIGHT')
				end
				column = column + 1

				-- missions
				local missionText = missionCounts[garrisonFollowerType] and missionCounts[garrisonFollowerType].text or ''
				self:SetCell(lineNum, column, missionText, 'LEFT')
				column = column + 1
			end

			self:SetCell(lineNum, column, shipments .. '\32\32', 'LEFT')
			column = column + 1
		end
	end

	return not hasData
end
