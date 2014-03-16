local addonName, addon, _ = ...

-- GLOBALS: _G, GameTooltip, LibStub
-- GLOBALS: CreateFrame, SetPortraitToTexture, PlaySound, EditBox_ClearFocus, FauxScrollFrame_OnVerticalScroll, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, OptionsList_ClearSelection, OptionsList_SelectButton, ToggleFrame
-- GLOBALS: gsub, type, pairs, tonumber, table, string, hooksecurefunc

-- FIXME: AceEvent-3.0 tends to run into "script ran too long" issues when other addons take too long
LibStub('AceAddon-3.0'):NewAddon(addon, addonName) --, 'AceEvent-3.0') -- TODO: FIXME: update modules to use AceEvent instead of our own event handler?

-- convenient and smart tooltip handling
function addon.ShowTooltip(self, anchor)
	if not self.tiptext and not self.link then return end
	if anchor and type(anchor) == 'table' then
		GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip:ClearLines()

	if self.link then
		GameTooltip:SetHyperlink(self.link)
	elseif type(self.tiptext) == "string" and self.tiptext ~= "" then
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	elseif type(self.tiptext) == "function" then
		self.tiptext(self, GameTooltip)
	end
	GameTooltip:Show()
end
function addon.HideTooltip() GameTooltip:Hide() end

-- utilities
-- counts table entries. for numerically indexed tables, use #table
function addon.Count(table)
	if not table or type(table) ~= "table" then return 0 end
	local i = 0
	for _ in pairs(table) do
		i = i + 1
	end
	return i
end

function addon.Find(where, what)
	for k, v in pairs(where) do
		if v == what then
			return k
		end
	end
end

function addon.GlobalStringToPattern(str)
	str = gsub(str, "([%(%)])", "%%%1")
	str = gsub(str, "%%%d?$?c", "(.+)")
	str = gsub(str, "%%%d?$?s", "(.+)")
	str = gsub(str, "%%%d?$?d", "(%%d+)")
	return str
end

function addon.GetLinkID(link)
	if not link or type(link) ~= "string" then return end
	local linkType, id = link:match("\124H([^:]+):([^:\124]+)")
	if not linkType then
		linkType, id = link:match("([^:\124]+):([^:\124]+)")
	end
	return tonumber(id), linkType
end

