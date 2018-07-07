local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local views = addon:GetModule('views')
local grids = views:GetModule('grids')
local storage = grids:NewModule('storage', 'AceEvent-3.0')
      storage.icon = 'Interface\\Icons\\inv_misc_paperpackage01a'
      storage.title = 'Storage'

function storage:OnEnable()
	-- self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', 'Update')
end
function storage:OnDisable()
	-- self:UnregisterEvent('CURRENCY_DISPLAY_UPDATE')
end

function storage:GetNumColumns()
	return 0
end

function storage:GetColumnInfo(index)
	local text, link, tooltipText, justify
	-- @todo Implement logic.
	return text, link, tooltipText, justify
end

function storage:GetCellInfo(characterKey, index)
	local text, link, tooltipText, justify = '-', nil, nil, 'CENTER'
	return text, link, tooltipText, justify
end
