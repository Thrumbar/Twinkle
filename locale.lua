local addonName, addon, _ = ...
local L = LibStub('AceLocale-3.0'):NewLocale(addonName, 'enUS', true, true)

L['Count'] = true
L['Lists'] = true

-- deDE localization
local L = LibStub('AceLocale-3.0'):NewLocale(addonName, 'deDE')
if L then
	L['Count'] = 'Anzahl'
	L['Lists'] = 'Listen'
end
