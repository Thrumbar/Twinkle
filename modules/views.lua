local addonName, addon, _ = ...
local emptyTable = {}

-- each view will be a sub-module of the views module!
local views = addon:NewModule('views', 'AceEvent-3.0')
local prototype = {
	OnInitialize = function(self)
		-- supply views with panel and tab
		local viewName = self:GetName()
		local prettyName = viewName:gsub('^.',  string.upper)

		local panel = CreateFrame('Frame', '$parentPanel'..prettyName, addon.frame)
		      panel:SetSize(addon.frame.content:GetSize())
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
views:SetDefaultModuleState(false) -- don't enable modules on load
views:SetDefaultModulePrototype(prototype)

function views:OnEnable()
	self:RegisterMessage('TWINKLE_SEARCH_RESULTS')
	addon:AutoUpdateModule(self.moduleName)
end

local lastTabIndex = 0
local function OnTabClick(self)
	self:SetChecked(not self:GetChecked())
	views:Show( self.module )
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
		tab:SetPoint('TOPLEFT', '$parentTab'..(index-1), 'BOTTOMLEFT', 0, -22)
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
function views:Show(view)
	view = view and type(view) == 'string' and self:GetModule(view, true) or view
	if (not view or type(view) == 'string') or (currentView and view == currentView) then return end

	local previousView = currentView
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

	if not view:IsEnabled() then view:Enable() end
	self:Update()

	addon:SendMessage('TWINKLE_VIEW_CHANGED', view:GetName(), previousView and previousView:GetName() or nil)
end

function views:GetActiveView()
	return currentView
end

function views:Update()
	if not currentView then
		views:EnableModule('default')
		views:Show('default')
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
	currentView:Update()
end

function views:TWINKLE_SEARCH_RESULTS(event, searchResults, characterKey)
	-- only considering current character
	characterKey = characterKey or addon:GetSelectedCharacter()
	for name, view in self:IterateModules() do
		if view.tab then
			local numResults = searchResults[characterKey] and searchResults[characterKey][name] or 0
			-- display number of matches
			view.tab.count:SetText(numResults > 0 and numResults or nil)
			-- desaturate tabs without search results
			local icon = view.tab:GetNormalTexture()
			icon:SetDesaturated(numResults == 0)
			icon:SetAlpha(numResults == 0 and 0.5 or 1)
		end
	end
end
