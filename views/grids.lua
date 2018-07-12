local addonName, addon, _ = ...

-- GLOBALS: _G, CreateFrame
-- GLOBALS: FauxScrollFrame_OnVerticalScroll, FauxScrollFrame_GetOffset, FauxScrollFrame_Update

local views = addon:GetModule('views')
local plugin = views:NewModule('grids', 'AceEvent-3.0')
      plugin.icon = 'Interface\\ICONS\\INV_Misc_Net_01'
      plugin.title = 'Grids'

-- 'Interface\\Icons\\INV_Enchant_FormulaSuperior_01'
-- 'Interface\\ICONS\\ACHIEVEMENT_GUILDPERK_EVERYONES A HERO_RANK2'

local prototype = {
	Update = function(self)
		if plugin.provider == self then
			plugin:UpdateList()
		end
	end,
}
-- views modules are disabled by default, so our modules need to do the same
plugin:SetDefaultModuleState(false)
plugin:SetDefaultModulePrototype(prototype)

local emptyTable = {}

local function SourceOnClick(button, btn, up)
	for providerName, provider in plugin:IterateModules() do
		if provider.button == button then
			plugin:SelectDataSource(provider)
			break
		end
	end
end
local function CreateDataSourceButton(provider, index)
	local providerName, title, icon = provider:GetName(), provider.title, provider.icon
	local button = CreateFrame('CheckButton', '$parent' .. providerName, plugin.panel, 'PopupButtonTemplate', index)
	      button:SetNormalTexture(icon)
	      button:SetScale(0.75)
	      button.tiptext = title
	      button:SetScript('OnClick', SourceOnClick)
	      button:SetScript('OnEnter', addon.ShowTooltip)
	      button:SetScript('OnLeave', addon.HideTooltip)
	      provider.button = button
	return button
end

function plugin:SelectDataSource(provider)
	if type(provider) == 'string' then provider = self:GetModule(provider) end
	if provider ~= self.provider then
		PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
		self.provider = provider
		self:Update()
	end
end

local function CellOnClick(self, btn, up)
	local link = self.link

	if plugin.provider.OnCellClick then
		local rowIndex = self.rowIndex
		local columnIndex = self.columnIndex
		local characterKey = addon.frame.sidebar.scrollFrame[rowIndex].element

		-- Return a hyperlink to use that, or nil to stop processing.
		link = plugin.provider:OnCellClick(characterKey, columnIndex, self, btn, up)
	end

	if link and IsModifiedClick() and HandleModifiedItemClick(link) then
		return
	end
end

function plugin:SetCell(rowIndex, columnIndex, label, link, tiptext, justify)
	local panel = self.panel
	if not panel.cells then panel.cells = {} end
	if not panel.cells[rowIndex] then panel.cells[rowIndex] = {} end

	local cell = panel.cells[rowIndex][columnIndex]
	if not cell then
		cell = CreateFrame('Button', nil, panel)
		cell.rowIndex = rowIndex
		cell.columnIndex = columnIndex

		cell:SetHeight(16)
		cell:SetScript('OnEnter', addon.ShowTooltip)
		cell:SetScript('OnLeave', addon.HideTooltip)
		cell:SetScript('OnClick', CellOnClick)

		cell.text = cell:CreateFontString(nil, nil, 'GameFontNormal')
		cell.text:SetAllPoints()

		local padding = 6
		local margin = 20
		if rowIndex == 0 then
			-- Headers.
			local characterButton = addon.frame.sidebar.scrollFrame[1]
			if columnIndex == 1 then
				cell:SetPoint('BOTTOM', characterButton, 'TOP', 0, 12.5)
				cell:SetPoint('LEFT', panel, 'LEFT', margin, 0)
			else
				cell:SetPoint('BOTTOMLEFT', panel.cells[rowIndex][columnIndex - 1], 'BOTTOMRIGHT', 2*padding, 0)
			end
		else
			-- Data rows.
			local characterButton = addon.frame.sidebar.scrollFrame[rowIndex]
			cell:SetPoint('TOP', characterButton, 'TOP', 0, 0)
			cell:SetPoint('BOTTOM', characterButton, 'BOTTOM', 0, 0)
			cell:SetPoint('LEFT', panel.cells[rowIndex - 1][columnIndex], 'LEFT', 0, 0)
			cell:SetPoint('RIGHT', panel.cells[rowIndex - 1][columnIndex], 'RIGHT', 0, 0)

			if not panel.cells[rowIndex].shadow then
				local shadow = panel:CreateTexture(nil, 'BACKGROUND') -- UI-EJ-Header-Overview
				shadow:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures')
				shadow:SetTexCoord(0.359375, 0.99609375, 0.8525390625, 0.880859375)
				shadow:SetHeight(10)
				shadow:SetPoint('BOTTOMLEFT', cell, 'BOTTOMLEFT', -1 * margin, 0)
				shadow:SetPoint('RIGHT', panel, 'RIGHT')
				shadow:SetAlpha(0.5)
				panel.cells[rowIndex].shadow = shadow
			end
		end
		panel.cells[rowIndex][columnIndex] = cell
	end

	-- Update cell content.
	cell.text:SetJustifyH(justify or 'CENTER')
	cell.text:SetText(label)
	cell.link = link
	cell.tiptext = tiptext

	return cell
