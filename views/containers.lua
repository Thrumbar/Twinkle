local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore, ITEM_QUALITY_COLORS, NUM_BANKBAGSLOTS, NUM_BAG_SLOTS, SEARCH
-- GLOBALS: CreateFrame, IsAddOnLoaded, GetItemInfo, FauxScrollFrame_GetOffset, FauxScrollFrame_Update, FauxScrollFrame_OnVerticalScroll, SetItemButtonTexture, SecondsToTimeAbbrev, HandleModifiedItemClick
-- GLOBALS: table, wipe, pairs, ipairs, assert, math, tonumber, select, unpack, string, type

local views = addon:GetModule('views')
local view = views:NewModule('containers', 'AceTimer-3.0')
      view.icon = 'Interface\\Buttons\\Button-Backpack-Up'
      view.title = 'Items'

local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')
local LOCATION, ITEMID, COUNT, ITEMLINK, EXPIRY = 0, 1, 2, 3, 4 -- indices in data table

view.itemsTable = {}
local primarySort, secondarySort

local function ItemLinksAreEqual(link1, link2)
	if link1 == link2 then
		return true
	elseif link1 and link2 then
		-- remove uniqueID
		link1 = link1:gsub('^(.-%l+:[^:]*:?[^:]-:[^:]-:[^:]-:[^:]-:[^:]-:[^:]-):[^:]-:(.+)$', '%1:0:%2')
		link2 = link2:gsub('^(.-%l+:[^:]*:?[^:]-:[^:]-:[^:]-:[^:]-:[^:]-:[^:]-):[^:]-:(.+)$', '%1:0:%2')
		return link1 == link2
	else
		return false
	end
end

local function DataUpdate(characterKey)
	local filter = view.panel:GetName()

	local showBags, showBank, showVoid =
		_G[filter.."Bags"]:GetChecked(),
		_G[filter.."Bank"]:GetChecked(),
		_G[filter.."VoidStorage"]:GetChecked()

	wipe(view.itemsTable)
	local containers = DataStore:GetContainers(characterKey)
	for bag, data in pairs(containers) do
		local bagIndex = tonumber(bag:match('Bag(%d+)') or '')
		if (bag == 'VoidStorage' and showVoid) or
			(bagIndex and bagIndex <= NUM_BAG_SLOTS and showBags) or
			(bagIndex and (bagIndex == 100 or (bagIndex > NUM_BAG_SLOTS and bagIndex < NUM_BANKBAGSLOTS)) and showBank) then
			if bagIndex and bagIndex > NUM_BAG_SLOTS then
				bagIndex = (bagIndex == 100 and 0 or bagIndex) + NUM_BAG_SLOTS + 1
			end
			for slot = 1, data.size do
				local itemID = data.ids[slot]
				if itemID then
					local index
					for i, listData in ipairs(view.itemsTable) do
						if listData[ITEMID] and listData[ITEMID] == itemID
							and ItemLinksAreEqual(listData[ITEMLINK], data.links[i]) then
							index = i
							break
						end
					end

					if index then
						view.itemsTable[index][COUNT] = (view.itemsTable[index][COUNT] or 1) + (data.counts[slot] or 1)
					else
						table.insert(view.itemsTable, {
							[ITEMID] = itemID,
							[COUNT] = data.counts[slot],
							[ITEMLINK] = data.links[slot],
							[LOCATION] = tonumber(string.format("%d.%.2d", bagIndex or 100, slot)),
						})
					end
				end
			end
		end
	end

	local button = _G[filter..'Equipment']
	if button and button:GetChecked() then
		for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
			local item = addon.data.GetInventoryItemLink(characterKey, slotID, true)
			if item then
				local itemID, itemLink
				if type(item) == 'string' then
					itemID = addon.GetLinkID(item)
					itemLink = item
				else
					itemID = item
				end

				local index
				for i, data in ipairs(view.itemsTable) do
					if data[ITEMID] and data[ITEMID] == itemID and ItemLinksAreEqual(data[ITEMLINK], itemLink) then
						index = i
						break
					end
				end

				if index then
					view.itemsTable[index][COUNT] = (view.itemsTable[index][COUNT] or 1) + 1
				else
					table.insert(view.itemsTable, {
						[ITEMID] = itemID,
						[COUNT] = 1,
						[ITEMLINK] = itemLink,
						[LOCATION] = tonumber(string.format('-2.%.4d', slotID)),
					})
				end
			end
		end
	end

	local button = _G[filter..'Mail']
	if button and button:GetChecked() then
		for i = 1, DataStore:GetNumMails(characterKey) do
			local _, count, link, _, _, returned = DataStore:GetMailInfo(characterKey, i)
			if link then
				local itemID = addon.GetLinkID(link)
				local _, baseLink = GetItemInfo(itemID)
				local _, expiresIn = DataStore:GetMailExpiry(characterKey, i)
				         expiresIn = math.floor(expiresIn)

				local index
				for j, data in ipairs(view.itemsTable) do
					-- don't merge mail with non-mail items, don't merge different timings
					if data[1] == itemID and ItemLinksAreEqual(data[ITEMLINK], baseLink ~= link and link or nil) and data[EXPIRY] == expiresIn then
						index = j
						break
					end
				end

				if index then
					view.itemsTable[index][COUNT] = (view.itemsTable[index][COUNT] or 1) + 1
				else
					table.insert(view.itemsTable, {
						[ITEMID] = itemID,
						[COUNT] = count,
						[ITEMLINK] = (baseLink ~= link and link or nil),
						[EXPIRY] = expiresIn,
						[LOCATION] = tonumber(string.format('-1.%.4d', i)),
					})
				end
			end
		end
	end
