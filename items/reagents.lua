local addonName, addon, _ = ...

-- GLOBALS: _G
-- "interesting" constants: REAGENTBANK_CONTAINER:<slots>

local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
local reagents       = items:NewModule('ReagentBank', 'AceEvent-3.0')
      reagents.icon  = 'INTERFACE\\ICONS\\INV_Fabric_Linen_01' -- INV_Enchant_EssenceArcaneLarge, INV_Fabric_Linen_01/Silk_03/Wool_03, INV_Misc_Fish_08, INV_Misc_Food_04/08/19/Vendor_PinkTurnip
      reagents.title = _G.REAGENT_BANK

function reagents:OnEnable()
	self:RegisterEvent('PLAYERREAGENTBANKSLOTS_CHANGED', 'Update')
end
function reagents:OnDisable()
	self:UnregisterEvent('PLAYERREAGENTBANKSLOTS_CHANGED')
end

function reagents:GetNumRows(characterKey)
	return (addon.data.GetContainerInfo(characterKey, _G.REAGENTBANK_CONTAINER))
end

function reagents:GetRowInfo(characterKey, index)
	local slot = index
	local location = LibItemLocations:PackInventoryLocation(0, slot, nil, nil, nil, nil, true) -- reagentBank
	local itemID, itemLink, count = addon.data.GetContainerSlotInfo(characterKey, _G.REAGENTBANK_CONTAINER, slot)
	if not itemID then return end

	return location, itemLink, count
end
