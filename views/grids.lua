local addonName, addon, _ = ...

-- GLOBALS: _G, CreateFrame
-- GLOBALS: FauxScrollFrame_OnVerticalScroll, FauxScrollFrame_GetOffset, FauxScrollFrame_Update

local views = addon:GetModule('views')
local lists  = views:GetModule('lists')
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

	local maxWidth = self.panel:GetWidth() - 24
	local usedWidth, numUsed = 0, 0
	local padding = 4

	local numColumns = self:GetNumColumns()
	local numRows = #addon.frame.sidebar.scrollFrame
	for columnIndex = 1, numColumns do
		local columnLabel = self:GetColumnLabel(columnIndex + offset)
		self:AddColumn(columnIndex, columnLabel)
		for rowIndex = 1, numRows do
			local characterKey = addon.frame.sidebar.scrollFrame[rowIndex].element
			local cellContent, justify = self:GetCellContent(characterKey, columnIndex + offset)
			self:SetCell(rowIndex, columnIndex, cellContent, justify)
		end

		usedWidth = usedWidth + self:UpdateColumnWidth(columnIndex) + (2 * padding)
		if usedWidth > maxWidth then break end
		numUsed = numUsed + 1
	end
	scrollFrame.numColumns = numUsed

	-- Hide unused columns.
	for columnIndex = numUsed + 1, #self.panel.cells[0] do
		for rowIndex = 0, numRows do
			self:SetCell(rowIndex, columnIndex, nil)
		end
	end

	-- Display scroll bar when necessary.
	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numColumns, numUsed, maxWidth / (numUsed or 1))
	-- adjustments so rows have decent padding with and without scroll bar
	scrollFrame:SetPoint('BOTTOMRIGHT', needsScrollBar and -24 or -12, 2)

	return numDataRows or 0
end

function plugin:AddColumn(columnIndex, label)
	return self:SetCell(0, columnIndex, label)
end

function plugin:SetCell(rowIndex, columnIndex, label, justify)
	local panel = self.panel
	if not panel.cells then panel.cells = {} end
	if not panel.cells[rowIndex] then panel.cells[rowIndex] = {} end

	local cell = panel.cells[rowIndex][columnIndex]
	if not cell then
		cell = panel:CreateFontString(nil, nil, 'GameFontNormal')
		if rowIndex == 0 then
			-- Headers.
			local padding = 4
			local characterButton = addon.frame.sidebar.scrollFrame[1]
			if columnIndex == 1 then
				cell:SetPoint('BOTTOM', characterButton, 'TOP', 0, 12.5)
				cell:SetPoint('LEFT', panel, 'LEFT', padding, 0)
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

	if justify then
		cell:SetJustifyH(justify)
	end

	-- Update cell content.
	cell:SetText(label)

	return cell
end

function plugin:UpdateColumnWidth(columnIndex, width)
	for column = 1, #self.panel.cells[0] do
		if not columnIndex or columnIndex == column then
			-- Calculate maximum used width.
			if not width then
				width = 0
				for row = 0, #self.panel.cells do
					width = math.max(width, self.panel.cells[row][column]:GetStringWidth())
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
end

function plugin:OnDisable()
	--
end

function plugin:Update()
	local numRows = self:UpdateList()
	return numRows
end

--[[
	Temporary helper functions.
--]]
function plugin:GetNumColumns()
	local count = 0
	count = count + 3 -- bags
	count = count + 6 -- professions
	count = count + addon.data.GetNumCurrencies()

	return count
end

function plugin:GetColumnLabel(columnIndex)
	local characterKey = addon.data.GetCurrentCharacter()
	local plugin, count

	-- Bag space.
	count = 3
	if columnIndex <= count then
		return (columnIndex == 1 and 'Bag Slots')
			or (columnIndex == 2 and 'Used')
			or (columnIndex == 3 and 'Free')
	end
	columnIndex = columnIndex - count

	-- Professions.
	count = 6
	if columnIndex <= count then
		return (columnIndex == 1 and 'Prof 1')
			or (columnIndex == 2 and 'Prof 2')
			or (columnIndex == 3 and 'Arch')
			or (columnIndex == 4 and 'Fish')
			or (columnIndex == 5 and 'Cook')
			or (columnIndex == 6 and 'Aid')
	end
	columnIndex = columnIndex - count

	-- Currencies.
	count = addon.data.GetNumCurrencies()
	if columnIndex <= count then
		-- Negative index => global list index.
		local _, name, _, icon, _, currencyID = addon.data.GetCurrencyInfoByIndex(characterKey, -1 * columnIndex)
		return icon and ('|T' .. icon .. ':0|t') or ''
	end
	columnIndex = columnIndex - count

	return 'Col ' .. columnIndex
end

function plugin:GetCellContent(characterKey, columnIndex)
	local plugin, count

	-- Bag space.
	count = 3
	if columnIndex <= count then
		local total, free = 0, 0
		for container = 0, _G.NUM_BAG_SLOTS do
			local bagTotal, bagFree = addon.data.GetContainerInfo(characterKey, container)
			total = total + bagTotal
			free = free + bagFree
		end
		if columnIndex == 1 then
			return total
		elseif columnIndex == 2 then
			return total - free
		else
			return free
		end
	end
	columnIndex = columnIndex - count

	-- Professions.
	count = 6
	if columnIndex <= count then
		local profession = select(columnIndex, addon.data.GetProfessions(characterKey))
		if profession then
			local name, icon, rank, maxRank, skillLine, spellID, specSpellID = addon.data.GetProfessionInfo(characterKey, profession)
			if name then
				return string.format('|T%s:0|t %s', icon, rank)
			end
		end
		return '-'
	end
	columnIndex = columnIndex - count

	-- Currencies.
	count = addon.data.GetNumCurrencies()
	if columnIndex <= count then
		-- Negative index => global list index.
		local _, name, count, icon, _, currencyID = addon.data.GetCurrencyInfoByIndex(characterKey, -1 * columnIndex)
		return count or '-'
	end
	columnIndex = columnIndex - count

	return '...'
end
