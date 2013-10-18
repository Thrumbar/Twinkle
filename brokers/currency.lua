local addonName, ns, _ = ...
local LDB = LibStub:GetLibrary('LibDataBroker-1.1')

local plugin = LDB:NewDataObject('TwinkleCurrency', {
	type	= 'data source',
	label	= CURRENCY,
	-- text 	= CURRENCY,

	-- OnClick = OnLDBClick,
	-- OnEnter = OnLDBEnter,
	-- OnLeave = function() end,	-- needed for e.g. NinjaPanel
})

ns.RegisterEvent('ADDON_LOADED', function(frame, event, arg1)
	if arg1 == addonName then
		ns.UnregisterEvent('ADDON_LOADED', 'currencies')
	end
end, 'currencies')

-- ns.RegisterEvent('CURRENCY_DISPLAY_UPDATE', LDBUpdate, 'currencies_update')
