local addonName, addon, _ = ...
local notifications = addon:NewModule('Notifications', 'AceEvent-3.0')

-- GLOBALS: LibStub, DataStore, DataMore, C_Garrison, C_Timer
-- GLOBALS: tContains, table, pairs, print, time

-- local QTip = LibStub('LibQTip-1.0')
-- local LDB  = LibStub('LibDataBroker-1.1')

local thisCharacter = DataStore:GetCharacter()
local notificationsCache = {}

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
-- TODO: config!
local reminderIntervals = {0, 5, 10, 15, 30, 60}
local function CheckCalendarNotifications(characterKey, characterName, now)
	local lastUpdate = DataStore:GetModuleLastUpdateByKey(_G.DataStore_Agenda, characterKey)
	if not lastUpdate or now - lastUpdate > 3*24*60*60 then
		return
	end
	local charNotifications = notificationsCache[characterKey]

	for index = 1, DataStore:GetNumCalendarEvents(characterKey) do
		local eventDate, eventTime, title, eventType, inviteStatus = DataStore:GetCalendarEventInfo(characterKey, index)
		if eventDate == today then
			local eventStamp = StringToTimestamp(eventDate, eventTime)
			for i, diffMinutes in ipairs(reminderIntervals) do
				local eventKey = index..':'..diffMinutes
				if eventStamp + diffMinutes*60 >= now and not tContains(charNotifications.events, eventKey) then
					-- remove previous reminders
					for i = #charNotifications.events, 1, -1 do
						if charNotifications.events[i]:find('^'..index..':') then
							tremove(charNotifications.events, index)
						end
					end
					local notification = diffMinutes == 0 and 'Event “%2$s” for %1$s has started.' or 'Event “%2$s” for %1$s will start in %3$s minutes.'
					table.insert(charNotifications.events, eventKey)
					notifications:Print((notification):format(characterName, title, diffMinutes))
				end
			end
		end
	end
end

local function CheckGarrisonNotifications(characterKey, characterName, now)
	-- FIXME: this depends on both, DataStore AND DataMore. Not good.
	local timers = DataMore:GetModule('Timers')
	local lastUpdate = DataStore:GetModuleLastUpdateByKey(timers, characterKey)
	if not lastUpdate or now - lastUpdate > 3*24*60*60 then
		return
	end
	local charNotifications = notificationsCache[characterKey]

	local hasNewMissions = false
	for missionID, expires in DataStore:IterateGarrisonMissions(characterKey) do
		if expires <= now then
			local data = C_Garrison.GetMissionLink(missionID)
			if not tContains(charNotifications.missions, data) then
				hasNewMissions = true
				table.insert(charNotifications.missions, data)
			end
		end
	end
	if hasNewMissions then
		notifications:Print(('Garrison mission completed by %s:'):format(characterName),
			table.concat(charNotifications.missions, ', '))
	end

	local hasNewBuilds = false
	for buildingID, expires in DataStore:IterateGarrisonBuilds(characterKey) do
		if expires <= now then
			local _, data = C_Garrison.GetBuildingInfo(buildingID)
			if not tContains(charNotifications.builds, data) then
				hasNewBuilds = true
				table.insert(charNotifications.builds, data)
			end
		end
	end
	if hasNewBuilds then
		notifications:Print(('Garrison building completed by %s:'):format(characterName),
			table.concat(charNotifications.builds, ', '))
	end

	local hasNewShipments = false
	for buildingID, nextBatch, numActive, numReady, maxOrders, itemID in DataStore:IterateGarrisonShipments(characterKey) do
		numActive = numActive - numReady
		while nextBatch > 0 and numActive > 0 and nextBatch <= now do
			-- additional sets that have been completed
			numActive = numActive - 1
			numReady  = (numReady or 0) + 1
			nextBatch = nextBatch + 4*60*60
		end
		if numReady > 0 then
			local _, name = C_Garrison.GetBuildingInfo(buildingID)
			local data = ('%1$s (%2$d/%3$d of %4$s)'):format(name, numReady, numReady+numActive, maxOrders)
			if not tContains(charNotifications.shipments, data) then
				-- remove previous notifications
				for i = #charNotifications.shipments, 1, -1 do
					if charNotifications.shipments[i]:find('^'..name..' %(') then
						tremove(charNotifications.shipments, index)
					end
				end
				hasNewShipments = true
				table.insert(charNotifications.shipments, data)
			end
		end
	end
	if hasNewShipments then
		notifications:Print(('Garrison shipment has arrived for %s:'):format(characterName),
			table.concat(charNotifications.shipments, ', '))
	end
end

local function CheckNotifications(charKey)
	if type(charKey) == 'table' then charKey = nil end
	local now = time()
	for _, characterKey in pairs(addon.data.GetCharacters()) do
		if not charKey or charKey == characterKey then
			if not notificationsCache[characterKey] then
				notificationsCache[characterKey] = {
					missions  = {},
					shipments = {},
					builds    = {},
					events    = {},
				}
			end
			local characterName = addon.data.GetCharacterText(characterKey)
			CheckGarrisonNotifications(characterKey, characterName, now)
			CheckCalendarNotifications(characterKey, characterName, now)
		end
	end
	addon:GetModule('brokers'):GetModule('Notifications'):Update()
end
local function UpdateNotifications()
	for _, group in pairs(notificationsCache[thisCharacter]) do
		wipe(group)
	end
	-- CheckNotifications(thisCharacter)
end

function notifications:OnEnable()
	-- we will check for changes every 30s
	local ticker = C_Timer.NewTicker(30, CheckNotifications)
	-- and once on load
	CheckNotifications()

	hooksecurefunc(C_Garrison, 'CloseArchitect',  UpdateNotifications) -- buildings might have changed
	hooksecurefunc(C_Garrison, 'CloseMissionNPC', UpdateNotifications) -- missions might have changed
	--[[ self:RegisterEvent('GARRISON_LANDINGPAGE_SHIPMENTS', UpdateNotifications) -- garrison shipments?
	-- TODO: shipment collected, there is neither an event nor a function call :(
	self:RegisterEvent('ITEM_PUSH', function(event, count, icon)
		if not C_Garrison.IsOnGarrisonMap() then return end
		wipe(notificationsCache[thisCharacter].shipments)
	end) --]]
end
