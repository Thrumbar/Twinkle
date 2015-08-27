local addonName, addon, _ = ...

-- GLOBALS: LibStub
local QTip = LibStub('LibQTip-1.0')
local LDB  = LibStub('LibDataBroker-1.1')

local brokers = addon:NewModule('brokers')
local prototype = {
	-- modules should implement these
	OnClick = function() end,
	UpdateLDB = function() end,
	UpdateTooltip = function() end,

	-- and stay away from these
	Update = function(self)
		local brokerName = self:GetName()
		local identifier = addonName..'_'..brokerName

		local ldb = LDB:GetDataObjectByName(identifier)
		self.UpdateLDB(ldb)

		if QTip:IsAcquired(identifier) then
			-- also update tooltip
			local tooltip = QTip:Acquire(identifier)
			      tooltip:Clear()
			local hide = self.UpdateTooltip(tooltip)
			if hide then
				QTip:Release(tooltip)
				tooltip:Hide()
			end
		end
	end,
	OnInitialize = function(self)
		local brokerName = self:GetName()
		local identifier = addonName..'_'..brokerName

		-- setup LDB
		local ldb = LDB:NewDataObject(identifier, {
			type	= 'data source',
			text    = brokerName,
			label   = brokerName,

			OnClick = self.OnClick,
			OnEnter = function(frame, ...)
				if QTip:IsAcquired(identifier) then return end
				local tooltip = QTip:Acquire(identifier)
				tooltip:SmartAnchorTo(frame)
				tooltip:SetAutoHideDelay(0.25, frame)

				local hide = self.UpdateTooltip(tooltip, frame, ...)
				if not hide then
					tooltip:Show()
				end
			end,
			-- needed for e.g. NinjaPanel, though QTip handles that functionality for us
			OnLeave = function() end,
		})
	end,
}
brokers:SetDefaultModulePrototype(prototype)
brokers:SetDefaultModuleLibraries('AceEvent-3.0')
