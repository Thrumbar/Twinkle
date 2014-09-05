local addonName, addon, _ = ...

-- GLOBALS: _G
-- TODO: sort lockouts
-- TODO: SHIFT-click to post lockoutLink to chat
-- TODO: display defeated/available bosses OnEnter

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Lockouts')

local instanceLockouts = {}
local function GetCharacterInstanceLockouts(characterKey)
	local hasData = nil
	wipe(instanceLockouts)

	-- DataStore:IsEncounterDefeated()
	for lockoutID, lockoutLink in DataStore:IterateInstanceLockouts(characterKey) do
		hasData = true
		local instanceName, difficulty, instanceReset, isExtended, isRaid, numDefeated, numBosses = DataStore:GetInstanceLockoutInfo(characterKey, lockoutID)
		local color = (instanceReset == 0 and _G.GRAY_FONT_COLOR_CODE)
			or (numDefeated > 0 and _G.GREEN_FONT_COLOR_CODE)
			or _G.NORMAL_FONT_COLOR_CODE
		local rowText = string.format('%s%d/%d|r', color, numDefeated, numBosses)
		table.insert(instanceLockouts, rowText)
	end
	return hasData and instanceLockouts or nil
end

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
	-- self.text = 'foo'
end

local function NOOP() end -- do nothing
function broker:UpdateTooltip()
	local numColumns = 5
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': ' .. _G.RAID, 'LEFT', numColumns)
	-- self:AddSeparator(2)

	-- _G.ERR_LOOT_GONE
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local data = GetCharacterInstanceLockouts(characterKey, true)
		if data then
			lineNum = self:AddLine(addon.data.GetCharacterText(characterKey),  unpack(data))
			self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
		end
	end
end
