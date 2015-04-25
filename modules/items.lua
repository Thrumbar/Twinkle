local addonName, addon, _ = ...
local L = addon.L

-- GLOBALS: _G, DataStore
-- GLOBALS: CreateFrame, IsModifiedClick, HandleModifiedItemClick, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, FauxScrollFrame_SetOffset, FauxScrollFrame_OnVerticalScroll, WhoFrameColumn_SetWidth, GetItemInfo, GetItemQualityColor
-- GLOBALS: ipairs, wipe, strjoin, type, select
local tinsert, tremove, tsort, abs = table.insert, table.remove, table.sort, math.abs

local views = addon:GetModule('views')
local items = views:NewModule('items', 'AceEvent-3.0')
      items.icon  = 'Interface\\Buttons\\Button-Backpack-Up'
      items.title = _G.ITEMS
-- views modules are disabled by default, so our modules need to do the same
items:SetDefaultModuleState(false)

local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')
local ItemSearch     = LibStub('LibItemSearch-1.2')

local collection  = {}
local searchCache = {}
-- note: item based sorting matches index of GetItemInfo, collection based matches property name
local SORT_BY_NAME, SORT_BY_QUALITY, SORT_BY_LEVEL, SORT_BY_COUNT = 1, 3, 15, 16
local sortProperties = {
	[SORT_BY_LEVEL] = 'level',
	[SORT_BY_COUNT] = 'count'
}
local sortHeaders = {
	{ id = SORT_BY_QUALITY,	label = _G.QUALITY },
	{ id = SORT_BY_NAME,	label = _G.ITEM_NAMES },
	{ id = SORT_BY_COUNT,	label = L['Count'] },
	{ id = SORT_BY_LEVEL,	label = _G.LEVEL }, -- GUILDINFOTAB_INFO
}
local sortOrder = { SORT_BY_NAME, SORT_BY_QUALITY, SORT_BY_LEVEL, SORT_BY_COUNT }

-- returns an normalized itemlink while keeping enchants etc intact
local function GetBaseLink(hyperlink)
	if type(hyperlink) == 'number' then
		_, hyperlink = GetItemInfo(hyperlink)
		return hyperlink
	end
	local itemID, linkType = addon.GetLinkID(hyperlink)
	if not itemID or linkType ~= 'item' then return hyperlink end

	-- @see http://wowpedia.org/ItemString
	-- itemID:enchant:gem1:gem2:gem3:gem4:suffixID:uniqueID:level :upgradeId:instanceDifficultyID:numBonusIDs:bonusID1:bonusID2...
	return hyperlink:gsub('item:([^:]+:[^:]+:' 	-- itemID, enchantID
		..'[^:]+:[^:]+:[^:]+:[^:]+:' 			-- gem1, gem2, gem3, gem4
		..'[^:]+:)[^:]+(.+)$', 'item:%10%2')
end

-- TODO: choose one, row -or- button!
-- click handler for list rows
local function OnRowClick(self, btn, up)
	if not self.link then
		return
	elseif IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	end
end

-- click handler for item buttons
local function OnButtonClick(self, btn, up)
	if not self.link then
		return
	elseif IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	end
end

local function OnSorterClick(button, btn)
	local newSort, index = button:GetID(), nil
	for sortIndex, sortOption in ipairs(sortOrder) do
		if sortOption == newSort or sortOption == -1*newSort then
			index = sortIndex
			break
		end
	end
	if not index then return end
	if index == 1 then
		-- reverse current sort order
		sortOrder[index] = -1 * sortOrder[index]
	else
		-- remove from old position, insert at front
		tremove(sortOrder, index)
		tinsert(sortOrder, 1, newSort)
	end
	items:Update()
end

-- left click: regular toggle. right click: show only this one
local function OnSourceClick(button, btn, up)
	if btn == 'RightButton' then
		for index, sourceButton in ipairs(items.panel) do
			-- show button eclusively
			sourceButton:SetChecked(sourceButton == button)
		end
	end
	items:Update()
end

