local addonName, addon, _ = ...

-- GLOBALS: _G
-- TODO: sort lockouts
-- TODO: SHIFT-click to post lockoutLink to chat
-- TODO: display defeated/available bosses OnEnter

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Lockouts')

local function GetInstanceLockouts(characterKey, difficulty, instanceName)
	local numDefeated, numBosses, hasID, link = 0, 0, nil, nil
	for lockoutID, lockoutLink in DataStore:IterateInstanceLockouts(characterKey) do
		local name, diff, reset, _, _, defeated, bosses = DataStore:GetInstanceLockoutInfo(characterKey, lockoutID)
		if diff == difficulty and name == instanceName then
			numDefeated = numDefeated + defeated
			numBosses   = numBosses + bosses
			hasID       = reset ~= 0
			link        = lockoutLink
		end
	end
	return numDefeated, numBosses, hasID, link
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
local instanceLinks = {}
function broker:UpdateTooltip()
	local numColumns = 4
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': ' .. _G.RAID, 'LEFT', numColumns)
	self:AddSeparator(2)

	-- GetNumRFDungeons(), GetRFDungeonInfo(index)
	-- GetNumFlexRaidDungeons(), GetFlexRaidDungeonInfo(index)

	lineNum = self:AddHeader('Character', 'Normal', 'Heroic', 'Mythic')
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local instanceName = 'Schlacht um Orgrimmar'
		local statusFormat, totalDefeated = '%s%d/%d|r', 0
		local numDefeated, numBosses, hasID, color, instanceLink
		wipe(instanceLinks)

		-- FIXME: chinese have separate lockous for 10/25
		numDefeated, numBosses, hasID, instanceLink = GetInstanceLockouts(characterKey, 14, instanceName)
		color = (not hasID and numDefeated > 0 and _G.GRAY_FONT_COLOR_CODE)
			or (numDefeated > 0 and _G.GREEN_FONT_COLOR_CODE)
			or _G.NORMAL_FONT_COLOR_CODE
		local nhc = string.format(statusFormat, color, numDefeated, numBosses)
		table.insert(instanceLinks, instanceLink or '')
		totalDefeated = totalDefeated + numDefeated

		numDefeated, numBosses, hasID, instanceLink = GetInstanceLockouts(characterKey, 15, instanceName)
		color = (not hasID and numDefeated > 0 and _G.GRAY_FONT_COLOR_CODE)
			or (numDefeated > 0 and _G.GREEN_FONT_COLOR_CODE)
			or _G.NORMAL_FONT_COLOR_CODE
		local hc = string.format(statusFormat, color, numDefeated, numBosses)
		table.insert(instanceLinks, instanceLink or '')
		totalDefeated = totalDefeated + numDefeated

		numDefeated, numBosses, hasID, instanceLink = GetInstanceLockouts(characterKey, 16, instanceName)
		color = (not hasID and numDefeated > 0 and _G.GRAY_FONT_COLOR_CODE)
			or (numDefeated > 0 and _G.GREEN_FONT_COLOR_CODE)
			or _G.NORMAL_FONT_COLOR_CODE
		local mc = string.format(statusFormat, color, numDefeated, numBosses)
		table.insert(instanceLinks, instanceLink or '')
		totalDefeated = totalDefeated + numDefeated

		if totalDefeated > 0 then
			lineNum = self:AddLine(addon.data.GetCharacterText(characterKey), nhc, hc, mc)
			self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
			for column = 2, numColumns do
				local instanceLink = instanceLinks[column - 1]
				if instanceLink ~= '' then
					local cell = self.lines[lineNum].cells[column]
					      cell.link = instanceLink
					self:SetCellScript(lineNum, column, 'OnEnter', addon.ShowTooltip, self)
					self:SetCellScript(lineNum, column, 'OnLeave', addon.HideTooltip, self)
				end
			end
		end
	end
end