local characters = {}
local thisCharacter
function addon.OnInitialize()
	-- TODO: prepare settings
	-- fill char data
	addon.data.GetCharacters(characters)
	thisCharacter = addon.data.GetCurrentCharacter()

	-- enable modules when they are created
	-- addon:SetDefaultModuleState(true)

	-- initialize main frame
	local frame = CreateFrame('Frame', addonName..'UI', _G.UIParent, 'PortraitFrameTemplate')
	frame:Hide()
	addon.frame = frame

	SetPortraitToTexture(frame:GetName()..'Portrait', 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2')
	frame.TitleText:SetText(addonName)
	frame:EnableMouse()
	frame:SetWidth(563)

	frame:SetAttribute('UIPanelLayout-defined', true)
	frame:SetAttribute('UIPanelLayout-enabled', true)
	frame:SetAttribute('UIPanelLayout-whileDead', true)
	frame:SetAttribute('UIPanelLayout-area', 'left')
	frame:SetAttribute('UIPanelLayout-pushable', 5)
	frame:SetAttribute('UIPanelLayout-width', 563+20)

	-- have a sidebar where characters are listed
	local sidebar = CreateFrame('Frame', '$parentSidebar', frame)
		sidebar:SetPoint('TOPLEFT', 0, -22)
		sidebar:SetPoint('BOTTOMRIGHT', '$parent', 'BOTTOMLEFT', 170, 2)
		sidebar:SetWidth(170) -- needed so child scrollframe knows its size
	frame.sidebar = sidebar

	local sidebarBgTex = frame:CreateTexture(nil, 'BORDER', nil, -1)
		sidebarBgTex:SetTexture('Interface\\Common\\bluemenu-main')
		sidebarBgTex:SetTexCoord(0.00390625, 0.82421875, 0.18554688, 0.58984375)
		sidebarBgTex:SetAllPoints(sidebar)

	local separator = frame:CreateTexture(nil, 'BORDER')
		separator:SetTexture('Interface\\Common\\bluemenu-vert')
		separator:SetTexCoord(0.00781250, 0.04687500, 0, 1)
		separator:SetVertTile(true)
		separator:SetPoint('TOPLEFT', sidebar, 'TOPRIGHT')
		separator:SetPoint('BOTTOMRIGHT', sidebar, 'BOTTOMRIGHT', 5, 0)

	local buttonHeight = 28
	local characterList = CreateFrame('ScrollFrame', '$parentList', sidebar, 'FauxScrollFrameTemplate')
		characterList:SetPoint('TOPLEFT', 4, -40)
		characterList:SetPoint('BOTTOMRIGHT', -4, 2)
		characterList:SetScript('OnVerticalScroll', function(self, offset)
			FauxScrollFrame_OnVerticalScroll(self, offset, buttonHeight, addon.UpdateCharacters)
		end)

	characterList.selection = thisCharacter -- preselect active character
	characterList.scrollBarHideable = true
	-- use a wrapper so hooking SelectCharacter actually works
	local function OnCharacterButtonClick(self) addon.SelectCharacter(self) end
	-- setup character buttons
	characterList.buttons = {}
	for i = 1, 11 do -- TODO: might even fit 12, but needs resizing by search
		local button = CreateFrame('Button', '$parentButton'..i, sidebar, 'OptionsListButtonTemplate', i)
		local info = button:CreateFontString(nil, nil, 'GameFontNormal')
			  info:SetPoint('RIGHT', -10, 0)
			  info:SetJustifyH('RIGHT')
		button.info = info
		button.toggle = nil
		button.toggleFunc = nil

		if i == 1 then
			button:SetPoint('TOPLEFT', characterList, 'TOPLEFT')
		else
			button:SetPoint('TOPLEFT', characterList.buttons[i-1], 'BOTTOMLEFT', 0, -2)
		end
		button:SetHeight(buttonHeight)
		button:SetScript('OnClick', OnCharacterButtonClick)

		table.insert(characterList.buttons, button)
	end
	sidebar.scrollFrame = characterList

	-- actual content goes in here
	local content = CreateFrame('Frame', '$parentContent', frame)
		content:SetPoint('TOPLEFT', sidebar, 'TOPRIGHT', 5, 0)
		content:SetPoint('BOTTOMRIGHT', -4, 2)
		content:SetBackdrop({ bgFile = 'Interface\\RAIDFRAME\\UI-RaidFrame-GroupBg.png' })
	frame.content = content

	-- setup ldb launcher
	addon.ldb = LibStub:GetLibrary('LibDataBroker-1.1'):NewDataObject(addonName, {
		type  = 'launcher',
		icon  = 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2',
		label = addonName,

		OnClick = function(self, button)
			if button == 'RightButton' then
				-- open config
				-- InterfaceOptionsFrame_OpenToCategory(Viewda.options)
			else
				ToggleFrame(addon.frame)
			end
		end,
	})

	-- expose us
	_G[addonName] = addon
end

function addon.OnEnable()
	-- TODO? register events
	addon.UpdateCharacters()
	addon.Update()
end

function addon.OnDisable()
    -- unregister events
end

-- ~~~~~~~~~~~

function addon.UpdateCharacters()
	local scrollFrame = addon.frame.sidebar.scrollFrame
	local currentSelection = scrollFrame.selection
	OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)

	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	for i = 1, #scrollFrame.buttons do
		local button = scrollFrame.buttons[i]
		local index = i + offset
		local character = characters[index]

		if character then
			button:SetAlpha(1)
			button:Show()
			button.element = character

			local level = addon.data.GetLevel(character)
			button.info:SetText(level < 90 and level or '')

			local icon = addon.data.GetCharacterFactionIcon(character)
			local name = addon.data.GetCharacterText(character)
			button:SetText( (icon and icon..' ' or '') .. name )

			if button.element == currentSelection then
				-- just for proper UI state
				OptionsList_SelectButton(scrollFrame, button)
			end
		else
			button:Hide()
		end
	end

	local parent = scrollFrame:GetParent()
	local width  = parent:GetWidth()
	-- also update width of buttons to match (no) scroll bar
	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, #characters, #scrollFrame.buttons, scrollFrame.buttons[1]:GetHeight(), parent:GetName()..'Button', width - 18, width)
end

function addon.GetSelectedCharacter()
	local scrollFrame = addon.frame.sidebar.scrollFrame
	return scrollFrame.selection or thisCharacter -- TODO: how to handle for summaries?
end

function addon.SelectCharacter(button)
	local scrollFrame = addon.frame.sidebar.scrollFrame
	if button and type(button) == 'string' then
		-- figure out this character' list button
		for _, charButton in pairs(scrollFrame.buttons) do
			if charButton.element and charButton.element == button then
				button = charButton
				break
			end
		end
	end

	local currentCharacter = addon.GetSelectedCharacter()
	if currentCharacter == button.element then return end

	OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)
	if button then
		PlaySound("igMainMenuOptionCheckBoxOn")
		OptionsList_SelectButton(scrollFrame, button)
	end

	addon.Update()
end

function addon.Update()
	-- characterList.selection = ns.data.GetCurrentCharacter()
	-- update character list (names, info, ...)
	-- addon.UpdateCharacters()

	-- when showing views, initialize if needed
end

