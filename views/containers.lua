local addonName, ns, _ = ...
local view = ns.CreateView("containers")

local AceTimer = LibStub("AceTimer-3.0")

view.itemsTable = {}
local primarySort, secondarySort

local function DataUpdate(characterKey)
	local characterKey = characterKey or ns.GetSelectedCharacter()
	local filter = addonName.."PanelContainersFilter"

	local showBags, showBank, showVoid = _G[filter.."Bags"]:GetChecked(), _G[filter.."Bank"]:GetChecked(), _G[filter.."VoidStorage"]:GetChecked()

	wipe(view.itemsTable)
	local containers = DataStore:GetContainers(characterKey)
	for bag, data in pairs(containers) do
		local bagIndex = tonumber(bag:match("Bag(%d+)") or "")
		if (bag == "VoidStorage" and showVoid) or
			(bagIndex and bagIndex <= NUM_BAG_SLOTS and showBags) or
			(bagIndex and (bagIndex == 100 or (bagIndex > NUM_BAG_SLOTS and bagIndex < NUM_BANKBAGSLOTS)) and showBank) then
			if bagIndex and bagIndex > NUM_BAG_SLOTS then
				bagIndex = (bagIndex == 100 and 0 or bagIndex) + NUM_BAG_SLOTS + 1
			end
			for i = 1, data.size do
				local itemID = data.ids[i]
				if itemID then
					table.insert(view.itemsTable, {
						itemID,
						string.format("%d.%.2d", bagIndex or 100, i),
						data.counts[i],
						data.links[i],
					})
				end
			end
		end
	end

	if _G[filter.."Mail"]:GetChecked() then
		for i = 1, DataStore:GetNumMails(characterKey) do
			local icon, count, link, money, text, returned = DataStore:GetMailInfo(characterKey, i)
			if link then
				local itemID = ns.GetLinkID(link)
				local _, itemLink = GetItemInfo(itemID)
				table.insert(view.itemsTable, {
					itemID,
					string.format("-1.%.4d", i),
					count,
					(itemLink ~= link and link or nil),
					DataStore:GetMailSender(characterKey, i),
					select(2,DataStore:GetMailExpiry(characterKey, i))
				})
			end
		end
	end
end

local function DataSort(a, b)
	-- FIXME: item level of upgraded items
	local namea, _, qualitya, iLevela, _, classa, subclassa = GetItemInfo(a[1])
	local nameb, _, qualityb, iLevelb, _, classb, subclassb = GetItemInfo(b[1])

	local reverse, s, sortA, sortB
	if primarySort then
		reverse = primarySort < 0
		s = math.abs(primarySort)
		sortA = (s == 1 and a[2]) or (s == 2 and namea) or (s == 3 and qualitya) or (s == 4 and (a[6] or iLevela)) or (a[5] or subclassa or classa)
		sortB = (s == 1 and b[2]) or (s == 2 and nameb) or (s == 3 and qualityb) or (s == 4 and (b[6] or iLevelb)) or (b[5] or subclassb or classb)
	end
	if (sortA ~= nil and sortB ~= nil) and sortA ~= sortB then
		if reverse then
			return sortA > sortB
		else
			return sortA < sortB
		end
	end

	if secondarySort then
		reverse = secondarySort < 0
		s = math.abs(secondarySort)
		sortA = (s == 1 and a[2]) or (s == 2 and namea) or (s == 3 and qualitya) or (s == 4 and (a[6] or iLevela)) or (a[5] or subclassa or classa)
		sortB = (s == 1 and b[2]) or (s == 2 and nameb) or (s == 3 and qualityb) or (s == 4 and (b[6] or iLevelb)) or (b[5] or subclassb or classb)
	end
	if (sortA ~= nil and sortB ~= nil) and sortA ~= sortB then
		if reverse then
			return sortA > sortB
		else
			return sortA < sortB
		end
	end

	return tonumber(a[2]) < tonumber(b[2])
end