local function SortCallback(a, b)
	-- property/sortValue can be nil if GetItemInfo was not available when filling the cache
	for _, sortOption in ipairs(sortOrder) do
		local realSort, ascending = abs(sortOption), sortOption > 0
		if sortProperties[realSort] then
			-- sort based on collection data
			local property = sortProperties[realSort]
			if a[property] and b[property] and a[property] ~= b[property] then
				return (ascending and a[property] < b[property]) or (not ascending and a[property] > b[property])
			end
		else
			-- sort based on item data
			local aValue = select(realSort, GetItemInfo(a.itemLink))
			local bValue = select(realSort, GetItemInfo(b.itemLink))
			if aValue and bValue and aValue ~= bValue then
				return (ascending and aValue < bValue) or (not ascending and aValue > bValue)
			end
		end
	end
	-- fallback if everything goes wrong
	return a.locations[1] < b.locations[1]
end

local qualityAlpha = {
	[_G.LE_ITEM_QUALITY_COMMON] = 0.5,
	[_G.LE_ITEM_QUALITY_UNCOMMON] = 0.5,
}
local function UpdateList()
	local self = items
	local query = addon.GetSearch and addon:GetSearch()

	local characterKey = addon:GetSelectedCharacter()
	local scrollFrame  = self.panel.scrollFrame
	local offset       = FauxScrollFrame_GetOffset(scrollFrame)
	tsort(collection[characterKey], SortCallback)

	-- numRows: including headers (=> scroll frame), numDataRows: excluding headers (=> result count)
	local buttonIndex, numRows, numDataRows = 1, 0, 0
	for index, itemData in ipairs(collection[characterKey]) do
		local matchesSearch = self:SearchRow(query, characterKey, itemData.itemLink)
		if matchesSearch then
			-- this row matches, even though it may not be displayed
			numRows = numRows + 1
			numDataRows = numDataRows + 1
		end

		if index >= offset+1 and matchesSearch then
			local button = scrollFrame[buttonIndex]
			if button then
				-- update display row
				local name, _, quality, _, _, _, _, _, _, texture, _ = GetItemInfo(itemData.itemLink)
				local count   = itemData.count
				local r, g, b = GetItemQualityColor(quality or _G.LE_ITEM_QUALITY_COMMON)

				button.name:SetText(name)
				-- button.name:SetTextColor(r, g, b)
				button.count:SetText(itemData.count > 1 and itemData.count or nil)
				button.level:SetText(itemData.level)
				button.icon:SetTexture(texture)
				button.iconBorder:SetVertexColor(r, g, b, quality and qualityAlpha[quality] or 1)
				button.item.link = itemData.itemLink

				button:Show()
				buttonIndex = buttonIndex + 1
			end
		end
	end

	-- hide empty rows
	for index = buttonIndex, #scrollFrame do
		local button = scrollFrame[index]
		      button.link = nil
		      button:Hide()
	end

	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numRows, #scrollFrame, scrollFrame[1]:GetHeight())
	-- adjustments so rows have decent padding with and without scroll bar
	scrollFrame:SetPoint('BOTTOMRIGHT', needsScrollBar and -24 or -12, 2)

	return numDataRows
end

local function CreateDataSourceButton(subModule)
	-- TODO: show slot count (13/97) on icons
	local name, title, icon = subModule:GetName(), subModule.title, subModule.icon
	local button = CreateFrame('CheckButton', '$parent'..name, items.panel, 'PopupButtonTemplate')
	      button:SetNormalTexture(icon)
	      button:SetScale(0.75)
	      button:SetChecked(not subModule.unchecked)
	      button.tiptext = title
	      button.module = name
	      button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	      button:SetScript('OnClick', OnSourceClick)
	      button:SetScript('OnEnter', addon.ShowTooltip)
	      button:SetScript('OnLeave', addon.HideTooltip)
	return button
end

function items:UpdateDataSources()
	local panel, index = self.panel, 1
	local previous = nil
	for name, subModule in self:IterateModules() do
		if not subModule:IsEnabled() then subModule:Enable() end

		-- init data selector
		local button = _G[panel:GetName()..name] or CreateDataSourceButton(subModule)
		      button:GetNormalTexture():SetDesaturated(false)
		      button:ClearAllPoints()
		if not previous then
			button:SetPoint('TOPLEFT', 10, -12)
		else
			button:SetPoint('TOPLEFT', '$parent'..previous, 'TOPRIGHT', 12, 0)
		end
		subModule.button = button
		panel[index] = button
		index = index + 1
		previous = name
	end
end