-- --------------------------------------------------------
--  Views
-- --------------------------------------------------------
-- each view will be a sub-module of the views module!
local views = addon:NewModule('views')
local prototype = {
	OnInitialize = function(self)
		-- supply views with panel and tab
		local viewName = self:GetName()
		local prettyName = viewName:gsub('^.',  string.upper)

		local panel = CreateFrame('Frame', '$parentPanel'..prettyName, addon.frame)
		self.panel = panel

		local tab = views.AddTab(self)
		self.tab = tab

		if self.icon then
			tab:GetNormalTexture():SetTexture(self.icon)
		end
		tab.tiptext = self.title or prettyName
		tab.module = viewName
		-- tab.element = panel
	end,
	Show = views.Show,
	Update = function() end, -- so we don't get errors if it doesn't exist
}
views:SetDefaultModulePrototype(prototype)

function views.OnInitialize()
	hooksecurefunc(addon, 'Update', views.Update)
end

local lastTabIndex = 0
local function OnTabClick(self)
	self:SetChecked(not self:GetChecked())
	views.Show( self.module )
end
function views.AddTab(view)
	local index = lastTabIndex + 1
	local tab = CreateFrame('CheckButton', '$parentTab'..index, addon.frame, 'SpellBookSkillLineTabTemplate', index)
	tab:Show()

	if index == 1 then
		tab:SetPoint('TOPLEFT', '$parent', 'TOPRIGHT', 0, -36)
	else
		tab:SetPoint('TOPLEFT', '$parentTab'..(index-1), 'BOTTOMLEFT', 0, -22)
	end

	tab:RegisterForClicks('AnyUp')
	tab:SetScript('OnEnter', addon.ShowTooltip)
	tab:SetScript('OnLeave', addon.HideTooltip)
	tab:SetScript('OnClick', OnTabClick)

	tab.element = view
	lastTabIndex = lastTabIndex + 1

	return tab
end

local currentView
function views.Show(view)
	view = view and type(view) == 'string' and views:GetModule(view, true) or view
	if (not view or type(view) == 'string') or (currentView and view == currentView) then return end

	local content = addon.frame.content
	if content.panel then
		-- hide old content panel
		content.panel:Hide()
		-- addon:SendMessage('TWINKLE_VIEW_HIDE', currentView:GetName())
	end

	local newPanel = view.panel
	-- now display new panel
	newPanel:SetParent(content)
	newPanel:ClearAllPoints()
	newPanel:SetAllPoints()
	newPanel:Show()

	content.panel = newPanel
	currentView = view

	views.Update()
	-- addon:SendMessage('TWINKLE_VIEW_SHOW', view:GetName())
end

function views.GetActiveView()
	return currentView
end

function views.Update()
	if not currentView then
		views.Show('default')
	end

	-- update tabs
	for index = 1, lastTabIndex do
		local tab = _G[addon.frame:GetName() .. 'Tab' .. index]
		tab:SetChecked( tab.element == currentView )
	end

	-- tell view to update, too
	currentView:Enable() -- TODO: in case it didn't init before, should not init twice
	currentView.Update()
end

-- --------------------------------------------------------
--  Legacy
-- --------------------------------------------------------
do
	-- GLOBALS: assert, format
	local eventFrame, eventHooks = CreateFrame("Frame", addonName.."EventHandler"), {}
	local function eventHandler(eventFrame, event, arg1, ...)
		if event == 'ADDON_LOADED' and arg1 == addonName then
			if not eventHooks[event] or addon.Count(eventHooks[event]) < 1 then
				eventFrame:UnregisterEvent(event)
			end
		end

		if eventHooks[event] then
			for id, listener in pairs(eventHooks[event]) do
				listener(eventFrame, event, arg1, ...)
			end
		end
	end
	eventFrame:SetScript("OnEvent", eventHandler)
	eventFrame:RegisterEvent("ADDON_LOADED")

	function addon.RegisterEvent(event, callback, id, silentFail)
		assert(callback and event and id, format("Usage: RegisterEvent(event, callback, id[, silentFail])"))
		if not eventHooks[event] then
			eventHooks[event] = {}
			eventFrame:RegisterEvent(event)
		end
		assert(silentFail or not eventHooks[event][id], format("Event %s already registered by id %s.", event, id))

		eventHooks[event][id] = callback
	end
	function addon.UnregisterEvent(event, id)
		if not eventHooks[event] or not eventHooks[event][id] then return end
		eventHooks[event][id] = nil
		if addon.Count(eventHooks[event]) < 1 then
			eventHooks[event] = nil
			eventFrame:UnregisterEvent(event)
		end
	end

	function addon.CreateView(name)
		local views = addon:GetModule('views')
		local view = views:NewModule(name)
		view.OnEnable = function(self) self.Init() end

		return view
	end
end

-- --------------------------------------------------------
--  *
-- --------------------------------------------------------
