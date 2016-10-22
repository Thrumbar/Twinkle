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

local collection  = setmetatable({ }, { __mode = 'v' }) -- TODO: does this even have any effect?
local emptyTable = {}
local searchCache = {}
local prototype = {
	Update = function(self)
		if items.provider == self then
			print('update items!', self, items.panel:IsShown(), items.panel:IsVisible())
			-- only the logged in character's items can change
			self:GatherItems(addon.data:GetCurrentCharacter())
			items:UpdateList()
		end
	end,
}
-- views modules are disabled by default, so our modules need to do the same
items:SetDefaultModuleState(false)
items:SetDefaultModulePrototype(prototype)

local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')
local ItemSearch     = LibStub('LibItemSearch-1.2')

-- note: item based sorting matches index of GetItemInfo, collection based matches property name
local SORT_BY_NAME, SORT_BY_QUALITY, SORT_BY_LEVEL, SORT_BY_COUNT = 1, 3, 15, 16
local sortOrder = { SORT_BY_NAME, SORT_BY_QUALITY, SORT_BY_LEVEL, SORT_BY_COUNT }
local sortHeaders = {
	{ id = SORT_BY_QUALITY,	label = _G.QUALITY },
	{ id = SORT_BY_NAME,	label = _G.ITEM_NAMES },
	{ id = SORT_BY_COUNT,	label = L['Count'] },
	{ id = SORT_BY_LEVEL,	label = _G.LEVEL }, -- GUILDINFOTAB_INFO
}

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

	-- TODO: handle different creation contexts
	-- item:122273:0:0:0:0:0:0:0:100:0:14:0; GetDifficultyInfo() => "Normal", "raid", false, false, false, false, nil; GetItemCreationContext => 122273, "vendor"
	-- item:122273:0:0:0:0:0:0:0:100:0:1:0; GetDifficultyInfo() => "Normal", "party", false, false, false, false, nil; GetItemCreationContext() => 122273, "dungeon-normal"
end

-- click handler for list rows
local function OnRowClick(self, btn, up)
	if self.link and IsModifiedClick() then
		return HandleModifiedItemClick(self.link)
	end
end
local function ItemOnEnter(self) addon.ShowTooltip(self:GetParent()) end
local function ItemOnClick(self, btn, up) return OnRowClick(self:GetParent(), btn, up) end

-- --------------------------------------------------------
--  Source Provider Selection
-- --------------------------------------------------------
-- left click: regular toggle. right click: show only this one
local function SourceOnClick(button, btn, up)
	PlaySound('igAbiliityPageTurn')
	if btn == 'RightButton' then
		for name, provider in items:IterateModules() do
			provider.button:SetChecked(provider.button == button)
		end
	end
	items:Update()
end

function items:UpdateDataSources()
	local query = addon.GetSearch and addon:GetSearch()
	local previous
	for providerName, provider in self:IterateModules() do
		if not provider:IsEnabled() then provider:Enable() end

		local button = provider.button
		if not button then
			-- TODO: show slot count (13/97) on icons
			button = CreateFrame('CheckButton', '$parent'..providerName, self.panel, 'PopupButtonTemplate', providerName)
			button:SetNormalTexture(provider.icon)
			button:SetScale(0.75)
			button:SetChecked(not provider.unchecked)
			button.tiptext = provider.title
			button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
			button:SetScript('OnClick', SourceOnClick)
			button:SetScript('OnEnter', addon.ShowTooltip)
			button:SetScript('OnLeave', addon.HideTooltip)
			provider.button = button
		end

		if not previous then
			button:SetPoint('TOPLEFT', 10, -12)
		else
			button:SetPoint('TOPLEFT', previous, 'TOPRIGHT', 12, 0)
		end
		if not query then
			button:GetNormalTexture():SetDesaturated(false)
		end
		previous = button
	end
end

-- --------------------------------------------------------
--  Sorting
-- --------------------------------------------------------
local function SorterOnClick(button, btn)
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

