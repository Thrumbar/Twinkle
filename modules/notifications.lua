local addonName, addon, _ = ...
local notifications = addon:NewModule('Notifications', 'AceEvent-3.0')

-- GLOBALS: _G, LibStub, DataStore, DataMore, C_Garrison, C_Timer
-- GLOBALS: tContains, table, pairs, print, time, type, tremove, ipairs, strsplit, wipe, date, hooksecurefunc

-- local QTip = LibStub('LibQTip-1.0')
-- local LDB  = LibStub('LibDataBroker-1.1')

local thisCharacter = addon.data.GetCurrentCharacter()
local notificationsCache = {}
local emptyTable = {}

local defaults = {
	global = {
		eventReminders = {
			[ 0] = true,
			[ 5] = true,
			[10] = true,
			[15] = true,
			[30] = true,
			[60] = true,
		},
		updateInterval = 30,
	},
}

-- TODO: LibSink
function notifications:GetSentNotifications(characterKey)
	return characterKey and notificationsCache[characterKey] or notificationsCache
end

function notifications:Print(message, ...)
	print('|cFFFF751F'..addonName..':|r', message, ...)
end

local dateTable = {}
local function StringToTimestamp(dateString, timeString)
	-- formatted by DataStore as '%04d-%02d-%02d' (2014-12-31), '%02d:%02d' (09:59)
	wipe(dateTable)
	local year, month, day = strsplit('-', dateString)
	dateTable.year, dateTable.month, dateTable.day = year*1, month*1, day*1
	local hours, minutes = strsplit(':', timeString)
	dateTable.hour, dateTable.min, dateTable.sec = hours*1, minutes*1, 0
	return time(dateTable)
end

local reminderIntervals = {0, 5, 10, 15, 30, 60}
local function CheckCalendarNotifications(characterKey, characterName, now)
	local lastUpdate = DataStore:GetModuleLastUpdateByKey(_G.DataStore_Agenda, characterKey)
	if not lastUpdate or now - lastUpdate > 3*24*60*60 then return end
	local charNotifications = notificationsCache[characterKey]
	local today = date('%Y-%m-%d')

	for index = 1, DataStore:GetNumCalendarEvents(characterKey) or emptyTable do
		local eventDate, eventTime, title, eventType, inviteStatus = DataStore:GetCalendarEventInfo(characterKey, index)
		if eventDate == today then
			local eventStamp = StringToTimestamp(eventDate, eventTime)
			for i, diffMinutes in ipairs(reminderIntervals) do
				local eventKey = index..':'..diffMinutes
				if eventStamp - diffMinutes*60 <= now then
					if not tContains(charNotifications.events, eventKey) then
						-- remove previous reminders
						for i = #charNotifications.events, 1, -1 do
							if charNotifications.events[i]:find('^'..index..':') then
								tremove(charNotifications.events, index)
							end
						end
						table.insert(charNotifications.events, eventKey)
						if notifications.db.global.eventReminders[diffMinutes] then
							-- user can disable printing to chat
							local notification = diffMinutes == 0 and 'Event “%2$s” for %1$s has started.' or 'Event “%2$s” for %1$s will start in %3$s minutes.'
							notifications:Print((notification):format(characterName, title, diffMinutes))
						end
					end
					break
				end
			end
		end
	end
end

