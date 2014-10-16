local addonName, addon, _ = ...

-- each view will be a sub-module of the views module!
local views = addon:NewModule('views')
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

function views:OnInitialize()
	-- hooksecurefunc(addon, 'Update', self.Update)
end

local lastTabIndex = 0
local function OnTabClick(self)
	self:SetChecked(not self:GetChecked())
	views:Show( self.module )
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
function views:Show(view)
	view = view and type(view) == 'string' and self:GetModule(view, true) or view
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

	if not view:IsEnabled() then view:Enable() end
	self:Update()

	addon:SendMessage('TWINKLE_VIEW_CHANGED', view:GetName())
end

function views:GetActiveView()
	return currentView
end

function views.Update()
	if not currentView then
		views:EnableModule('default')
		views:Show('default')
	end

	-- update tabs
	for index = 1, lastTabIndex do
		local tab = _G[addon.frame:GetName() .. 'Tab' .. index]
		tab:SetChecked( tab.element == currentView )
	end
	-- update panel
	currentView:Update()
end