end

function plugin:UpdateColumnWidth(columnIndex, width)
	for column = 1, #self.panel.cells[0] do
		if not columnIndex or columnIndex == column then
			-- Calculate maximum used width.
			if not width then
				width = 0
				for row = 0, #self.panel.cells do
					local cell = self.panel.cells[row][column]
					width = math.max(width, cell and cell.text:GetStringWidth() or 0)
				end
			end
			self.panel.cells[0][column]:SetWidth(width)

			if columnIndex then
				return width
			end
		end
	end
end

function plugin:Load()
	local panel = self.panel
	panel.cells = {}

	local background = panel:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\EncounterJournal\\UI-EJ-JournalBG')
	      background:SetTexCoord(395/1024, 782/1024, 3/512, 426/512)
	      background:SetPoint('TOPLEFT', 0, -40-20)
		  background:SetPoint('BOTTOMRIGHT')

	local scrollFrame = CreateFrame('ScrollFrame', '$parentScrollFrame', panel, 'FauxScrollFrameTemplate')
	      scrollFrame:SetSize(360, 354-20)
	      scrollFrame:SetPoint('TOPLEFT', 0, -40-20-9)
	      scrollFrame:SetPoint('BOTTOMRIGHT', -24, 2)
	      scrollFrame.scrollBarHideable = true
	panel.scrollFrame = scrollFrame

	scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
		local maxWidth = self:GetParent():GetWidth() - 24
		FauxScrollFrame_OnVerticalScroll(self, offset, maxWidth / (self.numColumns or 1), function() plugin:UpdateList() end)
	end)

	hooksecurefunc(addon, 'UpdateCharacters', function()
		if plugin.panel:IsShown() then
			plugin:UpdateList()
		end
	end)

	self:RegisterMessage('TWINKLE_VIEW_CHANGED', function(event, newView, oldView)
		if oldView and oldView == 'grids' then
			-- Show previous selected character again.
			addon:UpdateCharacters()
		end
	end)
end

function plugin:OnDisable()
	--
end

function plugin:UpdateDataSources()
	local panel = self.panel

	local index = 0
	for providerName, provider in self:IterateModules() do
		if not provider:IsEnabled() then provider:Enable() end
		self.provider = self.provider or provider

		-- init data selector
		index = index + 1
		local button = _G[panel:GetName() .. provider:GetName()] or CreateDataSourceButton(provider, index)
		button:GetNormalTexture():SetDesaturated(false)
		button:ClearAllPoints()
		button:SetChecked(self.provider == provider)
		button:GetNormalTexture():SetDesaturated(false)
		panel[index] = button
		if index == 1 then
			button:SetPoint('TOPLEFT', 10, -12)
		else
			button:SetPoint('TOPLEFT', panel[index - 1], 'TOPRIGHT', 12, 0)
		end
	end
end

function plugin:UpdateList()
	local numRows = 0
	for _, button in ipairs(addon.frame.sidebar.scrollFrame) do
		numRows = numRows + (button:IsShown() and 1 or 0)

		-- Deselect any characters in the sidebar.
		button.highlight:SetVertexColor(.196, .388, .8)
		button:UnlockHighlight()
	end

	local scrollFrame  = self.panel.scrollFrame
	local offset       = FauxScrollFrame_GetOffset(scrollFrame)

	local padding = 6
	local margin = 20
	local maxWidth = self.panel:GetWidth() - (16 + 2*margin)
	local usedWidth, numUsed = 0, 0

	local numColumns = self.provider:GetNumColumns()
	for columnIndex = 1, numColumns do
		self:SetCell(0, columnIndex, self.provider:GetColumnInfo(columnIndex + offset))

		for rowIndex = 1, numRows do
			local characterKey = addon.frame.sidebar.scrollFrame[rowIndex].element
			self:SetCell(rowIndex, columnIndex, self.provider:GetCellInfo(characterKey, columnIndex + offset))
		end

		usedWidth = usedWidth + self:UpdateColumnWidth(columnIndex) + (2 * padding)
		numUsed = numUsed + 1
		if usedWidth > maxWidth then break end
	end
	scrollFrame.numColumns = numUsed

	-- Hide unused cells.
	for columnIndex = 1, #self.panel.cells[0] do
		for rowIndex = 1, #addon.frame.sidebar.scrollFrame do
			if rowIndex > numRows or columnIndex > numUsed then
				self:SetCell(rowIndex, columnIndex, nil)
			end
		end
	end

	-- Display scroll bar when necessary.
	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numColumns, numUsed, maxWidth / (numUsed or 1))
	-- adjustments so rows have decent padding with and without scroll bar
	scrollFrame:SetPoint('BOTTOMRIGHT', needsScrollBar and -24 or -12, 2)

	return numUsed or 0
end

function plugin:Update()
	self:UpdateDataSources()
	local numColumns = self:UpdateList()
	return numColumns
end
