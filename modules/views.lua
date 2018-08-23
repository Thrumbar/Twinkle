local addonName, addon, _ = ...
local emptyTable = {}

-- each view will be a sub-module of the views module!
local views = addon:NewModule('views', 'AceEvent-3.0')
local prototype = {
	-- Load = function(self) local panel = self.panel end
	-- Search = function(query, characterKey) return numRows end
	-- Update = function() return numRows end

	-- DO NOT CARELESSLY OVERWRITE THESE FUNCTIONS
	OnInitialize = function(self) end,
	OnEnable = function(self)
		self.panel = CreateFrame('Frame', '$parentPanel' .. self:GetName(), addon.frame.content)
		self.panel:SetSize(addon.frame.content:GetSize())
		self.panel:SetAllPoints()
		self.panel:Hide()
		self:Load()
		self:Update()
	end,
}
views:SetDefaultModuleState(false) -- don't enable modules on load
views:SetDefaultModulePrototype(prototype)

function views:OnEnable()
	self:RegisterMessage('TWINKLE_SEARCH_RESULTS')
	addon:AutoUpdateModule(self.moduleName)
end

local lastTabIndex = 0
local function OnTabClick(self)
	PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
	self:SetChecked(not self:GetChecked())
	views:Show(self.module)
end
function views.AddTab(view)
	local index = lastTabIndex + 1
	local tab = CreateFrame('CheckButton', '$parentTab'..index, addon.frame, 'SpellBookSkillLineTabTemplate', index)

	local count = tab:CreateFontString(nil, 'ARTWORK', 'NumberFontNormalSmall')
	      count:SetAllPoints()
	      count:SetJustifyH('RIGHT')
	      count:SetJustifyV('BOTTOM')
	tab.count = count

	if index == 1 then
		tab:SetPoint('TOPLEFT', '$parent', 'TOPRIGHT', 0, -36)
	else
		tab:SetPoint('TOPLEFT', '$parentTab'..(index-1), 'BOTTOMLEFT', 0, -16)
	end

	tab:RegisterForClicks('AnyUp')
	tab:SetScript('OnEnter', addon.ShowTooltip)
	tab:SetScript('OnLeave', addon.HideTooltip)
	tab:SetScript('OnClick', OnTabClick)
	tab:Show()

	tab.element = view
	lastTabIndex = lastTabIndex + 1

	return tab
end

local currentView
function views:Hide()
	if currentView then
		currentView.panel:Hide()
		currentView = nil
		-- addon:SendMessage('TWINKLE_VIEW_HIDE', currentView:GetName())
	end
end

function views:Show(view)
	if not addon.frame then return end

	view = type(view) == 'table' and view or self:GetModule(view, true)
	if not view or view == currentView then return end
	if not view:IsEnabled() then view:Enable() end

	local previousView = currentView
	self:Hide()
	view.panel:Show()
	currentView = view

	self:Update()

	addon:SendMessage('TWINKLE_VIEW_CHANGED', view:GetName(), previousView and previousView:GetName() or nil)
end

function views.Sort(a, b)
	if a:GetName() == 'Default' then
		return true
	elseif b:GetName() == 'Default' then
		return false
	end
	return (a.title or a:GetName()) < (b.title or b:GetName())
end
function views:Initialize()
	local modules = {}
	for viewName, view in self:IterateModules() do
		table.insert(modules, view)
	end
	table.sort(modules, views.Sort)

	for _, view in pairs(modules) do
		view.tab = self.AddTab(view)
		view.tab.tiptext = view.title or view:GetName()
		view.tab.module = view:GetName()
		if view.icon then
			view.tab:GetNormalTexture():SetTexture(view.icon)
		end
	end

	local view = self:GetModule('Default')
	view:Enable()
end

function views:Update()
	if not addon.frame then return end
	if not currentView then
		views:Initialize()
	end

	-- update tabs
	for index = 1, lastTabIndex do
		local tab = _G[addon.frame:GetName() .. 'Tab' .. index]
		tab:SetChecked(tab.element == currentView)
		tab.count:SetText(nil)
		local icon = tab:GetNormalTexture()
		icon:SetDesaturated(false)
		icon:SetAlpha(1)
	end

	-- update panel
	if currentView and currentView.Update then
		currentView:Update()
	end
end

local characters = {}
function views:Search(query, searchResults)
	local currentCharacter = addon:GetSelectedCharacter()
	characters = addon.data.GetCharacters(characters)

	for viewName, view in views:IterateModules() do
		if view.Search then
			-- also searching unloaded views TODO: this causes :Update (duplicates)
			if not view:IsEnabled() then view:Enable() end
			-- gather search results
			for _, characterKey in pairs(characters) do
				local numMatches = 0
				if view == currentView and characterKey == currentCharacter then
					-- directly update displayed view
					self:Update()
				end

				numMatches = view:Search(query, characterKey) or 0
				if numMatches > 0 then
					-- store data as view.name, e.g. Twinkle_views_items
					searchResults[characterKey] = searchResults[characterKey] or {}
					searchResults[characterKey][view.name] = numMatches
				end
			end
		end
	end
end

function views:TWINKLE_SEARCH_RESULTS(event, searchResults)
	local characterKey = addon:GetSelectedCharacter()
	for _, view in self:IterateModules() do
		if view.tab then
			local numResults = searchResults[characterKey] and searchResults[characterKey][view.name] or 0
			-- display number of matches
			view.tab.count:SetText(numResults > 0 and numResults or nil)
			-- desaturate tabs without search results
			local icon = view.tab:GetNormalTexture()
			icon:SetDesaturated(numResults == 0)
			icon:SetAlpha(numResults == 0 and 0.5 or 1)
		end
	end
end
