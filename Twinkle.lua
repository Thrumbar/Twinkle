local addonName, addon, _ = ...
_G[addonName] = addon

-- GLOBALS: _G, GameTooltip, LibStub
-- GLOBALS: CreateFrame, SetPortraitToTexture, PlaySound, EditBox_ClearFocus, FauxScrollFrame_OnVerticalScroll, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, OptionsList_ClearSelection, OptionsList_SelectButton, ToggleFrame
-- GLOBALS: gsub, type, pairs, tonumber, table, string, hooksecurefunc

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0')

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
		local lineIndex = 2
		while self['tiptext'..lineIndex] do
			GameTooltip:AddLine(self['tiptext'..lineIndex], 1, 1, 1, nil, true)
			lineIndex = lineIndex + 1
		end
	elseif type(self.tiptext) == "function" then
		self.tiptext(self, GameTooltip)
	end
	GameTooltip:Show()
end
function addon.HideTooltip() GameTooltip:Hide() end

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
function addon:OnInitialize()
	-- TODO: prepare settings
	-- fill char data
	self.data.GetCharacters(characters)
	thisCharacter = self.data.GetCurrentCharacter()

	-- enable modules when they are created
	-- self:SetDefaultModuleState(true)

	-- initialize main frame
	local frame = CreateFrame('Frame', addonName..'Frame', _G.UIParent, 'PortraitFrameTemplate')
	frame:SetFrameLevel(17)
	frame:EnableMouse(true)
	frame:Hide()
	self.frame = frame

	SetPortraitToTexture(frame:GetName()..'Portrait', 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2')
	frame.TitleText:SetText(addonName)
	frame:EnableMouse(true)
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
		characterList:SetScript('OnVerticalScroll', function(scrollFrame, offset)
			FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, buttonHeight, self.UpdateCharacters)
		end)

	characterList.selection = thisCharacter -- preselect active character
	characterList.scrollBarHideable = true
	-- use a wrapper so hooking SelectCharacter actually works
	local function OnCharacterButtonClick(button) self.SelectCharacter(button) end
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
	      content:SetSize(frame:GetWidth() - sidebar:GetWidth(), frame:GetHeight() - 22 - 2)
	      content:SetPoint('TOPLEFT', sidebar, 'TOPRIGHT', 5, 0)
	      content:SetPoint('BOTTOMRIGHT', -4, 2)
	      content:SetBackdrop({ bgFile = 'Interface\\RAIDFRAME\\UI-RaidFrame-GroupBg.png' })
	frame.content = content

	-- quick launcher from the character frame
	local portraitButton = CreateFrame('Button', '$parentPortraitButton', CharacterFrame)
	      portraitButton:SetAllPoints(CharacterFrame.portrait)
	local highlight = portraitButton:CreateTexture(nil, 'OVERLAY')
	      highlight:SetAtlas('bags-roundhighlight', false)
	      highlight:SetAllPoints()
	portraitButton:SetHighlightTexture(highlight, 'ADD')
	CharacterFrame.portraitButton = portraitButton

	portraitButton:SetScript('OnEnter', self.ShowTooltip)
	portraitButton:SetScript('OnLeave', self.HideTooltip)
	portraitButton:SetScript('OnClick', function(button, btn, up)
		ToggleFrame(self.frame)
		PlaySound('igMainMenuOpen') -- 'igCharacterInfoTab')
	end)
	portraitButton.tiptext = 'Click to toggle Twinkle'

	-- setup ldb launcher
	addon.ldb = LibStub('LibDataBroker-1.1'):NewDataObject(addonName, {
		type  = 'launcher',
		icon  = 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2',
		label = addonName,

		OnClick = function(button, btn, up)
			if btn == 'RightButton' then
				-- open config
				-- InterfaceOptionsFrame_OpenToCategory(Viewda.options)
			else
				ToggleFrame(self.frame)
			end
		end,
	})
end

function addon:OnEnable()
	self.db = LibStub('AceDB-3.0'):New(addonName..'DB', {}, true)

	-- TODO: register events
	self:UpdateCharacters()
	self:Update()
end

function addon:OnDisable()
    -- unregister events
end

local maxLevel = GetMaxPlayerLevel()
function addon:UpdateCharacterButton(button, characterKey)
	if not characterKey then
		button:Hide()
	else
		button:SetAlpha(1)
		button:Show()
		button.element = characterKey

		local level = addon.data.GetLevel(characterKey)
		button.info:SetText(level < maxLevel and level or '')

		local icon = addon.data.GetCharacterFactionIcon(characterKey)
		local name = addon.data.GetCharacterText(characterKey)
		button:SetText( (icon and icon..' ' or '') .. name )
	end
end

function addon:UpdateCharacters()
	local scrollFrame = addon.frame.sidebar.scrollFrame
	local currentSelection = scrollFrame.selection
	OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)

	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	for i = 1, #scrollFrame.buttons do
		local button = scrollFrame.buttons[i]
		local index = i + offset

		addon:UpdateCharacterButton(button, characters[index])

		if button.element == currentSelection then
			-- just for proper UI state
			OptionsList_SelectButton(scrollFrame, button)
		end
	end

	local parent = scrollFrame:GetParent()
	local width  = parent:GetWidth()
	-- also update width of buttons to match (no) scroll bar
	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, #characters, #scrollFrame.buttons, scrollFrame.buttons[1]:GetHeight(), parent:GetName()..'Button', width - 18, width)
end

function addon.GetCharacterButton(characterKey)
	local scrollFrame, button = addon.frame.sidebar.scrollFrame, nil
	for i = 1, #scrollFrame.buttons do
		if scrollFrame.buttons[i].element == characterKey then
			button = scrollFrame.buttons[i]
		end
	end
	return button
end

function addon.GetSelectedCharacter()
	local scrollFrame = addon.frame.sidebar.scrollFrame
	return scrollFrame.selection or thisCharacter
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
		PlaySound('igMainMenuOptionCheckBoxOn')
		OptionsList_SelectButton(scrollFrame, button)
	end

	addon:Update()
	addon:SendMessage('TWINKLE_CHARACTER_CHANGED', button.element)
end

function addon:Update()
	-- TODO: FIXME: this is ugly, do something like this:
	--[[ for name, subModule in self:IterateModules() do
		if subModule.Update then
			subModule:Update()
		end
	end --]]

	local views = self:GetModule('views', true)
	if views then views:Update() end

	-- update character list (names, info, ...)
	self:UpdateCharacters()
end
