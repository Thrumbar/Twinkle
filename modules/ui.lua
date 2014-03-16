local addonName, ns, _ = ...

-- GLOBALS: _G, UIParent, SEARCH
-- GLOBALS: PlaySound, OptionsList_ClearSelection, OptionsList_SelectButton, CreateFrame, ShowUIPanel, HideUIPanel, ToggleFrame, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, FauxScrollFrame_OnVerticalScroll, SetPortraitToTexture, EditBox_ClearFocus
-- GLOBALS: type, table

local function ButtonOnClick(self, btn)
	PlaySound("igMainMenuOptionCheckBoxOn")

	local scrollFrame = self:GetParent().scrollFrame
	OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)
	OptionsList_SelectButton(scrollFrame, self)

	ns.UpdatePanel()
end

local characters = {}
local function CharacterListUpdate(self)
	-- fill char data
	ns.data.GetCharacters(characters)

	local selection = self.selection
	OptionsList_ClearSelection(self, self.buttons)

	local offset = FauxScrollFrame_GetOffset(self)
	for i = 1, #self.buttons do
		local index = i + offset
		local button = self.buttons[i]

		if characters[index] then
			local level = ns.data.GetLevel(characters[index])
			button.info:SetText(level < 90 and level or '')

			button.element = characters[index] -- TODO: use actual panel here!
			local icon = ns.data.GetCharacterFactionIcon(characters[index])
			local name = ns.data.GetCharacterText(characters[index])
			button:SetText( (icon and icon..' ' or '') .. name )
			button:SetAlpha(1)
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

	local parent = self:GetParent()
	local width = parent:GetWidth()
	local needsScrollBar = FauxScrollFrame_Update(self, #characters, #self.buttons, self.buttons[1]:GetHeight(), parent:GetName().."Button", width - 18, width)
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
		sidebar:SetPoint("TOPLEFT", 0, -22)
		sidebar:SetPoint("BOTTOMRIGHT", "$parent", "BOTTOMLEFT", 170, 2)
	frame.sidebar = sidebar

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

	local content = CreateFrame("Frame", "$parentContent", frame)
		content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 5, 0)
		content:SetPoint("BOTTOMRIGHT", -4, 2)
		content:SetBackdrop({ bgFile = 'Interface\\RAIDFRAME\\UI-RaidFrame-GroupBg.png' })
	frame.content = content

	local searchbox = CreateFrame("EditBox", "$parentSearchBox", sidebar, "SearchBoxTemplate")
		searchbox:SetPoint("BOTTOM", 4, 2)
		searchbox:SetSize(160, 20)
		searchbox:SetScript("OnEnterPressed", EditBox_ClearFocus)
		searchbox:SetScript("OnEscapePressed", function(self)
			PlaySound("igMainMenuOptionCheckBoxOff")
			self:SetText(SEARCH)
			EditBox_ClearFocus(self)
			self:clearFunc()
		end)
		searchbox:SetScript("OnTextChanged", ns.search.Update)
		searchbox.clearFunc = ns.search.Reset
	frame.search = searchbox

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
		local info = button:CreateFontString(nil, nil, "GameFontNormal")
			  info:SetPoint("RIGHT", -10, 0)
			  info:SetJustifyH("RIGHT")
		button.info = info
		button.toggle = nil
		button.toggleFunc = nil

		if i == 1 then
			button:SetPoint("TOPLEFT", characterList, "TOPLEFT")
		else
			button:SetPoint("TOPLEFT", characterList.buttons[i-1], "BOTTOMLEFT", 0, -2)
		end
		button:SetHeight(buttonHeight)
		button:SetScript("OnClick", ButtonOnClick)

		table.insert(characterList.buttons, button)
	end
	characterList.selection = ns.data.GetCurrentCharacter()

	for i, view in ipairs(ns.views) do
		view.Init()
	end

	HideUIPanel(frame)
	ShowUIPanel(frame)

	CharacterListUpdate(characterList)
	ns.DisplayPanel("default")
