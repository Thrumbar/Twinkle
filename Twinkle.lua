local addonName, addon, _ = ...
_G[addonName] = addon

-- GLOBALS: _G, GameTooltip, LibStub
-- GLOBALS: CreateFrame, SetPortraitToTexture, PlaySound, EditBox_ClearFocus, FauxScrollFrame_OnVerticalScroll, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, ToggleFrame
-- GLOBALS: gsub, type, pairs, tonumber, table, string, hooksecurefunc

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0')
addon.L = LibStub('AceLocale-3.0'):GetLocale(addonName, true)
local L = addon.L

local defaults = {
	profile = {
		factionIcon = 'Interface\\WorldStateFrame\\%sIcon',
		factionIconUndecided = 'Interface\\MINIMAP\\TRACKING\\BattleMaster',
		characterFilters = {
			['*'] = { -- options group: showLevel, showFaction ...
				['*'] = true,
			},
		},
	},
	char = {
		notes = '',
	}
}

-- see link types here: http://www.townlong-yak.com/framexml/19033/ItemRef.lua#162
local linkTypes = {'achievement', 'currency', 'enchant', 'glyph', 'instancelock', 'item', 'quest', 'spell', 'talent', 'unit'}

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
		-- not all links display in GameTooltip
		local _, linkType = addon.GetLinkID(self.link)
		if not tContains(linkTypes, linkType) then return end

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

local scanTooltip = CreateFrame('GameTooltip', addonName..'ScanTooltip', nil, 'GameTooltipTemplate')
addon.IsItemBOP = setmetatable({}, {
	__index = function(self, itemID)
		scanTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
		scanTooltip:SetItemByID(itemID)
		local binding = _G[scanTooltip:GetName().."TextLeft2"]:GetText()
		if not binding or binding:find(ITEM_LEVEL) then
			binding = _G[scanTooltip:GetName().."TextLeft3"]:GetText()
		end
		scanTooltip:Hide()
		if binding then
			self[itemID] = binding
			return binding
		end
	end ,
	__call = function(self, itemID)
		return self[itemID] == _G.ITEM_BIND_ON_PICKUP
	end
})

function addon.GetGradientColor(percent, maximum)
	if maximum and maximum ~= 0 then percent = percent / maximum end
	percent = percent > 1 and percent or percent * 100
	local _, x = math.modf(percent * 0.02)
	return (percent <= 50) and 1 or (percent >= 100) and 0 or (1 - x),
	       (percent >= 50) and 1 or (percent <= 0) and 0 or x,
	       0
end

function addon.ColorizeText(text, percent, maximum)
	local r, g, b = addon.GetGradientColor(percent, maximum)
	return ('|cff%02x%02x%02x%s|r'):format(r*255, g*255, b*255, text)
end

local function OnCharacterButtonClick(button, btn, up)
	if btn == 'RightButton' then
		-- TODO: delete characters, addon:DeleteCharacter(name, realm, account)
	else
		addon:SelectCharacter(button)
	end
end

local function InitializeFrame(frame)
	frame:SetScript('OnShow', function() PlaySound('igCharacterInfoOpen') end)
	frame:SetScript('OnHide', function() PlaySound('igCharacterInfoClose') end)
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
			leveling = 'Leveling',
		},
		Faction = {
			Horde = _G.FACTION_HORDE,
			Alliance = _G.FACTION_ALLIANCE,
			Other = _G.FACTION_OTHER,
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
		PlaySound('igMainMenuOptionCheckBoxOn')
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
	characterList:SetPoint('TOPLEFT', 4, -72)
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

function addon:OnInitialize()
	-- initialize main frame
	local frame = CreateFrame('Frame', addonName..'Frame', _G.UIParent, 'PortraitFrameTemplate')
	frame:SetFrameLevel(17)
	frame:EnableMouse(true)
	frame:Hide()
	self.frame = frame

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
	portraitButton:SetScript('OnClick', function(button, btn, up) ToggleFrame(self.frame) end)
	portraitButton.tiptext = L['Click to toggle Twinkle']

	-- setup ldb launcher
	addon.ldb = LibStub('LibDataBroker-1.1'):NewDataObject(addonName, {
		type  = 'launcher',
		icon  = 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2',
		label = addonName,

		OnClick = function(button, btn, up)
			if btn == 'RightButton' then
				InterfaceOptionsFrame_OpenToCategory(addonName)
			else
				ToggleFrame(self.frame)
			end
		end,
	})
end

function addon:OnEnable()
	self.db = LibStub('AceDB-3.0'):New(addonName..'DB', defaults, true)

	-- self.frame:SetScript('OnShow', InitializeFrame)
	InitializeFrame(self.frame)
	self:Update()

	self:RegisterMessage('TWINKLE_CHARACTER_DELETED')
end

function addon:OnDisable()
    self:UnregisterMessage('TWINKLE_CHARACTER_DELETED')
end

function addon:TWINKLE_CHARACTER_DELETED(event, characterKey)
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
		button:SetText( (icon and icon..' ' or '') .. name )
	end
end

local characters = {}
function addon:UpdateCharacters()
	local scrollFrame = self.frame.sidebar.scrollFrame
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	local characters = self.data.GetCharacters(characters)
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
			PlaySound('igMainMenuOptionCheckBoxOn')
			button.highlight:SetVertexColor(1, 1, 0)
			button:LockHighlight()
		else
			button.highlight:SetVertexColor(.196, .388, .8)
			button:UnlockHighlight()
		end
	end
	scrollFrame.selection = characterKey

	addon:Update()
	addon:SendMessage('TWINKLE_CHARACTER_CHANGED', listButton and listButton.element or nil)
end

local autoUpdateModules = {'views'}
function addon:AutoUpdateModule(moduleName)
	if tContains(autoUpdateModules, moduleName) then return end
	table.insert(autoUpdateModules, moduleName)
end
function addon:RemoveAutoUpdateModule(moduleName)
	tDeleteItem(autoUpdateModules, moduleName)
end

function addon:Update()
	-- update character list (names, info, ...)
	self:UpdateCharacters()

	for _, moduleName in pairs(autoUpdateModules) do
		local plugin = self:GetModule(moduleName, true)
		if plugin and plugin.Update then
			plugin:Update()
		end
	end
end