local function CreateSortButtons(parent)
	local tabRegions = {'', 'Left', 'Middle', 'Right'}
	local totalWidth, previous = 0, nil
	parent.sorters = {}
	for index, data in ipairs(sortHeaders) do
		local sorter = CreateFrame('Button', '$parentSorter' .. index, parent, 'WhoFrameColumnHeaderTemplate', data.id)
		sorter:SetText(data.label)
		sorter:SetScript('OnClick', SorterOnClick)
		-- sorter:SetNormalFontObject(GameFontNormalSmall)
		parent.sorters[index] = sorter

		if index == 1 then
			sorter:SetPoint('TOPLEFT', '$parent', 'TOPLEFT', 4, -40-4)
		else
			sorter:SetPoint('LEFT', parent.sorters[index - 1], 'RIGHT', -2, 0)
		end

		-- adjust tab width
		local width = sorter:GetTextWidth() + 16
		WhoFrameColumn_SetWidth(sorter, width)
		totalWidth = totalWidth + width -- - 2

		-- adjust tab height
		local sorterName = sorter:GetName()
		for _, region in ipairs(tabRegions) do
			_G[sorterName .. region]:SetHeight(20)
		end
	end
	-- extend main tab to fill whole panel width
	local tabWidth = parent.sorters[2]:GetWidth()
	WhoFrameColumn_SetWidth(parent.sorters[2], parent:GetWidth() - (totalWidth - tabWidth) -2*4)
end

local function Sort(a, b)
	-- property/sortValue can be nil if GetItemInfo was not available when filling the cache
	for _, sortOption in ipairs(sortOrder) do
		local realSort, ascending = abs(sortOption), sortOption > 0
		local aValue, bValue
		if realSort == SORT_BY_LEVEL then
			aValue = LibItemUpgrade:GetUpgradedItemLevel(a.link)
			bValue = LibItemUpgrade:GetUpgradedItemLevel(b.link)
		elseif realSort == SORT_BY_COUNT then
			aValue, bValue = 0, 0
			for providerName, provider in items:IterateModules() do
				if provider.button:GetChecked() then
					aValue = aValue + (a[providerName] or 0)
					bValue = bValue + (b[providerName] or 0)
				end
			end
		else
			-- sort based on item data
			aValue = select(realSort, GetItemInfo(a.link))
			bValue = select(realSort, GetItemInfo(b.link))
		end

		if aValue and bValue and aValue ~= bValue then
			if ascending then
				return aValue < bValue
			else
				return aValue > bValue
			end
		end
	end
	-- fallback if everything goes wrong
	return a.link < b.link
end

-- --------------------------------------------------------
--  Item Data Gathering
-- --------------------------------------------------------
local function AddItem(characterKey, providerName, baseLink, identifier, count)
	-- TODO: do not duplicate guild bank items
	-- do we already know this item?
	local collectionIndex
	for compareIndex, compareData in ipairs(collection[characterKey] or emptyTable) do
		local compareBaseLink = GetBaseLink(compareData.link)
		-- TODO: don't group (expiring) mail items with permanent bag items
		if compareBaseLink == baseLink then
			collectionIndex = compareIndex
			break
		end
	end

	-- add all items, regardless of search query and filters, they will be filtered in UpdateList
	if collectionIndex then
		local collectionItem = collection[characterKey][collectionIndex]
		collectionItem[providerName] = (collectionItem[providerName] or 0) + (count or 1)
	else
		-- providers must not be names 'link' for obvious reasons
		tinsert(collection[characterKey], {
			link = baseLink,
			[providerName] = count or 1,
		})
	end
end

function items:GatherItems(characterKey)
	if not collection[characterKey] then collection[characterKey] = {} end
	wipe(collection[characterKey])
	for providerName, provider in self:IterateModules() do
		for index = 1, provider:GetNumRows(characterKey) or 0 do
			local location, hyperlink, count = provider:GetRowInfo(characterKey, index)
			-- TODO/FIXME: when item links are not available, we need to update, too!
			if hyperlink then
				AddItem(characterKey, providerName, GetBaseLink(hyperlink), location, count)
			end
		end
	end
end

-- --------------------------------------------------------
--  View Update
-- --------------------------------------------------------
-- tone down some quality colors
local qualityAlpha = {
	[_G.LE_ITEM_QUALITY_COMMON] = 0.5,
	[_G.LE_ITEM_QUALITY_UNCOMMON] = 0.5,
}
function items:UpdateList()
	local query = addon.GetSearch and addon:GetSearch()

	local characterKey = addon:GetSelectedCharacter()
	local scrollFrame  = self.panel.scrollFrame
	local offset       = FauxScrollFrame_GetOffset(scrollFrame)

	-- numRows: including headers (=> scroll frame), numDataRows: excluding headers (=> result count)
	local buttonIndex, numRows, numDataRows = 1, 0, 0
	for index, itemData in ipairs(collection[characterKey]) do
		local matchesSearch = self:SearchRow(query, characterKey, itemData.link)
		local itemCount = 0
		if matchesSearch then
			-- this row matches, even though it might not be displayed
			numDataRows = numDataRows + 1

			-- only actually show row if provider is enabled
			for providerName, provider in self:IterateModules() do
				if provider.button:GetChecked() then
					itemCount = itemCount + (itemData[providerName] or 0)
				end
			end
			matchesSearch = itemCount > 0
		end

		if matchesSearch then numRows = numRows + 1 end
		if matchesSearch and numRows > offset then
			local button = scrollFrame[buttonIndex]
			if button then
				-- update display row
				local name, _, quality, _, _, _, _, _, _, texture, _ = GetItemInfo(itemData.link)
				local r, g, b = GetItemQualityColor(quality or _G.LE_ITEM_QUALITY_COMMON)
				local itemLevel = LibItemUpgrade:GetUpgradedItemLevel(itemData.link)

				button.name:SetText(name)
				-- button.name:SetTextColor(r, g, b)
				button.count:SetText(itemCount > 1 and itemCount or nil)
				button.level:SetText(itemLevel)
				button.icon:SetTexture(texture)
				button.iconBorder:SetVertexColor(r, g, b, quality and qualityAlpha[quality] or 1)
				button.link = itemData.link
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