end

local function UpdateList(self)
	local offset = FauxScrollFrame_GetOffset(self)
	for i = 1, #self do
		local index = i + offset
		local item = self[i]

		if view.itemsTable[index] then
			local itemID, itemCount, itemLink, timeLeft = unpack(view.itemsTable[index])
			local name, link, quality, iLevel, reqLevel, class, subclass, _, _, texture, _ = GetItemInfo(itemID)

			if itemLink then
				iLevel = LibItemUpgrade:GetUpgradedItemLevel(itemLink)
			end

			-- delay if we don't have data
			if not name then view:ScheduleTimer(UpdateList, 0.1, self); return end

			item.icon:SetTexture(texture)
			item.item.link = itemLink or link
			item.name:SetText(name)
			item.count:SetText(itemCount and itemCount > 1 and itemCount or nil)

			if timeLeft then
				if timeLeft <= 7*24*60*60 then
					item.level:SetTextColor(1, 0, 0)
				else
					item.level:SetTextColor(1, 0.82, 0)
				end
				item.level:SetFormattedText(SecondsToTimeAbbrev(timeLeft))
			else
				item.level:SetTextColor(1, 1, 1)
				item.level:SetFormattedText("%4d", iLevel or 0)
			end

			local r, g, b = GetItemQualityColor(quality)
			item.name:SetTextColor(r, g, b)
			--[[ if quality and quality ~= 1 then
				-- item.backdrop:Show()
				item.backdrop:SetVertexColor(r, g, b, 0.5)
			else
				item.backdrop:SetVertexColor(1, 1, 1, 0.5)
				-- item.backdrop:Hide()
			end --]]
			item:Show()
		else
			item:Hide()
		end
	end

	local needsScrollBar = FauxScrollFrame_Update(self, #view.itemsTable, #self, self[1]:GetHeight())
	-- adjustments so rows have decent padding with and without scroll bar
	self:SetPoint('BOTTOMRIGHT', needsScrollBar and -24 or -12, 2)
end

-- TODO: FIXME: this is ugly as hell
local function DataSort(a, b)
	local namea, _, qualitya, iLevela, _, classa, subclassa = GetItemInfo(a[ITEMID])
	if a[ITEMLINK] then iLevela = LibItemUpgrade:GetUpgradedItemLevel(a[ITEMLINK]) end

	local nameb, _, qualityb, iLevelb, _, classb, subclassb = GetItemInfo(b[ITEMID])
	if b[ITEMLINK] then iLevelb = LibItemUpgrade:GetUpgradedItemLevel(b[ITEMLINK]) end


	local reverse, s, sortA, sortB
	if primarySort then
		reverse = primarySort < 0
		s = math.abs(primarySort)
		sortA = (s == 1 and qualitya)
			or (s == 2 and namea)
			or (s == 3 and (a[COUNT] or 1))
			or (s == 4 and (a[EXPIRY] or iLevela))
		sortB = (s == 1 and qualityb)
			or (s == 2 and nameb)
			or (s == 3 and (b[COUNT] or 1))
			or (s == 4 and (b[EXPIRY] or iLevelb))
	end
	if sortA and sortB and sortA ~= sortB then
		if reverse then
			return sortA > sortB
		else
			return sortA < sortB
		end
	end

	if secondarySort then
		reverse = secondarySort < 0
		s = math.abs(secondarySort)
		sortA = (s == 1 and qualitya)
			or (s == 2 and namea)
			or (s == 3 and (a[COUNT] or 1))
			or (s == 4 and (a[EXPIRY] or iLevela))
		sortB = (s == 1 and qualityb)
			or (s == 2 and nameb)
			or (s == 3 and (b[COUNT] or 1))
			or (s == 4 and (b[EXPIRY] or iLevelb))
	end
	if sortA and sortB and sortA ~= sortB then
		if reverse then
			return sortA > sortB
		else
			return sortA < sortB
		end
	end

	return tonumber(a[LOCATION]) < tonumber(b[LOCATION])
end

local function SortOnClick(self, btn)
	local newSort = self:GetID()
	local reverse = primarySort and math.abs(primarySort) == math.abs(newSort)
	secondarySort = reverse and  secondarySort or primarySort
	primarySort   = reverse and -1*primarySort or newSort

	table.sort(view.itemsTable, DataSort)
	UpdateList(view.panel.scrollFrame)
end

local function FilterButtonOnClick() view:Update() end
local function CreateDataSourceButton(index, name, title, icon) -- (subModule, index)
	-- local name, title, icon = subModule:GetName(), subModule.title, subModule.icon
	local button = CreateFrame('CheckButton', '$parent'..name, view.panel, 'PopupButtonTemplate', index)
	      button:SetNormalTexture(icon)
	      button:SetScale(0.75)

	      button:SetScript('OnClick', FilterButtonOnClick) -- function(...) view:SelectDataSource(...) end)
	      button:SetScript('OnEnter', addon.ShowTooltip)
	      button:SetScript('OnLeave', addon.HideTooltip)

	      button.tiptext = title or name
	      button.module = name
	return button
