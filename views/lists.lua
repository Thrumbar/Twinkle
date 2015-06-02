local addonName, addon, _ = ...
local L = addon.L

-- GLOBALS: _G, DataStore
-- GLOBALS: CreateFrame, IsModifiedClick, HandleModifiedItemClick, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, FauxScrollFrame_SetOffset, FauxScrollFrame_OnVerticalScroll
-- GLOBALS: ipairs, wipe, strjoin, type

-- TODO: return all sub-rows when parent matches search?

local views = addon:GetModule('views')
local lists = views:NewModule('lists')
      lists.icon = 'Interface\\Icons\\INV_Scroll_02' -- grids: Ability_Ensnare
      lists.title = L['Lists']

local prototype = {
	Update = function(self)
		if lists.provider == self then
			print('update!', self, lists.panel:IsShown(), lists.panel:IsVisible())
			lists:UpdateList()
		end
	end,
}
-- views modules are disabled by default, so our modules need to do the same
lists:SetDefaultModuleState(false)
lists:SetDefaultModulePrototype(prototype)

local NUM_ITEMS_PER_ROW = 6
local INDENT_WIDTH = 20
local collapsed, searchResultCache = {}, {}

local function SetCollapsedState(button, state)
	button.state = state
	local actionIcon = state == 'expanded' and 'MinusButton' or 'PlusButton'
	button:GetNormalTexture():SetTexture('Interface\\Buttons\\UI-'..actionIcon..'-UP')
	button:GetDisabledTexture():SetTexture('Interface\\Buttons\\UI-'..actionIcon..'-Disabled')
	-- button:GetHighlightTexture():SetTexture('Interface\\Buttons\\UI-'..actionIcon..'-Hilight', 'ADD')
end

-- click handler for list rows
local function OnRowClick(self, btn, up)
	if self.isHeader then
		-- collapse/expand this category
		local providerName  = lists.provider:GetName()
		local characterKey  = addon:GetSelectedCharacter()
		local _, identifier = lists.provider:GetRowInfo(characterKey, self:GetID())
		collapsed[providerName][identifier] = not collapsed[providerName][identifier]
		lists:Update()
	elseif IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	elseif lists.provider.OnClickRow then
		lists.provider.OnClickRow(self, btn, up)
	end
end

-- click handler for item buttons
local function OnButtonClick(self, btn, up)
	if not self.link then
		return
	elseif IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	elseif lists.provider.OnClickItem then
		lists.provider.OnClickItem(self, btn, up)
	end
end