function items:CreateSortButtons()
	local panel      = self.panel
	panel.sorters    = {}
	local tabRegions = {'', 'Left', 'Middle', 'Right'}
	local totalWidth = 0
	for index, data in ipairs(sortHeaders) do
		local sorter = CreateFrame('Button', '$parentSorter'..index, panel, 'WhoFrameColumnHeaderTemplate', data.id)
			  sorter:SetText(data.label)
			  sorter:SetScript('OnClick', OnSorterClick)
		      -- sorter:SetNormalFontObject(GameFontNormalSmall)
		panel.sorters[index] = sorter

		if index == 1 then
			sorter:SetPoint('TOPLEFT', '$parent', 'TOPLEFT', 4, -40-4)
		else
			sorter:SetPoint('LEFT', panel.sorters[index - 1], 'RIGHT', -2, 0)
		end

		-- adjust tab width
		local width = sorter:GetTextWidth() + 16
		WhoFrameColumn_SetWidth(sorter, width)
		totalWidth = totalWidth + width -- - 2

		-- adjust tab height
		local sorterName = sorter:GetName()
		for _, region in ipairs(tabRegions) do
			_G[sorterName..region]:SetHeight(20)
		end
	end
	-- extend main tab to fill whole panel width
	local tabWidth = panel.sorters[2]:GetWidth()
	WhoFrameColumn_SetWidth(panel.sorters[2], panel:GetWidth() - (totalWidth - tabWidth) -2*4)
end

local function AddItem(characterKey, baseLink, ...)
	local identifier, count, level = ...

	-- do we already know this item?
	local collectionIndex
	for compareIndex, compareData in ipairs(collection[characterKey]) do
		local compareBaseLink = GetBaseLink(compareData.itemLink)
		-- TODO: don't group (expiring) mail items with permanent bag items
		if compareBaseLink == baseLink then
			collectionIndex = compareIndex
			break
		end
	end

	-- add all items, regardless of search query. those will be filtered in UpdateList
	if collectionIndex then
		local collectionItem = collection[characterKey][collectionIndex]
		collectionItem.count = collectionItem.count + (count or 1)
		tinsert(collectionItem.locations, location)
	else
		tinsert(collection[characterKey], {
			itemLink = baseLink,
			count    = count or 1,
			level    = level,
			locations = {
				identifier,
			},
		})
	end
end

function items:GatherItems(characterKey)
	if not collection[characterKey] then collection[characterKey] = {} end
	wipe(collection[characterKey])
	for name, subModule in self:IterateModules() do
		local filterButton = _G[self.panel:GetName()..name]
		if filterButton:GetChecked() then
			for index = 1, subModule:GetNumRows(characterKey) or 0 do
				local location, hyperlink, count, level = subModule:GetRowInfo(characterKey, index)
				local baseLink = hyperlink and GetBaseLink(hyperlink)

				local collectionIndex
				if baseLink then
					AddItem(characterKey, baseLink, location, count, level)
				end
			end
		end
	end
end

