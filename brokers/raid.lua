local addonName, ns, _ = ...
local moduleName = 'Raid'

-- GLOBALS:

local LDB     = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-1.0')

local characters = {}
local thisCharacter = ns.data.GetCurrentCharacter()

-- ========================================================
--  Gather data
-- ========================================================

-- ========================================================
--  Display data
-- ========================================================

-- ========================================================
--  LDB Display & Sorting
-- ========================================================
-- forward declaration
local OnLDBEnter = function() end

local tooltip
local function NOOP() end -- does nothing
OnLDBEnter = function(self)
	local numColumns = 2 -- (#showCurrency * 2) + 1
	if LibStub('LibQTip-1.0'):IsAcquired(addonName..moduleName) then
		tooltip:Clear()
	else
		tooltip = LibQTip:Acquire(addonName..moduleName, numColumns, 'LEFT', strsplit(',', string.rep('RIGHT,', numColumns-1)))
		tooltip:SmartAnchorTo(self)
		tooltip:SetAutoHideDelay(0.25, self)
		tooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	local lineNum
	lineNum = tooltip:AddHeader()
			  tooltip:SetCell(lineNum, 1, addonName .. ': ' .. _G.RAID, 'LEFT', numColumns)
	-- tooltip:AddSeparator(2)

	--[[
	lineNum = tooltip:AddLine(_G.CHARACTER, GetCurrencyHeaders())
	for column = 1, numColumns do
		-- make list sortable
		tooltip:SetCellScript(lineNum, column, 'OnMouseUp', SortCurrencyList, column-1)
		if column%2 == 0 then
			-- show tooltip for currency headers
			local cell = tooltip.lines[lineNum].cells[column]
			      cell.link = 'currency:'..showCurrency[column/2]
			tooltip:SetCellScript(lineNum, column, 'OnEnter', ns.ShowTooltip, tooltip)
			tooltip:SetCellScript(lineNum, column, 'OnLeave', ns.HideTooltip, tooltip)
		end
	end
	tooltip:AddSeparator(2)

	for _, characterKey in ipairs(characters) do
		local data = GetCurrencyCounts(characterKey, true)
		if data then
			lineNum = tooltip:AddLine( ns.data.GetCharacterText(characterKey),  unpack(data))
			tooltip:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
		end
	end
	--]]

	tooltip:Show()
end

local function Update(self)
	local ldb = LDB:GetDataObjectByName(addonName..moduleName)
	if ldb then
		ldb.text = nil
	end

	-- update tooltip, if shown
	if LibQTip:IsAcquired(addonName..moduleName) then
		OnLDBEnter(self)
	end
end

local function OnLDBClick(self, btn, down)
	-- ToggleCharacter("TokenFrame")
end

-- ========================================================
--  Setup
-- ========================================================
ns.RegisterEvent('ADDON_LOADED', function(frame, event, arg1)
	if arg1 == addonName then
		LDB:NewDataObject(addonName..moduleName, {
			type	= 'data source',
			label	= _G.RAID,
			-- text 	= CURRENCY,
			-- icon    = 'Interface\\Icons\\Spell_Holy_EmpowerChampion',

			OnClick = OnLDBClick,
			OnEnter = OnLDBEnter,
			OnLeave = function() end,	-- needed for e.g. NinjaPanel
		})

		-- fill character list
		characters = ns.data.GetCharacters(characters)

		ns.UnregisterEvent('ADDON_LOADED', 'raid')
	end
end, 'raid')

-- ns.RegisterEvent('CURRENCY_DISPLAY_UPDATE', Update, 'weekly_update')
