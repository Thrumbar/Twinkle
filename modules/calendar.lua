local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, GameTooltip, CalendarFrame, CalendarEventPickerFrame, CalendarEventPickerScrollFrame, CalendarTitleFrame_SetText, CalendarFrame_CloseEvent, CalendarFrame_ShowEventFrame, CALENDAR_WEEKDAY_NAMES, FULLDATE, NORMAL_FONT_COLOR
-- GLOBALS: hooksecurefunc, IsAddOnLoaded, CalendarGetMonth, CalendarGetNumDayEvents, CalendarGetDayEvent, GameTime_GetFormattedTime, CalendarFrame_SetSelectedEvent
-- GLOBALS: print, wipe, pairs, ipairs, tonumber, string, table

local calendar = addon:NewModule('calendar', 'AceEvent-3.0')

-- DayButton constants
local CALENDAR_DAYBUTTON_MAX_VISIBLE_EVENTS   = 4
local CALENDAR_DAYBUTTON_MAX_VISIBLE_BIGEVENTS  = 2
-- date constants
local CALENDAR_FULLDATE_MONTH_NAMES = {
	_G.FULLDATE_MONTH_JANUARY,
	_G.FULLDATE_MONTH_FEBRUARY,
	_G.FULLDATE_MONTH_MARCH,
	_G.FULLDATE_MONTH_APRIL,
	_G.FULLDATE_MONTH_MAY,
	_G.FULLDATE_MONTH_JUNE,
	_G.FULLDATE_MONTH_JULY,
	_G.FULLDATE_MONTH_AUGUST,
	_G.FULLDATE_MONTH_SEPTEMBER,
	_G.FULLDATE_MONTH_OCTOBER,
	_G.FULLDATE_MONTH_NOVEMBER,
	_G.FULLDATE_MONTH_DECEMBER,
}

local statusInfo = {
	["UNKNOWN"] = {
		name    = _G.UNKNOWN,
		color   = _G.NORMAL_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_CONFIRMED] = {
		name    = _G.CALENDAR_STATUS_CONFIRMED,
		color   = _G.GREEN_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_ACCEPTED] = {
		name    = _G.CALENDAR_STATUS_ACCEPTED,
		color   = _G.GREEN_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_DECLINED] = {
		name    = _G.CALENDAR_STATUS_DECLINED,
		color   = _G.RED_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_OUT] = {
		name    = _G.CALENDAR_STATUS_OUT,
		color   = _G.RED_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_STANDBY] = {
		name    = _G.CALENDAR_STATUS_STANDBY,
		color   = _G.ORANGE_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_INVITED] = {
		name    = _G.CALENDAR_STATUS_INVITED,
		color   = _G.NORMAL_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_SIGNEDUP] = {
		name    = _G.CALENDAR_STATUS_SIGNEDUP,
		color   = _G.GREEN_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_NOT_SIGNEDUP] = {
		name    = _G.CALENDAR_STATUS_NOT_SIGNEDUP,
		color   = _G.NORMAL_FONT_COLOR,
	},
	[_G.CALENDAR_INVITESTATUS_TENTATIVE] = {
		name    = _G.CALENDAR_STATUS_TENTATIVE,
		color   = _G.ORANGE_FONT_COLOR,
	},
}
local function GetEventInfo(status)
	status = status or 'UNKNOWN'
	return statusInfo[status].color, statusInfo[status].name
end