local function ListUpdate(self)
	local offset = FauxScrollFrame_GetOffset(self)
	for i = 1, #self.buttons do
		local index = i + offset
		local item = self.buttons[i]

		if view.itemsTable[index] then
			local itemID, _, itemCount, itemLink, extra1, extra2 = unpack(view.itemsTable[index])
			local name, link, quality, iLevel, reqLevel, class, subclass, _, _, texture, _ = GetItemInfo(itemID)

			-- delay if we don't have data
			if not name then AceTimer:ScheduleTimer(ListUpdate, 0.1, self); return end

			SetItemButtonCount(item, itemCount)
			SetItemButtonTexture(item, texture)
			item.name:SetText(name)
			-- item.name:SetTextColor(ITEM_QUALITY_COLORS[quality].r, ITEM_QUALITY_COLORS[quality].g, ITEM_QUALITY_COLORS[quality].b, 1)
			if extra2 then
				item.level:SetFormattedText(SecondsToTimeAbbrev(extra2))
			else
				item.level:SetFormattedText("%4d", iLevel or 0)
			end
			item.info:SetText(extra1 or subclass or class)
			item.link = itemLink or link
			if quality and quality ~= 1 then
				item.searchOverlay:SetVertexColor(
					ITEM_QUALITY_COLORS[quality].r,
					ITEM_QUALITY_COLORS[quality].g,
					ITEM_QUALITY_COLORS[quality].b,
					0.8
				)
				item.searchOverlay:SetDesaturated(true)
				item.searchOverlay:Show()
			else
				item.searchOverlay:Hide()
			end
			item:Show()
		else
			item:Hide()
		end
	end

	local needsScrollBar = FauxScrollFrame_Update(self, #view.itemsTable, #self.buttons, 22)
	self:SetPoint("BOTTOMRIGHT", -10+(needsScrollBar and -18 or 0), 10)
end

local function Sort(self, btn)
	local newSort = self:GetID()
	local reverse = primarySort and math.abs(primarySort) == math.abs(newSort)
	secondarySort = reverse and  secondarySort or primarySort
	primarySort   = reverse and -1*primarySort or newSort

	local sorter, index = _G[addonName.."PanelContainersSorter1"], 1
	while sorter do
		if sorter == self then
			_G[sorter:GetName().."Arrow"]:Show()
			_G[sorter:GetName().."Arrow"]:SetTexCoord(0, 0.5625, primarySort > 0 and 1 or 0, primarySort > 0 and 0 or 1)
		else
			_G[sorter:GetName().."Arrow"]:Hide()
		end
		index = index + 1
		sorter = _G[addonName.."PanelContainersSorter"..index]
	end

	table.sort(view.itemsTable, DataSort)
	ListUpdate(view.panel.scrollFrame)
end

local function Filter(self)
	DataUpdate()
	table.sort(view.itemsTable, DataSort)
	ListUpdate(view.panel.scrollFrame)
end

local function ItemButtonClick(self, btn)
	HandleModifiedItemClick(self.link)
end

function view.Init()
	local panel = CreateFrame("Frame", addonName.."PanelContainers")
	local tab = ns.GetTab()
	tab:GetNormalTexture():SetTexture("Interface\\Buttons\\Button-Backpack-Up")
	tab.view = view

	local filters = {
		{"Bags", "Interface\\MINIMAP\\TRACKING\\Banker"},
		{"Bank", "INTERFACE\\ICONS\\achievement_guildperk_mobilebanking"},
		{"VoidStorage", "INTERFACE\\ICONS\\Spell_Nature_AstralRecalGroup"},
		{"Mail", "Interface\\MINIMAP\\TRACKING\\Mailbox"},
	}
	local filterButtons = {}
	for i, data in ipairs(filters) do
		local filter = CreateFrame("CheckButton", "$parentFilter"..data[1], panel, "PopupButtonTemplate", i) -- SimplePopupButtonTemplate
			  filter:SetNormalTexture(data[2])
			  filter:SetChecked(true)
			  filter:SetScript("OnClick", Filter)
			  filter:SetScript("OnEnter", ns.ShowTooltip)
			  filter:SetScript("OnLeave", ns.HideTooltip)
			  filter.tiptext = data[1]

		if i == 1 then
			filter:SetPoint("TOPLEFT", 10, -10)
		else
			filter:SetPoint("LEFT", filterButtons[i-1], "RIGHT", 10, 0)
		end
		table.insert(filterButtons, filter)
	end
	panel.filters = filterButtons

	local sorters = {"Count", "Name", "Quality", "Level", "Type"}
	local sortButtons = {}
	for i, name in ipairs(sorters) do
		local sorter = CreateFrame("Button", "$parentSorter"..i, panel, "AuctionSortButtonTemplate", i)
			  sorter:SetText(name)
			  sorter:SetSize(sorter:GetTextWidth() + 34, 19)
			  sorter:SetScript("OnClick", Sort)
		_G[sorter:GetName().."Arrow"]:Hide()

		if i == 1 then
			sorter:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 10, -80)
		else
			sorter:SetPoint("LEFT", sortButtons[i-1], "RIGHT", -2, 0)
		end
		-- stretch the last one
		if i == #sorters then
			sorter:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -10, -80)
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

	list.scrollBarHideable = true
	list.buttons = {}
	list.buttonScale = 28/37 -- ItemButtonTemplate is 37px but that's too big
	for i = 1, 10 do
		local item = CreateFrame("Button", "$parentListButton"..i, panel, "ItemButtonTemplate")
			  item:SetScale(list.buttonScale)
			  item:SetScript("OnEnter", ns.ShowTooltip)
			  item:SetScript("OnLeave", ns.HideTooltip)
			  item:SetScript("OnClick", ItemButtonClick)
		local name = item:CreateFontString(nil, nil, "GameFontNormalLarge")
			  name:SetPoint("LEFT", item, "RIGHT", 6, 0)
			  name:SetJustifyH("LEFT")
			  name:SetTextColor(1, 1, 1, 1)
			  name:SetWidth(250)
		item.name = name
		local level = item:CreateFontString(nil, nil, "ErrorFont")
			  level:SetPoint("LEFT", name, "RIGHT", 6, 0)
			  level:SetJustifyH("LEFT")
		item.level = level
		local info = item:CreateFontString(nil, nil, "ErrorFont")
			  info:SetPoint("LEFT", level, "RIGHT", 6, 0)
			  info:SetPoint("RIGHT", list, "RIGHT", 0, 0)
			  info:SetJustifyH("RIGHT")
		item.info = info

		item.searchOverlay:SetBlendMode("ADD")
		item.searchOverlay:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		item.searchOverlay:Show()

		if i == 1 then
			item:SetPoint("TOPLEFT", list, "TOPLEFT")
		else
			item:SetPoint("TOPLEFT", list.buttons[i-1], "BOTTOMLEFT", 0, -4)
		end
		item:Hide()

		table.insert(list.buttons, item)
	end
	panel.scrollFrame = list

	view.panel = panel
	return panel
end

function view.Update()
	local panel = view.panel
	assert(panel, "Can't update panel before it's created")
	-- local character = ns.GetSelectedCharacter()

	DataUpdate()
	table.sort(view.itemsTable, DataSort)
	panel.scrollFrame:SetVerticalScroll(0)
	ListUpdate(panel.scrollFrame)
end

local ItemSearch = LibStub('LibItemSearch-1.2')
function view.Search(what, onWhom)
	local hasMatch = 0
	if what and what ~= "" and what ~= SEARCH then
		DataUpdate(onWhom)
		for i = #view.itemsTable, 1, -1 do
			local _, link = GetItemInfo(view.itemsTable[i][1])
			-- TODO: also search sender name etc
			if not ItemSearch:Matches(link, what) then
				wipe(view.itemsTable[i])
				table.remove(view.itemsTable, i)
			else
				hasMatch = hasMatch + 1
			end
		end
		table.sort(view.itemsTable, DataSort)
		if view.panel:IsVisible() then
			ListUpdate(view.panel.scrollFrame)
		end
	else
		hasMatch = true
	end

	return hasMatch
end