local function CheckGarrisonMissions(characterKey, characterName, now)
	local lastUpdate = DataStore:GetModuleLastUpdateByKey(DataMore:GetModule('Timers'), characterKey)
	if not lastUpdate or now - lastUpdate > 3*24*60*60 then return end

	local charNotifications = notificationsCache[characterKey]
	local hasNewMissions = false
	for missionID, expires in DataStore:IterateGarrisonMissions(characterKey) or nop do
		if expires <= now then
			local data = C_Garrison.GetMissionLink(missionID)
			if not tContains(charNotifications.missions, data) then
				hasNewMissions = true
				table.insert(charNotifications.missions, data)
			end
		end
	end
	if hasNewMissions and not (GarrisonMissionFrame and GarrisonMissionFrame:IsShown()) then
		local link = ('|Htwinkle:missions:%1$s|h[%3$d |4mission:missions;]|h'):format(characterKey, characterName, #charNotifications.missions)
		-- notifications:Print(characterName .. ' ' .. link)
		return link
	end
end

local function CheckGarrisonBuilds(characterKey, characterName, now)
	local lastUpdate = DataStore:GetModuleLastUpdateByKey(DataMore:GetModule('Timers'), characterKey)
	if not lastUpdate or now - lastUpdate > 3*24*60*60 then return end

	local charNotifications = notificationsCache[characterKey]
	local hasNewBuilds = false
	for buildingID, expires in DataStore:IterateGarrisonBuilds(characterKey) or nop do
		if expires <= now then
			local _, data = C_Garrison.GetBuildingInfo(buildingID)
			if not tContains(charNotifications.builds, data) then
				hasNewBuilds = true
				table.insert(charNotifications.builds, data)
			end
		end
	end
	if hasNewBuilds then
		local link = ('|Htwinkle:buildings:%1$s|h[%3$d |4build:builds;]|h'):format(characterKey, characterName, #charNotifications.builds)
		-- notifications:Print(characterName .. ' ' .. link)
		return link
	end
end

local function CheckGarrisonShipments(characterKey, characterName, now)
	local lastUpdate = DataStore:GetModuleLastUpdateByKey(DataMore:GetModule('Timers'), characterKey)
	if not lastUpdate or now - lastUpdate > 3*24*60*60 then return end

	local charNotifications = notificationsCache[characterKey]
	local hasNewShipments, numShipments = false, 0
	for buildingID, nextBatch, numActive, numReady, maxOrders in DataStore:IterateGarrisonShipments(characterKey) or nop do
		numActive = numActive - numReady
		while nextBatch > 0 and numActive > 0 and nextBatch <= now do
			-- additional sets that have been completed
			numActive = numActive - 1
			numReady  = (numReady or 0) + 1
			nextBatch = nextBatch + 4*60*60
		end
		numShipments = numShipments + numReady

		if numReady > 0 then
			local _, name = C_Garrison.GetBuildingInfo(buildingID)
			local data = ('%1$s (%2$d/%3$d of %4$s)'):format(name, numReady, numReady+numActive, maxOrders)
			if not tContains(charNotifications.shipments, data) then
				-- remove previous notifications
				for i = #charNotifications.shipments, 1, -1 do
					if charNotifications.shipments[i]:find('^'..name..' %(') then
						tremove(charNotifications.shipments, i)
					end
				end
				hasNewShipments = true
				table.insert(charNotifications.shipments, data)
			end
		end
	end
	if hasNewShipments then
		local link = ('|Htwinkle:shipments:%1$s|h[%3$d |4work order:work orders;]|h'):format(characterKey, characterName, numShipments)
		-- notifications:Print(characterName .. ' ' .. link)
		return link
	end
end

local function CheckCraftingNotifications(characterKey, characterName, now)
	local lastUpdate = DataStore:GetModuleLastUpdateByKey(_G.DataStore_Agenda, characterKey)
	if not lastUpdate or now - lastUpdate > 3*24*60*60 then
		return
	end
	local charNotifications = notificationsCache[characterKey]

	for profName, profession in pairs(DataStore:GetProfessions(characterKey) or emptyTable) do
		for index = 1, DataStore:GetNumActiveCooldowns(profession) or 0 do
			local name, expiresIn, _, lastCheck = DataStore:GetCraftCooldownInfo(profession, index)
			local expires = lastCheck + expiresIn
			-- TODO
		end
	end
end

local handlers = {
	missions  = CheckGarrisonMissions,
	shipments = CheckGarrisonShipments,
	builds    = CheckGarrisonBuilds,
	events    = CheckCalendarNotifications,
	crafts    = CheckCraftingNotifications,
}

local messages = {}
local function CheckNotifications(charKey, groupName)
	if type(charKey) == 'table' then charKey = nil end
	local now = time()
	for _, characterKey in pairs(addon.data.GetCharacters()) do
		if not charKey or charKey == characterKey then
			wipe(messages)
			local characterName = addon.data.GetCharacterText(characterKey)

			-- make sure all tables exist
			notificationsCache[characterKey] = notificationsCache[characterKey] or {}
			for key in pairs(handlers) do
				notificationsCache[characterKey][key] = notificationsCache[characterKey][key] or {}
			end

			for handlerName, handler in pairs(handlers) do
				if (not groupName or groupName == handlerName) and type(handler) == 'function' then
					local notification = handler(characterKey, characterName, now)
					if notification and notification ~= '' then
						table.insert(messages, notification)
					end
				end
			end
			if #messages > 0 then
				notifications:Print(characterName .. ' has completed ' .. table.concat(messages, ', '))
			end
		end
	end
	addon:GetModule('brokers'):GetModule('Notifications'):Update()
end
local function UpdateNotifications(groupName)
	if not notificationsCache[thisCharacter] then return end
	for group, info in pairs(notificationsCache[thisCharacter]) do
		if not groupName or group == groupName then
			wipe(info)
		end
	end
	CheckNotifications(thisCharacter, groupName)
end

function notifications:OnEnable()
	self.db = addon.db:RegisterNamespace('Notifications', defaults)

	--[[ create config ui
	local types = {
		-- eventReminders = 'multiselect',
	}
	local optionsTable = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(self.db, types)
	      optionsTable.name = strjoin(' - ', addonName, self:GetName())
	LibStub('AceConfig-3.0'):RegisterOptionsTable(self.name, optionsTable)
	-- added to options when options panel gets loaded --]]

	-- we will check for changes every few seconds
	local ticker = C_Timer.NewTicker(notifications.db.global.updateInterval, CheckNotifications)
	-- and once on load
	C_Timer.After(2, CheckNotifications)

	self:RegisterMessage('DATAMORE_TIMERS_SHIPMENT_COLLECTED', UpdateNotifications, 'shipments')
	self:RegisterEvent('GARRISON_BUILDING_ACTIVATED', UpdateNotifications, 'builds')
	self:RegisterEvent('GARRISON_MISSION_COMPLETE_RESPONSE', UpdateNotifications, 'missions')
	hooksecurefunc(C_Garrison, 'CloseMissionNPC', function() UpdateNotifications('missions') end)

	local SetHyperlink = ItemRefTooltip.SetHyperlink
	function ItemRefTooltip:SetHyperlink(link)
		if link:match('^twinkle') then
			local _, subType, characterKey = strsplit(':', link)
			if subType == 'missions' then
				local missions
				for _, missionLink in pairs(notificationsCache[characterKey].missions) do
					missions = missions and missions .. ', ' or ''
					-- add mission rewards
					local missionID = missionLink:match('garrmission:(%d+)') * 1
					for key, reward in pairs(C_Garrison.GetMissionRewardInfo(missionID)) do
						local icon, count = reward.icon, reward.quantity
						if reward.itemID then
							icon = GetItemIcon(reward.itemID)
						-- elseif reward.currencyID == 0 then
						-- 	count = BreakUpLargeNumbers(count/_G.COPPER_PER_GOLD)
						end
						if not reward.followerXP and reward.currencyID ~= 0 then
							-- don't display gold or follower XP rewards
							missions = missions .. ('|T%1$s:0|t '):format(icon)
							--[[ if count and count > 1 then
								missions = missions .. 'x'..count
							end --]]
						end
					end
					-- add mission name w/ link
					missions = missions:trim() .. missionLink
				end

				local characterName = addon.data.GetCharacterText(characterKey)
				notifications:Print(('Garrison missions completed by %s: %s'):format(characterName, missions or ''))
			elseif subType == 'buildings' then
				local characterName = addon.data.GetCharacterText(characterKey)
				local buildings = table.concat(notificationsCache[characterKey].builds, ', ')
				notifications:Print(('Garrison buildings completed by %s: %s'):format(characterName, buildings))
			elseif subType == 'shipments' then
				local characterName = addon.data.GetCharacterText(characterKey)
				local shipments = table.concat(notificationsCache[characterKey].shipments, ', ')
				notifications:Print(('Garrison shipment has arrived for %s: %s'):format(characterName, shipments))
			end
		else
			SetHyperlink(self, link)
		end
	end
end
