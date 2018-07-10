local addonName, addon, _ = ...

-- GLOBALS: _G, GameTooltip, NORMAL_FONT_COLOR
-- GLOBALS: hooksecurefunc, IsAddOnLoaded
-- GLOBALS: print, wipe, pairs, ipairs, tonumber, string, table

local ui = addon:NewModule('ui', 'AceEvent-3.0')
ui:SetEnabledState(false)
local L = addon.L

function ui:Update()
	if not addon.frame then return end
	-- update character list (names, info, ...)
	addon:UpdateCharacters()
end

function ui:OnEnable()
	self:Initialize()
	self:RegisterMessage('TWINKLE_CHARACTER_DELETED')

	addon:Update()
end

function ui:OnDisable()
    self:UnregisterMessage('TWINKLE_CHARACTER_DELETED')
end

function ui:TWINKLE_CHARACTER_DELETED(event, characterKey)
	if characterKey == self.frame.sidebar.scrollFrame.selection then
		self.frame.sidebar.scrollFrame.selection = addon.data.GetCurrentCharacter()
		self:Update()
	end
end

local function GetFactionIcon(characterKey)
	local faction = addon.data.GetCharacterFaction(characterKey)
	local icon    = addon.db.profile.factionIcon
	if faction ~= 'Horde' and faction ~= 'Alliance' then
		icon = addon.db.profile.factionIconUndecided
	end
	if icon and icon ~= '' then
		return '|T' .. icon:format(faction) .. ':22|t'
	else
		return ''
	end
end

local function OnCharacterButtonClick(button, btn, up)
	if btn == 'RightButton' then
		-- TODO: delete characters, addon:DeleteCharacter(name, realm, account)
	else
		addon:SelectCharacter(button)
	end
end

