local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: CreateFrame, IsModifiedClick, HandleModifiedItemClick, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, FauxScrollFrame_OnVerticalScroll
-- GLOBALS: ipairs

local views = addon:GetModule('views')
local lists = views:NewModule('lists', 'AceEvent-3.0')
      lists.icon = 'Interface\\Icons\\INV_Scroll_02' -- grids: Ability_Ensnare
      lists.title = 'Lists'
local NUM_ITEMS_PER_ROW = 5

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

local CustomSearch = LibStub('CustomSearch-1.0')
local ItemSearch   = LibStub('LibItemSearch-1.2')
local filters = {
	text = {
	  	tags = {'text'},
		canSearch = function(self, operator, search)
			return not operator and search
		end,
		match = function(self, text, _, search)
			return CustomSearch:Find(search, text)
		end
	},
}

local function UpdateList()
	local self = lists
	local characterKey = addon:GetSelectedCharacter()
	local numRows = 0

	local scrollFrame = self.panel.scrollFrame
	local offset = FauxScrollFrame_GetOffset(scrollFrame)

	local buttonIndex = 1
	for index = 1, self.provider:GetNumRows(characterKey) do
		-- TODO: fix search filtering, including search & collapse/expand
		-- if not self.search or MatchesSearch(self.provider, characterKey, index, self.search) then
		numRows = numRows + 1 -- this counts the number of rows remaining after filtering
		if index >= offset+1 then
			local button = scrollFrame[buttonIndex]
			if button then
				buttonIndex = buttonIndex + 1

				local isHeader, title, prefix, suffix, link, tiptext = self.provider:GetRowInfo(characterKey, index)
				local isCollapsed = false -- TODO: store as setting

				button:SetText(title)
				button.link = link
				button.tiptext = tiptext

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
					local icon, link, tiptext = self.provider:GetItemInfo(characterKey, index, itemIndex)
					if icon then
						itemButton.icon:SetTexture(icon)
						itemButton.link = link
						itemButton.tiptext = tiptext
						itemButton:Show()
					else
						itemButton:Hide()
					end
				end
			end
		end
	end

	-- hide empty rows
	for index = buttonIndex, #scrollFrame do
		local button = scrollFrame[index]
		button:SetNormalTexture('')
		button:SetHighlightTexture('')
		button:SetText('')
		button.prefix:SetText('')
		button.suffix:SetText('')
		button.link = nil
		button.tiptext = nil

		for itemIndex, itemButton in ipairs(button) do
			itemButton:Hide()
		end
	end

	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numRows, #scrollFrame, 20)
	-- scrollFrame:SetPoint('BOTTOMRIGHT', -10+(needsScrollBar and -14 or 0), 2)
end

function lists:SelectDataSource(button, btn, up)
	for index, sourceButton in ipairs(self.panel) do
		if sourceButton == button then
			self.provider = self:GetModule(sourceButton.module)
			sourceButton:SetChecked(true)
		else
			sourceButton:SetChecked(false)
		end
	end
	UpdateList()
end
local function CreateDataSourceButton(subModule, index)
	local name, title, icon = subModule:GetName(), subModule.title, subModule.icon
	local button = CreateFrame('CheckButton', '$parent'..name, lists.panel, 'PopupButtonTemplate', index)
	      button:SetNormalTexture(icon)
	      button:SetScale(0.75)
	      button.tiptext = title
	      button.module = name
	      button:SetScript('OnClick', function(...) lists:SelectDataSource(...) end)
	      button:SetScript('OnEnter', addon.ShowTooltip)
	      button:SetScript('OnLeave', addon.HideTooltip)
	return button
end
function lists:UpdateDataSources()
	local panel = self.panel

	local index = 0
	for name, subModule in self:IterateModules() do
		self.provider = self.provider or subModule

		-- init data selector
		index = index + 1
		local button = _G[panel:GetName()..subModule:GetName()] or CreateDataSourceButton(subModule, index)
		      button:ClearAllPoints()
		      button:SetChecked(self.provider == subModule)
		panel[index] = button
		if index == 1 then
			button:SetPoint('TOPLEFT', 10, -12)
		else
			button:SetPoint('TOPLEFT', panel[index - 1], 'TOPRIGHT', 12, 0)
		end
	end
end

function lists:OnEnable()
	self:UpdateDataSources()

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

		for i = 1, NUM_ITEMS_PER_ROW do
			local item = CreateFrame('Button', '$parentItem'..i, row, nil, i)
			      item:SetSize(16, 16)
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

local CustomSearch = LibStub('CustomSearch-1.0')
local ItemSearch   = LibStub('LibItemSearch-1.2')
local filters = {
	text = {
	  	tags = {'text'},
		canSearch = function(self, operator, search)
			return not operator and search
		end,
		match = function(self, text, _, search)
			return CustomSearch:Find(search, text)
		end
	},
}
function lists:Search(search, characterKey)
	local hasMatch = 0

	for name, subModule in self:IterateModules() do
		-- TODO: let lists search their values, e.g. reputation standing, quest reward gold etc
		local numMatches = 0
		for index = 1, subModule:GetNumRows(characterKey) do
			local _, title, prefix, suffix, hyperlink = subModule:GetRowInfo(characterKey, index)
			local compareString = strjoin(' ', title or '', prefix or '', suffix or '')

			if ItemSearch:Matches(hyperlink or '', search) or CustomSearch:Matches(compareString, search, filters) then
				-- the row itself matches
				numMatches = numMatches + 1
			else
				-- check if the row's items match
				for itemIndex = 1, NUM_ITEMS_PER_ROW do
					local itemName, itemLink, tiptext, count = subModule:GetItemInfo(characterKey, index, itemIndex)
					if itemLink and ItemSearch:Matches(itemLink, search) then
						numMatches = numMatches + 1
					end
				end
			end
		end
		hasMatch = hasMatch + numMatches

		if characterKey == addon:GetSelectedCharacter() then
			-- FauxScrollFrame_SetOffset(self.panel.scrollFrame, 0)
			-- numMatches = UpdateList()

			-- desaturate when data source has no data
			local button = _G[self.panel:GetName()..subModule:GetName()]
			      button:GetNormalTexture():SetDesaturated(numMatches == 0)
		end
	end

	return hasMatch
end