end

function ns.SetSelectedCharacter(character)
	local frame = _G[addonName.."UI"]
	if not frame then return end
	frame.sidebar.scrollFrame.selection = character or ns.data.GetCurrentCharacter()
	ns.Update()
end
function ns.GetSelectedCharacter()
	local frame = _G[addonName.."UI"]
	return frame and frame.sidebar.scrollFrame.selection or ns.data.GetCurrentCharacter()
end

function ns.SetCharacterInfo(character, info)
	local frame = _G[addonName.."UI"]
	if not frame then return end

	local scrollFrame = frame.sidebar.scrollFrame
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	for i = 1, #scrollFrame.buttons do
		local index = i + offset
		local button = scrollFrame.buttons[i]

		if characters[index] and characters[index] == character then
			button.info:SetText(info or '')
		end
	end
end

function ns.GetCurrentView()
	local frame = _G[addonName.."UI"]
	local panel = frame.content and frame.content.displayedPanel

	for i, v in ipairs(ns.views) do
		if v.panel == panel then
			return v
		end
	end
end

function ns.DisplayPanel(panel)
	local frame = _G[addonName.."UI"]
	if not frame then return end

	local view
	if type(panel) == "string" then
		for i, v in ipairs(ns.views) do
			if v.name == panel then
				view = v
				break
			end
		end
		assert(view, "No view with name '"..panel.."' found!")
		panel = view.panel or view:Init()
	end

	local content = frame.content
	if content.displayedPanel then
		content.displayedPanel:Hide()
	end
	content.displayedPanel = panel

	panel:SetParent(content)
	panel:ClearAllPoints()
	panel:SetAllPoints()
	panel:Show()

	ns.UpdatePanel()
	ns.UpdateTabs()
end

local function TabOnClick(self, btn)
	ns.DisplayPanel(self.view.name)
end

local lastTabIndex = 1
function ns.GetTab(index, noCreate)
	index = index or lastTabIndex
	local tab = _G[addonName.."UITab"..index]
	if not tab and not noCreate then
		tab = CreateFrame("CheckButton", "$parentTab"..index, _G[addonName.."UI"], "SpellBookSkillLineTabTemplate", index)
		tab:Show()
		if index == 1 then
			tab:SetPoint("TOPLEFT", "$parent", "TOPRIGHT", 0, -36)
		else
			tab:SetPoint("TOPLEFT", "$parentTab"..(index-1), "BOTTOMLEFT", 0, -22)
		end

		tab:RegisterForClicks("AnyUp")
		tab:SetScript("OnEnter", ns.ShowTooltip)
		tab:SetScript("OnLeave", ns.HideTooltip)
		tab:SetScript("OnClick", TabOnClick)
		lastTabIndex = lastTabIndex + 1
	end
	return tab
end

function ns.UpdateSidebar()
	local frame = _G[addonName.."UI"]
	if not frame or not frame.sidebar then return end
	CharacterListUpdate(frame.sidebar.scrollFrame)
end
function ns.UpdatePanel()
	local frame = _G[addonName.."UI"]
	local view = ns.GetCurrentView()
	if view then
		view:Update()
		if view.Search then
			view.Search(frame.search.searchString, ns.GetSelectedCharacter())
		end
	end
end
function ns.UpdateTabs()
	local currentView = ns.GetCurrentView()
		  currentView = currentView and currentView.name or nil
	local index = 1
	local tab = _G[addonName.."UITab"..index]
	while tab do
		tab:SetChecked(tab.view.name == currentView)
		index = index + 1
		tab = _G[addonName.."UITab"..index]
	end
end
function ns.Update()
	ns.UpdateSidebar()
	ns.UpdatePanel()
	ns.UpdateTabs()
end

function ns.ToggleUI()
	local frame = _G[addonName.."UI"]
	if not frame then
		Initialize()
	else
		ToggleFrame(frame)
	end
end