function ui:Initialize()
	if addon.frame then return end

	local frame = CreateFrame('Frame', addonName .. 'Frame', _G.UIParent, 'PortraitFrameTemplate')
	addon.frame = frame

	frame:SetFrameLevel(17)
	frame:EnableMouse(true)
	frame:Hide()
	frame:SetScript('OnShow', function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end)
	frame:SetScript('OnHide', function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)
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

	local thisRealm = GetRealmName()
	local filterOptions = {
		Level = {
			maxLevel = _G.GUILD_RECRUITMENT_MAXLEVEL,
			leveling = _G.PLAYER_LEVEL_UP,
		},
		Faction = {
			current = _G.REFORGE_CURRENT,
			Horde = _G.FACTION_HORDE,
			Alliance = _G.FACTION_ALLIANCE,
			Other = _G.FACTION_OTHER,
		},
		Realm = {
			current = _G.REFORGE_CURRENT,
		},
	}
	if addon.data.CharacterFilters then filterOptions = addon.data.CharacterFilters(filterOptions) end

	local function FilterOnClick(self, menuList, key, isChecked)
		if not menuList then return end
		addon.db.profile.characterFilters[menuList][key] = isChecked
		addon:Update()
	end

	local filterButton = CreateFrame('Button', '$parentFilterButton', sidebar, 'UIMenuButtonStretchTemplate')
	filterButton:SetSize(93+10, 22)
	filterButton:SetText(_G.FILTER)
	filterButton:SetPoint('TOPRIGHT', -6, -6)
	filterButton:SetScript('OnClick', function(self, btn, up)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ToggleDropDownMenu(nil, nil, self.filterDropDown, self:GetName(), 74, 15, filterOptions)
	end)
	local filterArrow = filterButton:CreateTexture(nil, 'ARTWORK')
	filterArrow:SetTexture('Interface\\ChatFrame\\ChatFrameExpandArrow')
	filterArrow:SetSize(10, 12)
	filterArrow:SetPoint('RIGHT', -5, 0)

	filterButton.filterDropDown = CreateFrame('Frame', '$parentFilterDropDown', filterButton, 'UIDropDownMenuTemplate')
	filterButton.filterDropDown.filterOptions = filterOptions
	filterButton.filterDropDown.displayMode = 'MENU'
	filterButton.filterDropDown.initialize = function(self, level, menuList)
		local info = UIDropDownMenu_CreateInfo()
		info.isNotRadio = true
		info.keepShownOnClick = true
		info.func = FilterOnClick

		local options = type(menuList) == 'table' and menuList or self.filterOptions[menuList]
		for key, value in pairs(options) do
			info.value = key
			if type(value) == 'table' then
				info.text = rawget(L, 'characterFilter' .. key) or key
				info.notCheckable = true
				info.hasArrow = true
				info.menuList = key
			else
				info.text = value
				info.notCheckable = nil
				info.hasArrow = nil
				info.menuList = nil
				info.checked = addon.db.profile.characterFilters[menuList][key]
				info.arg1 = menuList
				info.arg2 = key
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end

	local characterList = CreateFrame('ScrollFrame', '$parentList', sidebar, 'FauxScrollFrameTemplate')
	characterList:SetPoint('TOPLEFT', 4, -70)
	characterList:SetPoint('BOTTOMRIGHT', -4, 2)
	characterList:SetScript('OnVerticalScroll', function(scrollFrame, offset)
		FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, scrollFrame[1]:GetHeight(), function()
			addon:UpdateCharacters()
		end)
	end)

	characterList.selection = addon.data.GetCurrentCharacter() -- preselect active character
	characterList.scrollBarHideable = true
	sidebar.scrollFrame = characterList

	-- setup character buttons
	for i = 1, 11 do
		local button = CreateFrame('Button', '$parentCharacter'..i, sidebar, nil, i)
		      button:SetHeight(28)
		if i == 1 then
			button:SetPoint('TOPLEFT', characterList, 'TOPLEFT')
		else
			button:SetPoint('TOPLEFT', characterList[i-1], 'BOTTOMLEFT', 0, -2)
		end
		button:SetPoint('RIGHT', characterList, 'RIGHT')
		button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
		button:SetScript('OnClick', OnCharacterButtonClick)
		button:SetScript('OnEnter', OptionsListButton_OnEnter)
		button:SetScript('OnLeave', OptionsListButton_OnLeave)

		button:SetNormalFontObject('GameFontNormal')
		button:SetHighlightFontObject('GameFontHighlight')
		button:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestLogTitleHighlight', 'ADD')
		button.highlight = button:GetHighlightTexture()

		local info = button:CreateFontString(nil, nil, 'GameFontNormal')
			  info:SetPoint('RIGHT')
			  info:SetJustifyH('RIGHT')
		button.info = info

		local text = button:CreateFontString(nil, nil, 'GameFontNormal')
		      text:SetJustifyH('LEFT')
		      text:SetPoint('LEFT')
		      text:SetPoint('RIGHT', info, 'LEFT', -2, 0)
		button.text = text
		button:SetFontString(text)

		table.insert(characterList, button)
	end
	FauxScrollFrame_Update(characterList, 0, #characterList, characterList[1]:GetHeight())

	-- actual content goes in here
	local content = CreateFrame('Frame', '$parentContent', frame)
	      content:SetSize(frame:GetWidth() - sidebar:GetWidth(), frame:GetHeight() - 22 - 2)
	      content:SetPoint('TOPLEFT', sidebar, 'TOPRIGHT', 5, 0)
	      content:SetPoint('BOTTOMRIGHT', -4, 2)
	      content:SetBackdrop({ bgFile = 'Interface\\RAIDFRAME\\UI-RaidFrame-GroupBg.png' })
	frame.content = content
end

local maxLevel = GetMaxPlayerLevel()
function addon:UpdateCharacterButton(button, characterKey)
	if not characterKey then
		button.element = nil
		button:Hide()
	else
		button:SetAlpha(1)
		button:Show()
		button.element = characterKey

		local level = addon.data.GetLevel(characterKey)
		button.info:SetText(level < maxLevel and level or '')

		local icon = GetFactionIcon(characterKey)
		local name = addon.data.GetCharacterText(characterKey)
		button:SetText((icon and icon..' ' or '') .. name)
	end
end

--[[-- @todo Allow specifying sort order.
local function characterSort(a, b)
	-- Sort options:
	-- Realm, Name, Level, Faction, Race, Class, Armor Type.
	return a < b
end--]]

local characters = {}
local characterSort
function addon:UpdateCharacters()
	local scrollFrame = self.frame.sidebar.scrollFrame
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	local characters = self.data.GetCharacters(characters, characterSort)
	for i, button in ipairs(scrollFrame) do
		local index = i + offset
		self:UpdateCharacterButton(button, characters[index])

		if button.element == scrollFrame.selection then
			button.highlight:SetVertexColor(1, 1, 0)
			button:LockHighlight()
		else
			button.highlight:SetVertexColor(.196, .388, .8)
			button:UnlockHighlight()
		end
	end

	-- adjustments so rows have decent padding with and without scroll bar
	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, #characters, #scrollFrame, scrollFrame[1]:GetHeight())
	scrollFrame:SetPoint('BOTTOMRIGHT', -4 + (needsScrollBar and -20 or 0), 2)
end

function addon:GetSelectedCharacter()
	local scrollFrame = addon.frame.sidebar.scrollFrame
	return scrollFrame.selection
end

-- accepts characterKey or listButton to select, or nil to deselect all
function addon:SelectCharacter(characterKey)
	local scrollFrame = addon.frame.sidebar.scrollFrame
	if type(characterKey) == 'table' then
		characterKey = characterKey.element
	end

	-- already displaying this character
	if characterKey == addon:GetSelectedCharacter() then return end

	for i, button in ipairs(scrollFrame) do
		if button.element == characterKey then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			button.highlight:SetVertexColor(1, 1, 0)
			button:LockHighlight()
		else
			button.highlight:SetVertexColor(.196, .388, .8)
			button:UnlockHighlight()
		end
	end
	scrollFrame.selection = characterKey

	addon:Update()
	addon:SendMessage('TWINKLE_CHARACTER_CHANGED', characterKey)
end