end

local function ItemButtonOnClick(self, btn) HandleModifiedItemClick(self.link) end

--[[
function view:SelectDataSource(button, btn, up)
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

function view:UpdateDataSources()
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
end --]]

function view:OnEnable()
	local panel = self.panel

	-- TODO: show slot count (13/97) on icons
	-- TODO: convert to checking if required functions exist
	local filters = {}
	if IsAddOnLoaded('DataStore_Containers') then
		table.insert(filters, {'Bags', 'Bags', 'Interface\\MINIMAP\\TRACKING\\Banker'})
		table.insert(filters, {'Bank', 'Bank', 'INTERFACE\\ICONS\\achievement_guildperk_mobilebanking'})
		table.insert(filters, {'VoidStorage', 'Void Storage', 'INTERFACE\\ICONS\\Spell_Nature_AstralRecalGroup'})
	end
	if IsAddOnLoaded('DataStore_Inventory') then
		table.insert(filters, {'Equipment', 'Equipped Items', 'Interface\\GUILDFRAME\\GuildLogo-NoLogo'})
	end
	if IsAddOnLoaded('DataStore_Mails') then
		table.insert(filters, {'Mail', 'Mails', 'Interface\\MINIMAP\\TRACKING\\Mailbox'})
	end

	for i, data in ipairs(filters) do
		local filter = CreateDataSourceButton(i, unpack(data))
			  filter:SetChecked(true)

		if i == 1 then
			filter:SetPoint("TOPLEFT", 10, -12)
		else
			filter:SetPoint("LEFT", filters[i-1], "RIGHT", 10, 0)
		end
		filters[i] = filter
	end
	panel.filters = filters -- filterButtons

	local sorters = {"Quality", "Item Name", "Count", "Level"}
	local tabRegions = {'', 'Left', 'Middle', 'Right'}
	for i, name in ipairs(sorters) do
		local sorter = CreateFrame("Button", "$parentSorter"..i, panel, "WhoFrameColumnHeaderTemplate", i)
			  sorter:SetText(name)
			  sorter:SetScript("OnClick", SortOnClick)

		-- sorter:SetNormalFontObject(GameFontNormalSmall)
		local sorterName = sorter:GetName()
		for _, region in ipairs(tabRegions) do
			_G[sorterName..region]:SetHeight(20)
		end

		if i == 1 then
			sorter:SetPoint('TOPLEFT', panel, 'TOPLEFT', 4, -40-4)
		else
			sorter:SetPoint("LEFT", sorters[i-1], "RIGHT", -2, 0)
		end

		if i == 2 then
			-- make the main column wider
			WhoFrameColumn_SetWidth(sorter, 238)
		else
			WhoFrameColumn_SetWidth(sorter, sorter:GetTextWidth() + 16)
		end
		sorters[i] = sorter
	end
	panel.sorters = sorters

	local background = panel:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\TALENTFRAME\\spec-paper-bg')
	      background:SetTexCoord(0, 0.76, 0, 0.86)
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

	local function OnEnter(self) self.shadow:SetAlpha(1) end
	local function OnLeave(self) self.shadow:SetAlpha(0.5) end
	for i = 1, 11 do
		local row = CreateFrame('Button', nil, panel, nil, i)
		      row:SetHeight(30)
		      row:Hide()

		row:SetPoint('RIGHT', scrollFrame, 'RIGHT', 0, 0)
		if i == 1 then
			row:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 8, 0)
		else
			row:SetPoint('TOPLEFT', scrollFrame[i-1], 'BOTTOMLEFT', 0, 0)
		end

		row:SetScript('OnEnter', OnEnter)
		row:SetScript('OnLeave', OnLeave)

		--[[ local highlight = row:CreateTexture(nil, 'HIGHLIGHT')
		      -- UI-PlusButton-Hilight, UI-Common-MouseHilight, UI-Listbox-Highlight, UI-Listbox-Highlight2
		      highlight:SetTexture('Interface\\Buttons\\UI-Listbox-Highlight')
		      highlight:SetAlpha(0.5)
		      highlight:SetAllPoints()
		row:SetHighlightTexture(highlight) --]]

		local shadow = row:CreateTexture(nil, 'BACKGROUND')
		      shadow:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures')
		      shadow:SetTexCoord(50/512, 322/512, 633/1024, (678-10)/1024)
		      shadow:SetPoint('TOPLEFT', 26, 0)
		      shadow:SetPoint('BOTTOMRIGHT', 0, 0)
		      -- shadow:SetSize(270, 30)
		      shadow:SetAlpha(0.5)
		row.shadow = shadow

		local level = row:CreateFontString(nil, nil, 'GameFontHighlight')
			  level:SetPoint('RIGHT', 0, 0)
			  level:SetWidth(40)
			  level:SetJustifyH('RIGHT')
		row.level = level
		local count = row:CreateFontString(nil, nil, 'GameFontHighlight')
		      count:SetWidth(40)
		      count:SetPoint('RIGHT', level, 'LEFT', -4, 0)
		      count:SetJustifyH('RIGHT')
		row.count = count

		local item = CreateFrame('Button', nil, row)
		      item:SetSize(26, 26)
		      item:SetPoint('LEFT', 0, 0)
		      item:SetScript('OnEnter', addon.ShowTooltip)
		      item:SetScript('OnLeave', addon.HideTooltip)
		      item:SetScript('OnClick', ItemButtonOnClick)
		row.item = item
		local icon = item:CreateTexture(nil, 'BORDER')
		      icon:SetAllPoints()
		row.icon = icon

		local normalTexture = item:CreateTexture()
		      normalTexture:SetTexture('Interface\\Buttons\\UI-Quickslot2')
		      normalTexture:SetSize(42, 42)
		      normalTexture:SetPoint('CENTER')
		item:SetNormalTexture(normalTexture)
		item:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')
		item:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')

		local name = row:CreateFontString(nil, nil, 'GameFontHighlight')
			  name:SetPoint('LEFT', item, 'RIGHT', 6, 0)
			  name:SetPoint('RIGHT', level, 'LEFT', -4)
			  name:SetHeight(row:GetHeight())
			  name:SetJustifyH('LEFT')
		row.name = name

		table.insert(scrollFrame, row)
	end
	panel.scrollFrame = scrollFrame
end

function view:Update()
	local panel = self.panel
	local character = addon.GetSelectedCharacter()

	DataUpdate(character)
	table.sort(self.itemsTable, DataSort)

	panel.scrollFrame:SetVerticalScroll(0)
	UpdateList(panel.scrollFrame)
end

local ItemSearch = LibStub('LibItemSearch-1.2')
function view:Search(what, onWhom)
	local hasMatch = 0
	if what and what ~= '' and what ~= _G.SEARCH then
		DataUpdate(onWhom)
		for i = #self.itemsTable, 1, -1 do
			local _, link = GetItemInfo(self.itemsTable[i][ITEMID])
			-- TODO: also search sender name etc
			if not ItemSearch:Matches(link, what) then
				wipe(self.itemsTable[i])
				table.remove(self.itemsTable, i)
			else
				hasMatch = hasMatch + 1
			end
		end
		table.sort(self.itemsTable, DataSort)
	end

	local character = addon.GetSelectedCharacter()
	if self.panel:IsVisible() and character == onWhom then
		UpdateList(self.panel.scrollFrame)
	end

	return hasMatch
end
