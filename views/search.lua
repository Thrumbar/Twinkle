local addonName, ns, _ = ...
local view = ns.CreateView("search")

-- GLOBALS: _G, AceTimer, ITEM_QUALITY_COLORS
-- GLOBALS: CreateFrame, GetSpellInfo, GetSpellLink, GetItemInfo, SetItemButtonTexture, SetItemButtonCount, FauxScrollFrame_GetOffset, FauxScrollFrame_Update, FauxScrollFrame_OnVerticalScroll
-- GLOBALS: table, string, pairs, ipairs, strsplit, assert

local function ButtonUpdate(button, itemID, locations)
	local name, link, texture, quality, info
	if itemID < 0 then
		itemID = -1 * itemID
		name, _, texture = GetSpellInfo(itemID)
		link = GetSpellLink(itemID)
		quality = 6
	else
		name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)
	end

	-- delay if we don't have data
	if not name then AceTimer:ScheduleTimer(ButtonUpdate, 0.1, button, itemID, locations); return end

	SetItemButtonTexture(button, texture)
	button.name:SetText(name)
	button.link = link

	if quality and quality ~= 1 then
		button.searchOverlay:SetVertexColor(
			ITEM_QUALITY_COLORS[quality].r,
			ITEM_QUALITY_COLORS[quality].g,
			ITEM_QUALITY_COLORS[quality].b,
			0.8
		)
		button.searchOverlay:SetDesaturated(true)
		button.searchOverlay:Show()
	else
		button.searchOverlay:Hide()
	end

	local totals, locationsText = 0, nil
	for charLocation, count in pairs(locations) do
		totals = totals + count
		local character, location = strsplit("|", charLocation)
		locationsText = (locationsText and locationsText .. ', ' or '') .. ns.data.GetCharacterText(character)
	end
	button.info:SetText(locationsText)
	SetItemButtonCount(button, totals)
end

local function ListUpdate(self)
	local searchResults = ns.search.GetResults()
	local buttonIndex, numButtons, offset = 1, #self.buttons, FauxScrollFrame_GetOffset(self)

	local index = 0
	for itemID, locations in pairs(searchResults) do
		index = index + 1
		if index == buttonIndex+offset then
			ButtonUpdate(self.buttons[buttonIndex], itemID, locations)
			self.buttons[buttonIndex]:Show()

			buttonIndex = buttonIndex + 1
			if buttonIndex > numButtons then
				break
			end
		end
	end

	for i = buttonIndex, #self.buttons do
		self.buttons[i]:Hide()
	end

	local needsScrollBar = FauxScrollFrame_Update(self, ns.Count(searchResults), numButtons, 22)
	self:SetPoint("BOTTOMRIGHT", -10+(needsScrollBar and -18 or 0), 10)
end

function view.Init()
	local tab = ns.GetTab()
	tab:GetNormalTexture():SetTexture("Interface\\MINIMAP\\TRACKING\\None")
	tab.view = view

	local panel = CreateFrame("Frame", addonName.."PanelSearch")

	local sorters = {"Name", "Quality", "Level", "Type", "Owner"}
	local sortButtons = {}
	for i, name in ipairs(sorters) do
		local sorter = CreateFrame("Button", "$parentSorter"..i, panel, "AuctionSortButtonTemplate", i)
			  sorter:SetText(name)
			  sorter:SetSize(sorter:GetTextWidth() + 34, 19)
			  -- sorter:SetScript("OnClick", Sort) -- TODO
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
			  -- item:SetScript("OnClick", ItemButtonClick)
		local name = item:CreateFontString(nil, nil, "GameFontNormalLarge")
			  name:SetPoint("LEFT", item, "RIGHT", 6, 0)
			  name:SetJustifyH("LEFT")
			  name:SetTextColor(1, 1, 1, 1)
			  name:SetWidth(250)
		item.name = name
		local info = item:CreateFontString(nil, nil, "ErrorFont")
			  info:SetPoint("TOPLEFT", item, "TOPRIGHT", 262, 0)
			  info:SetPoint("BOTTOM", item, "BOTTOM")
			  info:SetPoint("RIGHT", list, "RIGHT")
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

	-- DataUpdate()
	-- table.sort(view.itemsTable, DataSort)
	panel.scrollFrame:SetVerticalScroll(0)
	ListUpdate(panel.scrollFrame)
end