local function DayOnEnter(self)
	local events = self.otherEvents
	if not events or #events < 1 then return end

	if not GameTooltip:IsVisible() then
		-- we only have other character's events, show header
		GameTooltip:SetOwner(self)
		GameTooltip:ClearLines()

		local weekday = (self:GetID() - 2 + _G.CALENDAR_FIRST_WEEKDAY)%7 + 1
		local month, year = CalendarGetMonth(self.monthOffset)

		GameTooltip:AddLine(string.format(FULLDATE,
			CALENDAR_WEEKDAY_NAMES[weekday], CALENDAR_FULLDATE_MONTH_NAMES[month], self.day, year, month),
			_G.HIGHLIGHT_FONT_COLOR.r, _G.HIGHLIGHT_FONT_COLOR.g, _G.HIGHLIGHT_FONT_COLOR.b)
	end

	for _, eventInfo in ipairs(events) do
		local eventColor, eventStatus = GetEventInfo(eventInfo.status)
		local hours, minutes = strsplit(':', eventInfo.time)
		GameTooltip:AddLine(' ')
		GameTooltip:AddDoubleLine(
			string.format('%s', eventInfo.title),
			GameTime_GetFormattedTime(hours, minutes, false),
			eventColor.r, eventColor.g, eventColor.b,
			_G.HIGHLIGHT_FONT_COLOR.r, _G.HIGHLIGHT_FONT_COLOR.g, _G.HIGHLIGHT_FONT_COLOR.b,
			1
		)

		GameTooltip:AddLine(string.format('%s (%s)', addon.data.GetCharacterText(eventInfo.character), eventStatus),
			NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	-- show and update tooltip
	GameTooltip:Show()
end

-- http://www.townlong-yak.com/framexml/17930/Blizzard_Calendar/Blizzard_Calendar.lua#4745
local function UpdateEventPicker()
	local dayButton = CalendarEventPickerFrame.dayButton
	local monthOffset, day = dayButton.monthOffset, dayButton.day
	local numCharacterEvents = CalendarGetNumDayEvents(monthOffset, day)

	local buttons = CalendarEventPickerScrollFrame.buttons
	for i = 1, dayButton.numViewableEvents - numCharacterEvents do
		local eventInfo = dayButton.otherEvents[i]
		local button = buttons[i] -- TODO: error handling?
		      button.eventIndex = 0
		      button.eventInfo = eventInfo
		      button:Show()

		local buttonName = button:GetName()
		local buttonIcon = _G[buttonName..'Icon']
		      buttonIcon:SetTexture()
		      buttonIcon:Show()
		local buttonTitle = _G[buttonName..'Title']
		      buttonTitle:SetFormattedText('%s (%s)', eventInfo.title, addon.data.GetCharacterText(eventInfo.character))
		local hours, minutes = strsplit(':', eventInfo.time)
		local buttonTime = _G[buttonName..'Time']
		      buttonTime:SetText(GameTime_GetFormattedTime(hours, minutes, false))
		      buttonTime:Show()
	end
end

local function UpdateHolidayFrame(eventInfo)
	-- TODO: improve this
	local title, description = _G.CalendarViewHolidayTitleFrame, _G.CalendarViewHolidayDescription
	CalendarTitleFrame_SetText(title, eventInfo.title)
	local hours, minutes = strsplit(':', eventInfo.time)
	description:SetFormattedText('%s has this event in their agenda for %s.',
		addon.data.GetCharacterText(eventInfo.character),
		GameTime_GetFormattedTime(hours, minutes, false)
	)
end
local function EventOnClick(self, btn)
	if self.eventIndex == 0 then
		CalendarFrame_CloseEvent()
		CalendarFrame_SetSelectedEvent(self)
		CalendarFrame_ShowEventFrame(_G.CalendarViewHolidayFrame)
		UpdateHolidayFrame(self.eventInfo)
	end
end

local function UpdateEventTextPositions(eventButton, showingBigEvents)
	local eventButtonName = eventButton:GetName()

	local timeText = _G[eventButtonName..'Text2']
		  timeText:ClearAllPoints()
		  timeText:Show()

	if showingBigEvents then
		timeText:SetPoint('BOTTOMLEFT')
		timeText:SetJustifyH('LEFT')
	else
		timeText:SetPoint('RIGHT')
		timeText:SetJustifyH('RIGHT')
	end

	local titleText = _G[eventButtonName..'Text1']
	      titleText:ClearAllPoints()
	      titleText:SetPoint('TOPLEFT')
	      titleText:Show()

	if not showingBigEvents then
		titleText:SetPoint('BOTTOMRIGHT', timeText, 'BOTTOMLEFT')
	end

	return titleText, timeText
end

local function AddDayEvent(dayButtonName, eventInfo)
	local dayButton = _G[dayButtonName]
	local numEvents = dayButton.numViewableEvents or 0
	local eventNum = numEvents + 1

	-- we now display more events than before
	dayButton.numViewableEvents = eventNum

	if eventNum > CALENDAR_DAYBUTTON_MAX_VISIBLE_EVENTS then
		_G[dayButtonName..'MoreEventsButton']:Show()
		return
	end

	if eventNum == CALENDAR_DAYBUTTON_MAX_VISIBLE_BIGEVENTS + 1 then
		-- this custom event causes all other displayed events to be small
		for i = 1, numEvents do
			local eventButton = _G[dayButtonName..'EventButton'..i]
			eventButton:SetHeight(12)
			UpdateEventTextPositions(eventButton, false)
		end
	end

	local showingBigEvents = eventNum <= CALENDAR_DAYBUTTON_MAX_VISIBLE_BIGEVENTS
	local buttonHeight = showingBigEvents and 24 or 12

	local eventButtonName  = dayButtonName..'EventButton'..eventNum
	local eventButton = _G[eventButtonName]
	      eventButton.eventIndex = 0
	      eventButton.eventInfo = eventInfo
	      eventButton:SetHeight(buttonHeight)
	      eventButton:Show()

	-- update event texts
	local titleText, timeText = UpdateEventTextPositions(eventButton, showingBigEvents)
	local eventColor, eventStatus = GetEventInfo(eventInfo.eventStatus)
	local hours, minutes = strsplit(':', eventInfo.time)
	titleText:SetFormattedText('%s', eventInfo.title)
	titleText:SetTextColor(eventColor.r, eventColor.g, eventColor.b)
	timeText:SetText(GameTime_GetFormattedTime(hours, minutes, false))

	-- anchor event button
	eventButton:SetPoint('BOTTOMLEFT', '$parent', 'BOTTOMLEFT', 4, 3)
	if eventNum == 1 then
		dayButton.firstEventButton = eventButton
		-- TODO update day textures Blizzard_Calendar/Blizzard_Calendar.lua#1472

		-- anchor the top of the event background to first event button, it's always on top
		local eventBackground = _G[dayButtonName..'EventBackgroundTexture']
		eventBackground:SetPoint('TOP', eventButton, 'TOP', 0, 40)
		eventBackground:SetPoint('BOTTOM')
		eventBackground:Show()

	elseif eventNum > 1 then
		-- move previous event up one slot
		_G[dayButtonName..'EventButton'..(eventNum - 1)]:SetPoint('BOTTOMLEFT', eventButton, 'TOPLEFT', 0, 3)
	end
end

local function EventSort(a, b)
	if a.time ~= b.time then
		return a.time < b.time
	elseif a.character ~= b.character then
		return a.character < b.character
	else
		return a.eventIndex < b.eventIndex
	end
end

local characters = {} -- filled on load
local thisCharacter   -- filled on load
-- TODO: resolve dependency on DataStore_Agenda - move to data.lua
local function UpdateDayEvents(index, day, monthOffset, selectedEventIndex, contextEventIndex)
	if not DataStore:GetMethodOwner('GetCalendarEventInfo') or not DataStore:GetMethodOwner('GetNumCalendarEvents') then return end
	local month, year = CalendarGetMonth(monthOffset)
	local thisDate = string.format("%04d-%02d-%02d", year, month, day)

	local dayButtonName = 'CalendarDayButton'..index
	local dayButton = _G[dayButtonName]

	-- stores other character's events for this day. won't change while logged in
	if dayButton.otherEvents then
		wipe(dayButton.otherEvents)
	else
		dayButton.otherEvents = {}
	end

	for _, character in pairs(characters) do
		if character ~= thisCharacter then
			for i = 1, DataStore:GetNumCalendarEvents(character) do
				local eventDate, eventTime, title, eventType, inviteStatus  = DataStore:GetCalendarEventInfo(character, i)
				if eventDate == thisDate then
					table.insert(dayButton.otherEvents, {
						character = character,
						eventIndex = i,
						time = eventTime,
						title = title,
						type = eventType,
						status = tonumber(inviteStatus),
					})
				end
			end
		end
	end
	table.sort(dayButton.otherEvents, EventSort)

	for i, eventInfo in ipairs(dayButton.otherEvents) do
		AddDayEvent(dayButtonName, eventInfo)
	end
end

function calendar:OnInitialize()
	if not IsAddOnLoaded('Blizzard_Calendar') then
		-- registering ADDON_LOADED in OnEnable fails, so we need to do so here
		self:RegisterEvent('ADDON_LOADED', function(event, arg1)
			if arg1 == 'Blizzard_Calendar' then
				self:UnregisterEvent('ADDON_LOADED')
				self:OnEnable()
			end
		end)
		return
	end
end
function calendar:OnEnable()
	-- delay loading until calendar is ready
	if not IsAddOnLoaded('Blizzard_Calendar') then return end

	-- fill characters table
	addon.data.GetCharacters(characters)
	thisCharacter = addon.data.GetCurrentCharacter()

	hooksecurefunc('CalendarFrame_UpdateDayEvents', UpdateDayEvents)
	hooksecurefunc('CalendarDayButton_OnEnter', DayOnEnter)
	hooksecurefunc('CalendarDayEventButton_OnClick', EventOnClick)

	hooksecurefunc('CalendarEventPickerScrollFrame_Update', UpdateEventPicker)
	hooksecurefunc('CalendarEventPickerButton_OnClick', function(self)
		if self.eventIndex == 0 and not CalendarFrame.selectedEventButton then
			-- clicked on custom event that's not shown in calendar
			CalendarFrame_ShowEventFrame(_G.CalendarViewHolidayFrame)
			UpdateHolidayFrame(self.eventInfo)
		end
	end)
end
function calendar:OnDisable()
	self:UnregisterEvent('ADDON_LOADED')
end
