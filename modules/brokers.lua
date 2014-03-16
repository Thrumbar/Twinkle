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
			self.UpdateTooltip(tooltip)
		end
	end,
	OnInitialize = function(self)
		local brokerName = self:GetName()
		local identifier = addonName..'_'..brokerName

		-- setup LDB
		local ldb = LDB:NewDataObject(identifier, {
			type	= 'data source',

			OnClick = self.OnClick,
			OnEnter = function(frame, ...)
				if QTip:IsAcquired(identifier) then return end
				local tooltip = QTip:Acquire(identifier)
				tooltip:SmartAnchorTo(frame)
				tooltip:SetAutoHideDelay(0.25, frame)

				self.UpdateTooltip(tooltip, frame, ...)
				tooltip:Show()
			end,
			-- needed for e.g. NinjaPanel, though QTip handles that functionality for us
			OnLeave = function() end,
		})
	end,
}
brokers:SetDefaultModulePrototype(prototype)
brokers:SetDefaultModuleLibraries('AceEvent-3.0')

local characters, thisCharacter
function brokers:OnInitialize()
	characters = addon.data.GetCharacters(characters)
	thisCharacter = addon.data.GetCurrentCharacter()
end

function brokers:GetCharacters()
	return characters
end

function brokers:GetCharacter()
	return thisCharacter
end
