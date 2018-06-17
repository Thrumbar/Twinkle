local addonName, addon, _ = ...
_G[addonName] = addon

-- GLOBALS: _G, GameTooltip, LibStub
-- GLOBALS: CreateFrame, SetPortraitToTexture, EditBox_ClearFocus, FauxScrollFrame_OnVerticalScroll, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, ToggleFrame
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

function addon:OnInitialize()
	local ui = addon:GetModule('ui')

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
		ui:Enable()
		ToggleFrame(self.frame)
	end)
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
				ui:Enable()
				ToggleFrame(self.frame)
			end
		end,
	})
end

function addon:OnEnable()
	self.db = LibStub('AceDB-3.0'):New(addonName..'DB', defaults, true)
	self:Update()
end

local autoUpdateModules = {'ui', 'views'}
function addon:AutoUpdateModule(moduleName)
	if tContains(autoUpdateModules, moduleName) then return end
	table.insert(autoUpdateModules, moduleName)
end
function addon:RemoveAutoUpdateModule(moduleName)
	tDeleteItem(autoUpdateModules, moduleName)
end

function addon:Update()
	for _, moduleName in pairs(autoUpdateModules) do
		local plugin = self:GetModule(moduleName, true)
		if plugin and plugin.Update then
			plugin:Update()
		end
	end
end
