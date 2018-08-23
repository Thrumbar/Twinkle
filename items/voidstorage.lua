local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string, math

local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
local voidstorage       = items:NewModule('VoidStorage', 'AceEvent-3.0')
      voidstorage.icon  = 'INTERFACE\\ICONS\\Spell_Nature_AstralRecalGroup'
      voidstorage.title = _G.VOID_STORAGE

function voidstorage:OnEnable()
	-- other events: VOID_STORAGE_UPDATE, VOID_TRANSFER_DONE
	self:RegisterEvent('VOID_STORAGE_CONTENTS_UPDATE', 'Update')
end
function voidstorage:OnDisable()
	self:UnregisterEvent('VOID_STORAGE_CONTENTS_UPDATE')
end

function voidstorage:GetNumRows(characterKey)
	local numRows = addon.data.GetContainerInfo(characterKey, 'VoidStorage1')
		+ addon.data.GetContainerInfo(characterKey, 'VoidStorage2')
	return numRows
end

function voidstorage:GetRowInfo(characterKey, index)
	local slotsPerTab = 80
	local slot, container = index%slotsPerTab, math.ceil(index/slotsPerTab)
	local location = LibItemLocations:PackInventoryLocation(container, slot, nil, nil, nil, true) -- player|voidStorage

	-- void storage removes enchants, gems etc
	local itemID, itemLink, count = addon.data.GetContainerSlotInfo(characterKey, 'VoidStorage'..container, slot)
	if not itemID then return end

	return location, itemLink, count
end