local headerParents = {}
local function UpdateList()
	local self = lists
	local query = addon.GetSearch and addon:GetSearch()
	local headerState, nextDataRow = nil, 1

	local characterKey = addon:GetSelectedCharacter()
	local providerName = self.provider:GetName()
	local scrollFrame  = self.panel.scrollFrame
	local offset       = FauxScrollFrame_GetOffset(scrollFrame)

	-- numRows: including headers (=> scroll frame), numDataRows: excluding headers (=> result count)
	local buttonIndex, numRows, numDataRows = 1, 0, 0
	for index = 1, self.provider:GetNumRows(characterKey) or 0 do
		local isHeader, title, prefix, suffix, link, tiptext = self.provider:GetRowInfo(characterKey, index)
		local isHeaderCollapsed = isHeader and isHeader < 0
		      isHeader = isHeaderCollapsed and -1*isHeader or isHeader
		local identifier = isHeader and title or link or tiptext

		-- store collapse/expand all state
		if isHeader then
			if collapsed[providerName].all ~= nil then
				collapsed[providerName][identifier] = collapsed[providerName].all or nil
			elseif collapsed[providerName][identifier] == nil then
				collapsed[providerName][identifier] = isHeaderCollapsed
			end
		end

		-- hide nested collapsed rows
		local matchesSearch = isHeader or self:SearchRow(self.provider, query, characterKey, index)
		local isCollapsed, isHidden = false, false
		for level, parentIdentifier in ipairs(headerParents) do
			if not isHeader or level < isHeader then
				-- state depends on parent's state
				isHidden = isHidden or collapsed[providerName][parentIdentifier]
			elseif level > isHeader then
				headerParents[level] = nil
			end
		end

		if isHeader then
			local headerLevel = type(isHeader) == 'number' and isHeader or 0
			if headerLevel <= #headerParents and nextDataRow < buttonIndex then
				-- remove empty sibling/parent headers
				while buttonIndex > (nextDataRow or 1) and scrollFrame[buttonIndex] do
					buttonIndex = buttonIndex - 1
					numRows     = numRows - 1
				end
			end
			headerParents[headerLevel] = identifier
			numRows = numRows + (isHidden and 0 or 1)

			-- compare state for "toggle all" button
			isCollapsed = collapsed[providerName][identifier]
			local state = isCollapsed and 'collapsed' or 'expanded'
			if headerState == nil then
				headerState = state
			elseif headerState and headerState ~= state then
				headerState = false
			end
		elseif matchesSearch then
			-- this row matches, even though it may not be displayed
			numRows     = numRows + (isHidden and 0 or 1)
			numDataRows = numDataRows + 1
			nextDataRow = buttonIndex + (isHidden and 0 or 1)
		end

		if index >= offset+1 and matchesSearch and not isHidden then
			local button = scrollFrame[buttonIndex]
			if button then
				button:SetID(index)
				button:SetText(title)
				button.link = link
				button.tiptext = tiptext

				-- keep indentation intact
				button:SetPoint('LEFT', scrollFrame, 'LEFT', (#headerParents - 1) * INDENT_WIDTH + 10, 0)

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
				button.isHeader = isHeader

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
				buttonIndex = buttonIndex + 1
			end
		end
	end

	-- reset "collapse/expand all" flag
	collapsed[providerName].all = nil
	if headerState then
		SetCollapsedState(self.panel.toggleAll, headerState)
	end

	-- hide empty rows
	for index = nextDataRow or buttonIndex, #scrollFrame do
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

	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numRows, #scrollFrame, scrollFrame[1]:GetHeight())
	-- adjustments so rows have decent padding with and without scroll bar
	scrollFrame:SetPoint('BOTTOMRIGHT', needsScrollBar and -24 or -12, 2)

	return numDataRows
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

function lists:SelectDataSource(button, btn, up)
	for index, sourceButton in ipairs(self.panel) do
		if sourceButton == button then
			self.provider = self:GetModule(sourceButton.module)
			sourceButton:SetChecked(true)
		else
			sourceButton:SetChecked(false)
		end
	end
	self:Update()
end

function lists:UpdateDataSources()
	local panel = self.panel

	local index = 0
	for name, subModule in self:IterateModules() do
		if not subModule:IsEnabled() then subModule:Enable() end
		self.provider   = self.provider or subModule
		collapsed[name] = collapsed[name] or {}
		searchResultCache[name] = searchResultCache[name] or {}

		-- init data selector
		index = index + 1
		local button = _G[panel:GetName()..subModule:GetName()] or CreateDataSourceButton(subModule, index)
		      button:GetNormalTexture():SetDesaturated(false)
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

function lists:UpdateList()
	local numRows = UpdateList()
	self.panel.resultCount:SetFormattedText('%d result |4row:rows;', numRows)
	return numRows
end

function lists:Update()
	self:UpdateDataSources()
	local numRows = self:UpdateList()
	return numRows
end

function lists:OnEnable()
	local panel = self.panel
	self:UpdateDataSources()

	local collapseAll = CreateFrame('Button', '$parentCollapseAll', panel)
	      collapseAll:SetSize(270, 20)
	      collapseAll:SetPoint('TOPLEFT', panel, 'TOPLEFT', 4, -40-1)
	local label = collapseAll:CreateFontString('$parentText', 'ARTWORK', 'GameFontNormalLeft')
	      label:SetPoint('LEFT', 20, 0)
	      label:SetHeight(collapseAll:GetHeight())
	collapseAll:SetFontString(label)
	collapseAll:SetHighlightFontObject('GameFontHighlightLeft')
	collapseAll:SetDisabledFontObject('GameFontDisableLeft')
	collapseAll:SetNormalFontObject('GameFontNormalLeft')

	collapseAll:SetNormalTexture('Interface\\Buttons\\UI-MinusButton-UP')
	local tex = collapseAll:GetNormalTexture()
	      tex:SetSize(16, 16)
	      tex:ClearAllPoints()
	      tex:SetPoint('LEFT', 3, 0)
	collapseAll:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight', 'ADD')
	local tex = collapseAll:GetHighlightTexture()
	      tex:SetSize(16, 16)
	      tex:ClearAllPoints()
	      tex:SetPoint('LEFT', 3, 0)
	collapseAll:SetDisabledTexture('Interface\\Buttons\\UI-PlusButton-Disabled')
	local tex = collapseAll:GetDisabledTexture()
	      tex:SetSize(16, 16)
	      tex:ClearAllPoints()
	      tex:SetPoint('LEFT', 3, 0)

	collapseAll:SetText(_G.ALL)
	collapseAll.state = 'expanded'
	collapseAll:SetScript('OnClick', function(button, btn, up)
		local providerName = self.provider:GetName()
		collapsed[providerName].all = button.state == 'expanded'
		self:Update()
	end)
	panel.toggleAll = collapseAll

	local count = panel:CreateFontString('$parentText', 'ARTWORK', 'GameFontNormalRight')
	      count:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -4, -40-4.5)
	panel.resultCount = count

	local background = panel:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\EncounterJournal\\UI-EJ-JournalBG')
	      background:SetTexCoord(395/1024, 782/1024, 3/512, 426/512)
	      background:SetPoint('TOPLEFT', 0, -40 -20)
		  background:SetPoint('BOTTOMRIGHT')

	local scrollFrame = CreateFrame('ScrollFrame', '$parentScrollFrame', panel, 'FauxScrollFrameTemplate')
	      scrollFrame:SetSize(360, 354)
	      scrollFrame:SetPoint('TOPLEFT', 0, -40-4 -20 -2)
	      scrollFrame:SetPoint('BOTTOMRIGHT', -24, 2)
	      scrollFrame.scrollBarHideable = true
	panel.scrollFrame = scrollFrame

	scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, 20, function() lists:UpdateList() end)
	end)

	for index = 1, 16 do
		local row = CreateFrame('Button', '$parentRow'..index, panel, nil, index)
		      row:SetHeight(20)
		scrollFrame[index] = row

		if index == 1 then
			row:SetPoint('TOP', scrollFrame, 'TOP', 0, -4)
		else
			row:SetPoint('TOP', scrollFrame[index - 1], 'BOTTOM', 0, 0)
		end
		row:SetPoint('LEFT', scrollFrame, 'LEFT', 10, 0)
		row:SetPoint('RIGHT', scrollFrame, 'RIGHT', 0, 0)
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

		local suffix = row:CreateFontString(nil, nil, 'GameFontBlack') -- GameFontNormalRight
		      suffix:SetJustifyH('RIGHT')
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

