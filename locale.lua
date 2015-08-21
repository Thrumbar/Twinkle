local addonName, addon, _ = ...
local L = LibStub('AceLocale-3.0'):NewLocale(addonName, 'enUS', true, true)

L['Count'] = true
L['Lists'] = true
L['Click to toggle Twinkle'] = true

L['characterFilterFaction'] = _G.FACTION
L['characterFilterLevel']   = _G.LEVEL

-- deDE localization
local L = LibStub('AceLocale-3.0'):NewLocale(addonName, 'deDE')
if L then
	L['Count'] = 'Anzahl'
	L['Lists'] = 'Listen'
end
