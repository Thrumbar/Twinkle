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
	local filter = view.panel:GetName().."Filter"

	local showBags, showBank, showVoid = _G[filter.."Bags"]:GetChecked(), _G[filter.."Bank"]:GetChecked(), _G[filter.."VoidStorage"]:GetChecked()

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

local function ListUpdate(self)
	local offset = FauxScrollFrame_GetOffset(self)
	for i = 1, #self.buttons do
		local index = i + offset
		local item = self.buttons[i]

		if view.itemsTable[index] then
			local itemID, itemCount, itemLink, timeLeft = unpack(view.itemsTable[index])
			local name, link, quality, iLevel, reqLevel, class, subclass, _, _, texture, _ = GetItemInfo(itemID)

			if itemLink then
				iLevel = LibItemUpgrade:GetUpgradedItemLevel(itemLink)
			end

			-- delay if we don't have data
			if not name then view:ScheduleTimer(ListUpdate, 0.1, self); return end

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
			-- item.name:SetTextColor(r, g, b)
			if quality and quality ~= 1 then
				item.backdrop:Show()
				item.backdrop:SetVertexColor(r, g, b, 0.5)
			else
				item.backdrop:Hide()
			end
			item:Show()
		else
			item:Hide()
		end
	end

	local needsScrollBar = FauxScrollFrame_Update(self, #view.itemsTable, #self.buttons, 22)
	self:SetPoint("BOTTOMRIGHT", -10+(needsScrollBar and -18 or 0), 10)
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
	ListUpdate(view.panel.scrollFrame)
end

function view:OnEnable()
	local panel = self.panel

	-- TODO: show slot count (13/97) on icons
	local filters = {
		IsAddOnLoaded('DataStore_Containers') and {'Bags', 'Interface\\MINIMAP\\TRACKING\\Banker'},
		IsAddOnLoaded('DataStore_Containers') and {'Bank', 'INTERFACE\\ICONS\\achievement_guildperk_mobilebanking'},
		IsAddOnLoaded('DataStore_Containers') and {'VoidStorage', 'INTERFACE\\ICONS\\Spell_Nature_AstralRecalGroup'},
		IsAddOnLoaded('DataStore_Inventory')  and {'Equipment', 'Interface\\GUILDFRAME\\GuildLogo-NoLogo'},
		IsAddOnLoaded('DataStore_Mails')      and {'Mail', 'Interface\\MINIMAP\\TRACKING\\Mailbox'},
	}
	local filterButtons = {}
	local function OnFilterButtonClick() self.Update() end
	for i, data in ipairs(filters) do
		local filter = CreateFrame("CheckButton", "$parentFilter"..data[1], panel, "PopupButtonTemplate", i) -- SimplePopupButtonTemplate
			  filter:SetNormalTexture(data[2])
			  filter:SetChecked(true)
			  filter:SetScript("OnClick", OnFilterButtonClick)
			  filter:SetScript("OnEnter", addon.ShowTooltip)
			  filter:SetScript("OnLeave", addon.HideTooltip)
			  filter.tiptext = data[1]

		if i == 1 then
			filter:SetPoint("TOPLEFT", 10, -10)
		else
			filter:SetPoint("LEFT", filterButtons[i-1], "RIGHT", 10, 0)
		end
		table.insert(filterButtons, filter)
	end
	panel.filters = filterButtons

	local sorters = {"Quality", "Item Name", "Count", "Level"}
	local sortButtons = {}
	for i, name in ipairs(sorters) do
		local sorter = CreateFrame("Button", "$parentSorter"..i, panel, "WhoFrameColumnHeaderTemplate", i)
			  sorter:SetText(name)
			  sorter:SetScript("OnClick", SortOnClick)

		if i == 1 then
			sorter:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 10, -80-2)
		else
			sorter:SetPoint("LEFT", sortButtons[i-1], "RIGHT", -2, 0)
		end

		if i == 2 then
			-- make the main column wider
			WhoFrameColumn_SetWidth(sorter, 230)
		else
			WhoFrameColumn_SetWidth(sorter, sorter:GetTextWidth() + 16)
		end

		table.insert(sortButtons, sorter)
	end
	panel.sorters = sorters

	local bg = panel:CreateTexture(nil, "BACKGROUND")
		  bg:SetTexture("Interface\\TALENTFRAME\\spec-paper-bg")
		  bg:SetTexCoord(0, 0.76, 0, 0.86)
		  bg:SetPoint("TOPLEFT", 0, -78)
		  bg:SetPoint("BOTTOMRIGHT")

	local buttonHeight = 22
	local list = CreateFrame("ScrollFrame", "$parentList", panel, "FauxScrollFrameTemplate")
	list:SetSize(345, 305)
	list:SetPoint("TOPLEFT", bg, "TOPLEFT", 10, -6)
	list:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -10, -6)
	list:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, buttonHeight, ListUpdate)
	end)

	local function ItemButtonClick(self, btn)
		HandleModifiedItemClick(self.link)
	end

	list.scrollBarHideable = true
	list.buttons = {}
	for i = 1, 10 do
		local row = CreateFrame("Frame", nil, panel, nil, i)
		row:SetHeight(30)
		row:Hide()

		row:SetPoint("RIGHT", list, "RIGHT", 2, 0)
		if i == 1 then
			row:SetPoint("TOPLEFT", list, "TOPLEFT")
		else
			row:SetPoint("TOPLEFT", list.buttons[i-1], "BOTTOMLEFT", 0, 0)
		end

		-- ACHIEVEMENTFRAME\\UI-Achievement-HorizontalShadow
		local backdrop = row:CreateTexture(nil, "BACKGROUND")
		      backdrop:SetTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight")
		      backdrop:SetTexCoord(0, 1, 0, 0.578125)
		      backdrop:SetDesaturated(true)
		      backdrop:SetBlendMode("ADD")
		      backdrop:SetAllPoints()
		row.backdrop = backdrop

		local item = CreateFrame("Button", nil, row)
		      item:SetSize(26, 26)
		      item:SetPoint("LEFT", 2, 0)
		      item:SetScript("OnEnter", addon.ShowTooltip)
		      item:SetScript("OnLeave", addon.HideTooltip)
		      item:SetScript("OnClick", ItemButtonClick)
		row.item = item
		local icon = item:CreateTexture(nil, "BORDER")
		      icon:SetAllPoints()
		row.icon = icon

		local normalTexture = item:CreateTexture()
		      normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
		      normalTexture:SetSize(42, 42)
		      normalTexture:SetPoint("CENTER")
		item:SetNormalTexture(normalTexture)
		item:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
		item:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

		local name = row:CreateFontString(nil, nil, "GameFontHighlight")
			  name:SetPoint("LEFT", item, "RIGHT", 6, 0)
			  name:SetJustifyH("LEFT")
			  name:SetWidth(210)
		row.name = name
		local count = row:CreateFontString(nil, nil, "GameFontHighlight")
		      count:SetWidth(40)
		      count:SetPoint("LEFT", name, "RIGHT", 6, 0)
		      count:SetJustifyH("RIGHT")
		row.count = count
		local level = row:CreateFontString(nil, nil, "GameFontHighlight")
			  level:SetPoint("LEFT", count, "RIGHT", 6, 0)
			  level:SetPoint("RIGHT")
			  level:SetJustifyH("RIGHT")
		row.level = level

		table.insert(list.buttons, row)
	end
	panel.scrollFrame = list
end

function view:Update()
	local panel = self.panel
	local character = addon.GetSelectedCharacter()

	DataUpdate(character)
	table.sort(self.itemsTable, DataSort)

	panel.scrollFrame:SetVerticalScroll(0)
	ListUpdate(panel.scrollFrame)
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
		ListUpdate(self.panel.scrollFrame)
	end

	return hasMatch
end