function items:OnEnable()
	local panel = self.panel
	self:UpdateDataSources()
	self:CreateSortButtons()

	local background = panel:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\EncounterJournal\\UI-EJ-JournalBG')
	      background:SetTexCoord(395/1024, 782/1024, 3/512, 426/512)
	      background:SetPoint('TOPLEFT', 0, -40 -20)
		  background:SetPoint('BOTTOMRIGHT')

	local scrollFrame = CreateFrame('ScrollFrame', '$parentScrollFrame', panel, 'FauxScrollFrameTemplate')
	      scrollFrame:SetSize(360, 354 - 20)
	      scrollFrame:SetPoint('TOPLEFT', 0, -40-4 -20 -2)
	      scrollFrame:SetPoint('BOTTOMRIGHT', -24, 2)
	      scrollFrame.scrollBarHideable = true
	panel.scrollFrame = scrollFrame

	scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
		local buttonHeight = self[1]:GetHeight()
		FauxScrollFrame_OnVerticalScroll(self, offset, buttonHeight, UpdateList)
	end)

	for index = 1, 11 do
		local row = CreateFrame('Button', nil, panel, nil, index)
		      row:SetScript('OnClick', OnRowClick)
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

		local highlight = row:CreateTexture(nil, 'HIGHLIGHT') -- UI-EJ-SearchBarHighlightSm
		      highlight:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures')
		      highlight:SetTexCoord(0.63085938, 0.88085938, 0.58886719, 0.61523438)
		      highlight:SetDesaturated(true)
		      highlight:SetVertexColor(230/255, 100/255, 60/255, 0.66)
		      highlight:SetAllPoints()
		row:SetHighlightTexture(highlight, 'BLEND')

		row:SetScript('OnEnter', function(self) self.name:SetFontObject('GameFontHighlight') end)
		row:SetScript('OnLeave', function(self) self.name:SetFontObject('GameFontNormal') end)

		local item = CreateFrame('Button', nil, row)
		      item:SetSize(30, 30)
		      item:SetPoint('LEFT', 0, 0)
		row.item = item

		item:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')
		item:SetScript('OnEnter', addon.ShowTooltip)
		item:SetScript('OnLeave', addon.HideTooltip)
		item:SetScript('OnClick', OnButtonClick)

		local iconBorder = item:CreateTexture(nil, 'OVERLAY', nil, 2) -- UI-EJ-SearchIconFrameLg
		      iconBorder:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures')
		      iconBorder:SetTexCoord(0.89843750, 0.97265625, 0.21386719, 0.25097656)
		      iconBorder:SetAllPoints()
		local icon = item:CreateTexture(nil, 'OVERLAY')
		      icon:SetPoint('TOPLEFT', item, 1, -2)
		      icon:SetPoint('BOTTOMRIGHT', item, -1, 1)
		row.icon = icon

		local quality = item:CreateTexture(nil, 'OVERLAY', nil, 3)
		      quality:SetTexture('Interface\\Buttons\\CheckButtonHilight')
		      quality:SetDesaturated(true)
		      quality:SetBlendMode('ADD')
		      quality:SetAllPoints()
		row.iconBorder = quality

		local level = row:CreateFontString(nil, nil, 'GameFontBlack')
			  level:SetPoint('RIGHT', 0, 0)
			  level:SetWidth(40)
			  level:SetJustifyH('RIGHT')
		row.level = level
		local count = row:CreateFontString(nil, nil, 'GameFontBlack')
		      count:SetWidth(40)
		      count:SetPoint('RIGHT', level, 'LEFT', -4, 0)
		      count:SetJustifyH('RIGHT')
		row.count = count
		local name = row:CreateFontString(nil, nil, 'GameFontNormal') -- SystemFont_Shadow_Med1
			  name:SetPoint('LEFT', item, 'RIGHT', 6, 0)
			  name:SetPoint('RIGHT', level, 'LEFT', -4)
			  name:SetHeight(row:GetHeight())
			  name:SetJustifyH('LEFT')
		row.name = name

		scrollFrame[index] = row
	end

	self:RegisterMessage('TWINKLE_SEARCH_RESULTS')
end

function items:Update()
	self:UpdateDataSources()

	-- gather data
	local characterKey = addon:GetSelectedCharacter()
	if characterKey == addon.data:GetCurrentCharacter() or not collection[characterKey] then
		-- current character's items may change, all others are static
		-- TODO/FIXME: when item links are not available, we need to update, too!
		self:GatherItems(characterKey)
	end

	-- display data
	local numRows = UpdateList()
	return numRows
end

function items:TWINKLE_SEARCH_RESULTS(event, searchResults, characterKey)
	-- characterKey = characterKey or addon:GetSelectedCharacter()
	for i, button in ipairs(self.panel) do
		button:GetNormalTexture():SetDesaturated(button.searchResults == 0)
	end
end

function items:SearchRow(query, characterKey, itemLink)
	if not query then return true end
	if not searchCache[characterKey] then searchCache[characterKey] = {} end
	local cache = searchCache[characterKey]
	if cache and cache.query ~= query then
		wipe(cache)
		cache.query = query
	elseif cache[itemLink] ~= nil then
		return cache[itemLink]
	end

	cache[itemLink] = ItemSearch:Matches(itemLink, query) and true or false
	return cache[itemLink]
end

function items:Search(query, characterKey)
	local isActiveView = characterKey == addon:GetSelectedCharacter() and views:GetActiveView() == self
	local numResults = 0
	for name, provider in self:IterateModules() do
		local numMatches = 0
		if isActiveView then
			-- update displayed data
			FauxScrollFrame_SetOffset(self.panel.scrollFrame, 0)
			numMatches = self:Update()
		else
			-- gather search results without affecting current display
			for index = 1, provider:GetNumRows(characterKey) do
				local _, itemLink = provider:GetRowInfo(characterKey, index)
				local matchesSearch = itemLink and self:SearchRow(query, characterKey, itemLink)
				if matchesSearch then
					numMatches = numMatches + 1
				end
			end
		end

		-- desaturate when data source has no data
		provider.button.searchResults = numMatches
		numResults = numResults + numMatches
	end
	return numResults
end
