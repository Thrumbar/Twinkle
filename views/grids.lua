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

	return numDataRows
end

function plugin:OnEnable()
	local panel = self.panel

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

	local leftButton = panel:CreateFontString('$parentText', 'ARTWORK', 'GameFontNormalRight')
	      leftButton:SetPoint('TOPLEFT', 4, -40-4.5)
	panel.leftButton = leftButton

	local numRows, numColumns = 11, 3
	local columnWidth = scrollFrame:GetWidth()/numColumns
	panel.leftButton:SetText('Header text')

	for index = 1, numRows do
		local row = CreateFrame('Button', nil, panel, nil, index)
		      row:SetHeight(30)
		      row:Hide()

		row:SetPoint('RIGHT', scrollFrame, 'RIGHT', 0, 0)
		if index == 1 then
			row:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 8, 0)
		else
			row:SetPoint('TOPLEFT', scrollFrame[index - 1], 'BOTTOMLEFT', 0, 0)
		end

    	local shadow = row:CreateTexture(nil, 'BACKGROUND') -- UI-EJ-Header-Overview
    	      shadow:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures')
    	      shadow:SetTexCoord(0.359375, 0.99609375, 0.8525390625, 0.880859375)
    	      shadow:SetSize(320, 10)
    	      shadow:SetPoint('BOTTOM')
    	      shadow:SetAlpha(0.5)
    	row.shadow = shadow

		local highlight = row:CreateTexture(nil, 'HIGHLIGHT')
		      highlight:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures')
		      highlight:SetTexCoord(0.63085938, 0.88085938, 0.58886719, 0.61523438)
		      highlight:SetDesaturated(true)
		      highlight:SetVertexColor(230/255, 100/255, 60/255, 0.66)
		      highlight:SetAllPoints()
		row:SetHighlightTexture(highlight, 'BLEND')

		row:SetScript('OnEnter', function(self) self.label:SetFontObject('GameFontHighlight') end)
		row:SetScript('OnLeave', function(self) self.label:SetFontObject('GameFontNormal') end)
		-- row:SetScript('OnClick', OnRowClick)

		local label = row:CreateFontString(nil, nil, 'GameFontNormal')
			  label:SetPoint('LEFT', 0, 0)
			  label:SetWidth(200)
			  label:SetHeight(row:GetHeight())
			  label:SetJustifyH('LEFT')
		row.label = label

		for i = 1, numColumns do
			local cell = row:CreateFontString(nil, nil, 'GameFontNormal')
				  cell:SetPoint('LEFT', i > 1 and row[i-1] or row.label, 'RIGHT', 0, 0)
				  cell:SetWidth(columnWidth)
				  cell:SetHeight(row:GetHeight())
				  cell:SetJustifyH('LEFT')
			row[i] = cell
		end

		scrollFrame[index] = row
	end
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