function items:Update()
	self:UpdateDataSources()

	-- gather data
	local characterKey = addon:GetSelectedCharacter()
	if not collection[characterKey] or #collection[characterKey] == 0 then
		self:GatherItems(characterKey)
	end
	tsort(collection[characterKey], Sort)

	-- display data
	local numRows = self:UpdateList()
	return numRows
end

-- --------------------------------------------------------
--  Plugin Setup
-- --------------------------------------------------------
function items:Load()
	local panel = self.panel
	CreateSortButtons(panel)

	local background = panel:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\EncounterJournal\\UI-EJ-JournalBG')
	      background:SetTexCoord(395/1024, 782/1024, 3/512, 426/512)
	      background:SetPoint('TOPLEFT', 0, -40 -20)
		  background:SetPoint('BOTTOMRIGHT')

	local scrollFrame = CreateFrame('ScrollFrame', '$parentScrollFrame', panel, 'FauxScrollFrameTemplate')
	      scrollFrame:SetSize(360, 354 - 20)
	      scrollFrame:SetPoint('TOPLEFT', 0, -40-20-9)
	      scrollFrame:SetPoint('BOTTOMRIGHT', -24, 2)
	      scrollFrame.scrollBarHideable = true
	panel.scrollFrame = scrollFrame

	scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
		local buttonHeight = self[1]:GetHeight()
		FauxScrollFrame_OnVerticalScroll(self, offset, buttonHeight, function() items:UpdateList() end)
	end)

	for index = 1, 11 do
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

		local highlight = row:CreateTexture(nil, 'HIGHLIGHT') -- UI-EJ-SearchBarHighlightSm
		      highlight:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures')
		      highlight:SetTexCoord(0.63085938, 0.88085938, 0.58886719, 0.61523438)
		      highlight:SetDesaturated(true)
		      highlight:SetVertexColor(230/255, 100/255, 60/255, 0.66)
		      highlight:SetAllPoints()
		row:SetHighlightTexture(highlight, 'BLEND')

		row:SetScript('OnEnter', function(self) self.name:SetFontObject('GameFontHighlight') end)
		row:SetScript('OnLeave', function(self) self.name:SetFontObject('GameFontNormal') end)
		row:SetScript('OnClick', OnRowClick)

		local item = CreateFrame('Button', nil, row)
		      item:SetSize(30, 30)
		      item:SetPoint('LEFT', 0, 0)
		row.item = item

		item:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')
		item:SetScript('OnEnter', ItemOnEnter)
		item:SetScript('OnLeave', addon.HideTooltip)
		item:SetScript('OnClick', ItemOnClick)

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

	self:RegisterMessage('TWINKLE_CHARACTER_DELETED')
end

function items:OnDisable()
	self:UnregisterMessage('TWINKLE_CHARACTER_DELETED')
end

-- --------------------------------------------------------
--  Search Support
-- --------------------------------------------------------
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
	local isCurrentCharacter = characterKey == addon:GetSelectedCharacter()
	local numResults = 0
	for name, provider in self:IterateModules() do
		-- gather search results without affecting current display
		local numMatches = 0
		for index = 1, provider:GetNumRows(characterKey) do
			local _, itemLink = provider:GetRowInfo(characterKey, index)
			local matchesSearch = itemLink and self:SearchRow(query, characterKey, itemLink)
			if matchesSearch then
				numMatches = numMatches + 1
			end
		end
		numResults = numResults + numMatches

		if isCurrentCharacter then
			-- desaturate when data source has no data
			-- provider.button.searchResults = numMatches
			provider.button:GetNormalTexture():SetDesaturated(numMatches == 0)
		end
	end
	return numResults
end

function items:TWINKLE_CHARACTER_DELETED(event, characterKey)
	wipe(collection[characterKey])
	collection[characterKey] = nil
end
