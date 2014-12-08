local addonName, addon, _ = ...

-- GLOBALS: _G
-- TODO: sort lockouts
-- TODO: SHIFT-click to post lockoutLink to chat
-- TODO: display defeated/available bosses OnEnter

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Notifications')

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

local function NOOP() end -- do nothing
local instanceLinks = {}
function broker:UpdateTooltip()
	local numColumns = 2
	self:SetColumnLayout(numColumns, 'LEFT')

	local lineNum -- = self:AddHeader()
	-- self:SetCell(lineNum, 1, addonName .. ': Notifications', 'LEFT', numColumns)

	local allNotifications = addon:GetModule("Notifications"):GetSentNotifications()
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local notifications = allNotifications[characterKey]
		local numNotifications = 0
		for _, group in pairs(notifications) do
			numNotifications = numNotifications + #group
		end
		if numNotifications > 0 then
			local characterName = addon.data.GetCharacterText(characterKey)
			lineNum = self:AddHeader(characterName)
			self:AddSeparator(2)

			for i, event in ipairs(notifications.events) do
				local index, startsIn = strsplit(':', event)
				local eventDate, eventTime, title, eventType, inviteStatus = DataStore:GetCalendarEventInfo(characterKey, index*1)
				local notification = startsIn == '0' and '“%2$s” has started.' or '“%2$s” starts in %3$s minutes.'
				lineNum = self:AddLine('Event', (notification):format(characterName, title, startsIn))
				self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
			end
			for i, buildingName in ipairs(notifications.builds) do
				local notification = '%2$s has been completed.'
				lineNum = self:AddLine('Building', (notification):format(characterName, buildingName))
				self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
			end
			for i, data in ipairs(notifications.shipments) do
				local notification = 'Shipment at %2$s has arrived.'
				lineNum = self:AddLine('Work Order', (notification):format(characterName, data))
				self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
			end
			-- for i, missionLink in ipairs(notifications.missions) do
			if #notifications.missions > 0 then
				-- local notification = '“%2$s” has been completed.'
				local notification = '%3$d |4mission has:missions have; been completed.'
				lineNum = self:AddLine('Mission', (notification):format(characterName, missionLink, #notifications.missions))
				self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
			end
		end
	end

	if not lineNum then return true end
end
