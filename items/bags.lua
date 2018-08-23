local addonName, addon, _ = ...

-- GLOBALS: _G
-- "interesting" constants: NUM_BAG_SLOTS:<slots>

local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
local bags       = items:NewModule('Bags', 'AceEvent-3.0')
      bags.icon  = 'Interface\\ICONS\\INV_Misc_Bag_07'
      bags.title = _G.INVTYPE_BAG or 'Bags'

function bags:OnEnable()
	self:RegisterEvent('BAG_UPDATE_DELAYED', 'Update')
end
function bags:OnDisable()
	self:UnregisterEvent('BAG_UPDATE_DELAYED')
end

function bags:GetNumRows(characterKey)
	local numRows = 0
	for container = 0, _G.NUM_BAG_SLOTS do
		local numSlots = addon.data.GetContainerInfo(characterKey, container)
		numRows = numRows + (numSlots or 0)
	end
	return numRows
end

function bags:GetRowInfo(characterKey, index)
	local slot, container = index, 0
	local numSlots = addon.data.GetContainerInfo(characterKey, container)
	while container <= _G.NUM_BAG_SLOTS and slot > numSlots do
		-- indexed slot is not in this bag
		container = container + 1
		numSlots  = addon.data.GetContainerInfo(characterKey, container)
		slot      = slot - numSlots
	end

	local location = LibItemLocations:PackInventoryLocation(container, slot, nil, nil, true)
	local itemID, itemLink, count = addon.data.GetContainerSlotInfo(characterKey, container, slot)
	if not itemID then return end

	return location, itemLink, count
end