local CustomSearch = LibStub('CustomSearch-1.0')
local ItemSearch   = LibStub('LibItemSearch-1.2')
lists.filters = {
	tooltip = {
		tags      = ItemSearch.Filters.tip.tags,
		onlyTags  = ItemSearch.Filters.tip.onlyTags,
		canSearch = ItemSearch.Filters.tip.canSearch,
		match     = function(self, text, operator, search)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')
			return ItemSearch.Filters.tip.match(self, hyperlink or text, operator, search)
		end
	},
	name = {
		tags      = {'n', 'name', 'title', 'text'},
		canSearch = function(self, operator, search) return not operator and search end,
		match     = function(self, text, operator, search)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')
			local name = hyperlink:match('%[(.-)%]') or hyperlink
			if name then return CustomSearch:Find(search, name) end
		end
	},
}

function lists:SearchRow(provider, query, characterKey, index)
	if not query then return true end
	local cache = searchResultCache[provider:GetName()]
	local key   = strjoin(':', characterKey, index)
	if cache and cache.query ~= query then
		wipe(cache)
		cache.query = query
	elseif cache[key] ~= nil then
		return cache[key]
	end

	local isHeader, title, prefix, suffix, hyperlink = provider:GetRowInfo(characterKey, index)
	if not title then
		cache[key] = false
		return false
	end

	local searchString = characterKey..': '..(hyperlink or title)
	if CustomSearch:Matches(searchString, query, provider.filters or self.filters) then
		cache[key] = true
	elseif not provider.excludeItemSearch then -- check items
		for itemIndex = 1, NUM_ITEMS_PER_ROW do
			local itemName, itemLink, tiptext, count = provider:GetItemInfo(characterKey, index, itemIndex)
			if itemLink and ItemSearch:Matches(itemLink, query) then
				cache[key] = true
				break
			end
		end
	end
	return cache[key]
end

function lists:Search(query, characterKey)
	local isActiveView = characterKey == addon:GetSelectedCharacter() and views:GetActiveView() == self
	local numResults = 0
	for name, provider in self:IterateModules() do
		local numMatches = 0
		if isActiveView and provider == self.provider then
			-- update displayed data
			FauxScrollFrame_SetOffset(self.panel.scrollFrame, 0)
			numMatches = self:Update()
		else
			-- gather search results without affecting current display
			for index = 1, provider:GetNumRows(characterKey) do
				local matchesSearch = self:SearchRow(provider, query, characterKey, index)
				if matchesSearch then
					numMatches = numMatches + 1
				end
			end
		end

		-- desaturate when data source has no data
		_G[self.panel:GetName() .. name]:GetNormalTexture():SetDesaturated(numMatches == 0)
		numResults = numResults + numMatches
	end
	return numResults
end
