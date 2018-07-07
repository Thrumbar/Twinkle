local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local views = addon:GetModule('views')
local grids = views:GetModule('grids')
local storage = grids:NewModule('storage', 'AceEvent-3.0')
      storage.icon = 'Interface\\Icons\\inv_misc_paperpackage01a'
      storage.title = 'Storage'

function storage:OnEnable()
	self:RegisterEvent('BAG_UPDATE_DELAYED', 'Update')
end
function storage:OnDisable()
	self:UnregisterEvent('BAG_UPDATE_DELAYED')
end

function storage:GetNumColumns()
	return 3
end

function storage:GetColumnInfo(index)
	local text, link, tooltipText, justify

	return (index == 1 and 'Bag Slots')
			or (index == 2 and 'Used')
			or (index == 3 and 'Free'), link, tooltipText, justify
end

function storage:GetCellInfo(characterKey, index)
	local total, free = 0, 0
	for container = 0, _G.NUM_BAG_SLOTS do
		local bagTotal, bagFree = addon.data.GetContainerInfo(characterKey, container)
		total = total + bagTotal
		free = free + bagFree
	end
	if index == 1 then
		return total
	elseif index == 2 then
		return total - free
	else
		return free
	end
	-- return text, link, tooltipText, justify
end
