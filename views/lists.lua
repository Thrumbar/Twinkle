local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: CreateFrame, IsModifiedClick, HandleModifiedItemClick, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, FauxScrollFrame_OnVerticalScroll
-- GLOBALS: ipairs

local views = addon:GetModule('views')
local lists = views:NewModule('lists', 'AceEvent-3.0')
      lists.icon = 'Interface\\Icons\\INV_Scroll_02' -- grids: Ability_Ensnare
      lists.title = 'Lists'

local function OnRowClick(self, btn, up)
	if not self.link then
		return
	elseif IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	elseif lists.provider.OnClickRow then
		lists.provider.OnClickRow(self, btn, up)
	end
end

local function OnButtonClick(self, btn, up)
	if not self.link then
		return
	elseif IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	elseif lists.provider.OnClickItem then
		lists.provider.OnClickItem(self, btn, up)
	end
end

local function UpdateList()
	local self = lists
	local characterKey = addon.GetSelectedCharacter()
	local numRows = self.provider.GetNumRows(characterKey)

	local scrollFrame = self.panel.scrollFrame
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	for i, button in ipairs(scrollFrame) do
		local index = i + offset
		if index <= numRows then
			local isHeader, title, link, prefix, suffix = self.provider.GetRowInfo(characterKey, index)
			local isCollapsed = false -- TODO: store

			button:SetText(title)
			button.link = link

			if isHeader then
				local texture = isCollapsed and 'UI-PlusButton-UP' or 'UI-MinusButton-UP'
				button:SetNormalTexture('Interface\\Buttons\\'..texture)
				button:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight')
				button.prefix:SetText('')
				button.suffix:SetText('')
			else
				button:SetNormalTexture('')
				button:SetHighlightTexture('')
				button.prefix:SetText(prefix or '')
				button.suffix:SetText(suffix or '')
			end

			-- we can display associated icons, e.g. quest rewards or crafting reagents
			for itemIndex, itemButton in ipairs(button) do
				local icon, link, tiptext = self.provider.GetItemInfo(characterKey, index, itemIndex)
				if icon then
					itemButton.icon:SetTexture(icon)
					itemButton.link = link
					itemButton.tiptext = tiptext
					itemButton:Show()
				else
					itemButton:Hide()
				end
			end
		else
			-- hide empty rows
			button:SetNormalTexture('')
			button:SetHighlightTexture('')
			button:SetText('')
			button.prefix:SetText('')
			button.suffix:SetText('')
			button.link = nil

			for itemIndex, itemButton in ipairs(button) do
				itemButton:Hide()
			end
		end
	end

	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numRows, #scrollFrame, 20)
	-- scrollFrame:SetPoint('BOTTOMRIGHT', -10+(needsScrollBar and -14 or 0), 2)
end

function lists:OnEnable()
	for name, subModule in self:IterateModules() do
		self.provider = subModule
		break
	end

	local panel = self.panel
	local background = panel:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\TALENTFRAME\\spec-paper-bg')
	      background:SetTexCoord(0, 0.76, 0, 0.86)
	      background:SetPoint('TOPLEFT', 0, -40)
		  background:SetPoint('BOTTOMRIGHT')

	local scrollFrame = CreateFrame('ScrollFrame', '$parentScrollFrame', panel, 'FauxScrollFrameTemplate')
	      scrollFrame:SetSize(360, 354)
	      scrollFrame:SetPoint('TOPLEFT', 0, -40-6)
	      scrollFrame:SetPoint('BOTTOMRIGHT', -24, 2)
	      scrollFrame.scrollBarHideable = true
	panel.scrollFrame = scrollFrame

	scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, 20, UpdateList)
	end)

	for index = 1, 17 do
		local row = CreateFrame('Button', '$parentRow'..index, panel, nil, index)
		      row:SetHeight(20)
		scrollFrame[index] = row

		if index == 1 then
			row:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 10, -4)
		else
			row:SetPoint('TOPLEFT', scrollFrame[index - 1], 'BOTTOMLEFT')
		end
		row:SetPoint('RIGHT', scrollFrame, 'RIGHT')
		row:SetScript('OnEnter', addon.ShowTooltip)
		row:SetScript('OnLeave', addon.HideTooltip)
		row:SetScript('OnClick', OnRowClick)

		row:SetNormalTexture('Interface\\Buttons\\UI-MinusButton-UP')
		local tex = row:GetNormalTexture()
		      tex:SetSize(16, 16)
		      tex:ClearAllPoints()
		      tex:SetPoint('LEFT', 3, 0)
		row:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight', 'ADD')
		local tex = row:GetHighlightTexture()
		      tex:SetSize(16, 16)
		      tex:ClearAllPoints()
		      tex:SetPoint('LEFT', 3, 0)

		row:SetHighlightFontObject('GameFontHighlightLeft')
		row:SetDisabledFontObject('GameFontHighlightLeft')
		row:SetNormalFontObject('GameFontNormalLeft')

		local label = row:CreateFontString(nil, nil, 'GameFontNormalLeft')
		      label:SetPoint('LEFT', 20, 0)
		      label:SetHeight(row:GetHeight())
		row:SetFontString(label)

		local prefix = row:CreateFontString(nil, nil, 'GameFontNormalSmall')
		      prefix:SetPoint('TOPLEFT')
		      prefix:SetPoint('BOTTOMRIGHT', label, 'BOTTOMLEFT')
		row.prefix = prefix

		local suffix = row:CreateFontString(nil, nil, 'GameFontNormalRight')
		      suffix:SetPoint('TOPLEFT', label, 'TOPRIGHT', 4, 0)
		      suffix:SetPoint('BOTTOMRIGHT', -80, 0)
		row.suffix = suffix

		for i = 1, 5 do
			local item = CreateFrame('Button', '$parentItem'..i, row, nil, i)
			      item:SetSize(14, 14)
			local tex = item:CreateTexture(nil, 'BACKGROUND')
			      tex:SetAllPoints()
			item.icon = tex

			item:SetScript('OnEnter', addon.ShowTooltip)
			item:SetScript('OnLeave', addon.HideTooltip)
			item:SetScript('OnClick', OnButtonClick)
			row[i] = item

			if i == 1 then
				item:SetPoint('RIGHT')
			else
				item:SetPoint('RIGHT', row[i-1], 'LEFT', -1, 0)
			end
		end
	end
end

function lists:OnDisable()
	--
end

function lists:Update()
	UpdateList()
end

local ItemSearch = LibStub('LibItemSearch-1.2')
function lists:Search(what, onWhom)
	-- TODO: relay to provider
	local hasMatch = 0
	if what and what ~= '' and what ~= _G.SEARCH then
		-- find results
		-- hasMatch = hasMatch + 1
	end

	local character = addon.GetSelectedCharacter()
	if self.panel:IsVisible() and character == onWhom then
		-- this panel is active, display filtered results
		-- ListUpdate(self.panel.scrollFrame)
	end

	return hasMatch
end
