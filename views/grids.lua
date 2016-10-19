local addonName, addon, _ = ...

-- GLOBALS: _G, CreateFrame
-- GLOBALS: FauxScrollFrame_OnVerticalScroll, FauxScrollFrame_GetOffset, FauxScrollFrame_Update

local views = addon:GetModule('views')
local plugin = views:NewModule('Grids')
      plugin.icon = 'Interface\\ICONS\\INV_Misc_Net_01'
      plugin.title = 'Grids'

-- 'Interface\\Icons\\INV_Enchant_FormulaSuperior_01'
-- 'Interface\\ICONS\\ACHIEVEMENT_GUILDPERK_EVERYONES A HERO_RANK2'

local emptyTable = {}

function plugin:UpdateList()
	local characterKey = addon:GetSelectedCharacter()
	local scrollFrame  = self.panel.scrollFrame
	local offset       = FauxScrollFrame_GetOffset(scrollFrame)

	for columnIndex = 1, 2 do
		self:AddColumn(columnIndex, 'Col ' .. columnIndex)
		for rowIndex, characterButton in ipairs(addon.frame.sidebar.scrollFrame) do
			self:AddCell(rowIndex, columnIndex, string.format('%dx%d', rowIndex, columnIndex))
		end
	end

	self:UpdateColumnWidth(nil, nil, 10)

	--[[
	local buttonIndex = 1
	local numRows, numDataRows = 11, 11
	for index = 1, numRows do
		if index >= offset+1 then
			local button = scrollFrame[buttonIndex]
			if button then
				button:SetID(index)

				-- TODO: update row values

				button.label:SetText('Row ' .. index)
				button:Show()
				buttonIndex = buttonIndex + 1
			end
		end
	end

	-- hide empty rows
	for index = buttonIndex, #scrollFrame do
		local button = scrollFrame[index]
		      button:Hide()
	end

	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numRows, #scrollFrame, scrollFrame[1]:GetHeight())
	-- adjustments so rows have decent padding with and without scroll bar
	scrollFrame:SetPoint('BOTTOMRIGHT', needsScrollBar and -24 or -12, 2)
	--]]

	return numDataRows or 0
end

function plugin:AddColumn(columnIndex, label)
	return self:AddCell(0, columnIndex, label)
end

function plugin:AddCell(rowIndex, columnIndex, label)
	local panel = self.panel
	if not panel.cells then panel.cells = {} end
	if not panel.cells[rowIndex] then panel.cells[rowIndex] = {} end

	local cell = panel.cells[rowIndex][columnIndex]
	if not cell then
		cell = panel:CreateFontString(nil, nil, 'GameFontNormal')
		if rowIndex == 0 then
			local characterButton = addon.frame.sidebar.scrollFrame[1]
			if columnIndex == 1 then
				cell:SetPoint('BOTTOM', characterButton, 'TOP', 0, 10)
				cell:SetPoint('LEFT', panel, 'LEFT', 2, 0)
			else
				cell:SetPoint('BOTTOMLEFT', panel.cells[rowIndex][columnIndex - 1], 'BOTTOMRIGHT', 2, 0)
			end
		else
			local characterButton = addon.frame.sidebar.scrollFrame[rowIndex]
			cell:SetPoint('TOP', characterButton, 'TOP', 0, 0)
			cell:SetPoint('BOTTOM', characterButton, 'BOTTOM', 0, 0)
			cell:SetPoint('LEFT', panel.cells[rowIndex - 1][columnIndex], 'LEFT', 0, 0)
			cell:SetPoint('RIGHT', panel.cells[rowIndex - 1][columnIndex], 'RIGHT', 0, 0)

			if columnIndex == 1 then
				local shadow = panel:CreateTexture(nil, 'BACKGROUND') -- UI-EJ-Header-Overview
				shadow:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures')
				shadow:SetTexCoord(0.359375, 0.99609375, 0.8525390625, 0.880859375)
				shadow:SetHeight(10)
				shadow:SetPoint('BOTTOMLEFT', cell, 'BOTTOMLEFT')
				shadow:SetPoint('RIGHT', panel, 'RIGHT')
				shadow:SetAlpha(0.5)
				panel.cells[rowIndex].shadow = shadow
			end
		end
		panel.cells[rowIndex][columnIndex] = cell
	end

	-- Update cell content.
	cell:SetText(label or '')

	return cell
end

function plugin:UpdateColumnWidth(columnIndex, width, padding)
	for column = 1, #self.panel.cells[0] do
		if not columnIndex or columnIndex == column then
			-- Calculate maximum used width.
			if not width then
				width = 0
				for row = 0, #self.panel.cells do
					width = math.max(width, self.panel.cells[row][column]:GetStringWidth())
				end
			end
			self.panel.cells[0][column]:SetWidth(width + (padding or 0))
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
		local buttonHeight = self[1]:GetHeight()
		FauxScrollFrame_OnVerticalScroll(self, offset, buttonHeight, function() plugin:UpdateList() end)
	end)
end

function plugin:OnDisable()
	--
end

function plugin:Update()
	-- local characterKey = addon:GetSelectedCharacter()
	-- local equipmentSets = DataStore:GetEquipmentSetNames(characterKey)
	local numRows = self:UpdateList()
	return numRows
end
