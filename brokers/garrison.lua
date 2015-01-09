local addonName, addon, _ = ...

-- GLOBALS: _G

local brokers = addon:GetModule('brokers')
local broker  = brokers:NewModule('Garrison')

--[[
local DataStore_Garrisons_PublicMethods = {
	GetFollowers = _GetFollowers,
	GetFollowerInfo = _GetFollowerInfo,
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

local function NOOP() end -- do nothing
local instanceLinks = {}
function broker:UpdateTooltip()
	local numColumns = 2
	self:SetColumnLayout(numColumns, 'LEFT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': Garrisons', 'LEFT', numColumns)

	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local characterName = addon.data.GetCharacterText(characterKey)
		-- lineNum = self:AddHeader(characterName)
		-- self:AddSeparator(2)

		-- lineNum = self:AddLine('Event', (notification):format(characterName, title, startsIn))
		-- self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
	end
	if not lineNum then return true end
end
