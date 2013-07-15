local addonName, ns, _ = ...

local function ButtonOnClick(self, btn)
	PlaySound("igMainMenuOptionCheckBoxOn")

	local scrollFrame = self:GetParent().scrollFrame
	OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)
	OptionsList_SelectButton(scrollFrame, self)

	if self.element and type(self.element) == "table" then
		InterfaceOptionsList_DisplayPanel(self.element)
	end
end

local characters = {}
local function CharacterListUpdate(self)
	local numButtons = #self.buttons
	local parent = self:GetParent()

	wipe(characters)
	for characterName, characterKey in pairs(DataStore:GetCharacters()) do
		table.insert(characters, characterName)
	end
	table.sort(characters)

	local selection = self.selection
	OptionsList_ClearSelection(self, self.buttons)

	local offset = FauxScrollFrame_GetOffset(self)
	for i = 1, numButtons do
		local index = i + offset
		local button = self.buttons[i]

		if characters[index] then
			button.element = characters[index] -- TODO: use actual panel here!
			button:SetText( characters[index] )
			button:Show()

			if button.element == selection then
				-- just for proper UI state
				OptionsList_SelectButton(self, button)
			end
		else
			button:Hide()
		end
	end

	if selection then self.selection = selection end

	local width = parent:GetWidth()
	local needsScrollBar = FauxScrollFrame_Update(self, #characters, numButtons, self.buttons[1]:GetHeight(), parent:GetName().."Button", width - 18, width)
end

local function Initialize()
	local frame = CreateFrame("Frame", addonName.."UI", UIParent, "PortraitFrameTemplate")
	frame:EnableMouse()
	frame:SetWidth(563)

	frame:SetAttribute("UIPanelLayout-defined", true)
	frame:SetAttribute("UIPanelLayout-enabled", true)
	frame:SetAttribute("UIPanelLayout-whileDead", true)
	frame:SetAttribute("UIPanelLayout-area", "left")
	frame:SetAttribute("UIPanelLayout-pushable", 5)
	frame:SetAttribute("UIPanelLayout-width", 563+20)

	SetPortraitToTexture(frame:GetName().."Portrait", "Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2")
	frame.TitleText:SetText(addonName)

	local sidebar = CreateFrame("Frame", "$parentSidebar", frame)
		sidebar:SetPoint("TOPLEFT", 0, -26)
		sidebar:SetPoint("BOTTOMRIGHT", "$parent", "BOTTOMLEFT", 170, 0)

	local sidebarBgTex = frame:CreateTexture(nil, "BORDER", nil, -1)
		sidebarBgTex:SetTexture("Interface\\Common\\bluemenu-main")
		sidebarBgTex:SetTexCoord(0.00390625, 0.82421875, 0.18554688, 0.58984375)
		sidebarBgTex:SetAllPoints(sidebar)

	local separator = frame:CreateTexture(nil, "BORDER")
		separator:SetTexture("Interface\\Common\\bluemenu-vert")
		separator:SetTexCoord(0.00781250, 0.04687500, 0, 1)
		separator:SetVertTile(true)
		separator:SetPoint("TOPLEFT", sidebar, "TOPRIGHT")
		separator:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 5, 0)

	-- == Sidebar Contents ========================
	local searchbox = CreateFrame("EditBox", "$parentSearchBox", sidebar, "SearchBoxTemplate")
		searchbox.clearFunc = function(self) end
		searchbox:SetPoint("BOTTOM", 4, 4)
		searchbox:SetSize(160, 20)
		searchbox:SetScript("OnEnterPressed", EditBox_ClearFocus)
		searchbox:SetScript("OnEscapePressed", function(self)
			PlaySound("igMainMenuOptionCheckBoxOn")
			self:SetText(SEARCH)
			EditBox_ClearFocus(self)
		end)
		searchbox:SetScript("OnTextChanged", function(self)
			local oldText, text = self.searchString, self:GetText()
			if text == "" or text == SEARCH then self.searchString = nil
			else self.searchString = string.lower(text) end

			if oldText ~= self.searchString then
				-- TODO: search
			end
		end)

	local buttonHeight = 28
	local characterList = CreateFrame("ScrollFrame", "$parentList", sidebar, "FauxScrollFrameTemplate")
		characterList:SetPoint("TOPLEFT", 4, -36)
		characterList:SetPoint("BOTTOMRIGHT", searchbox, "TOPRIGHT", -22, 0)
		characterList:SetScript("OnVerticalScroll", function(self, offset)
			FauxScrollFrame_OnVerticalScroll(self, offset, buttonHeight, CharacterListUpdate)
		end)

	sidebar.scrollFrame = characterList
	characterList.scrollBarHideable = true
	characterList.buttons = {}
	for i = 1, 11 do
		local button = CreateFrame("Button", "$parentButton"..i, sidebar, "OptionsListButtonTemplate", i)
		if i == 1 then
			button:SetPoint("TOPLEFT", characterList, "TOPLEFT")
		else
			button:SetPoint("TOPLEFT", characterList.buttons[i-1], "BOTTOMLEFT", 0, -2)
		end
		button:SetHeight(buttonHeight)
		button:SetScript("OnClick", ButtonOnClick)

		table.insert(characterList.buttons, button)
	end

	HideUIPanel(frame)
	ShowUIPanel(frame)

	CharacterListUpdate(characterList)
	searchbox:SetText(SEARCH)
end


function ns.ToggleUI()
	local frame = _G[addonName.."UI"]
	if not frame then
		Initialize()
	else
		ToggleFrame(frame)
	end
end

--[[-- gold colored horizontal line:
local line = frame:CreateTexture()
line:SetTexture(0.74, 0.52, 0.06)
line:SetSize(339, 1)
--]]
