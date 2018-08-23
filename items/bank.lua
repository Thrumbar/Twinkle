local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string

local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
local bank       = items:NewModule('Bank', 'AceEvent-3.0')
      bank.icon  = 'Interface\\MINIMAP\\TRACKING\\Banker'
      bank.title = _G.BANK or 'Bank'

function bank:OnEnable()
	self:RegisterEvent('PLAYERBANKSLOTS_CHANGED', 'Update')
	self:RegisterEvent('PLAYERBANKBAGSLOTS_CHANGED', 'Update')
end
function bank:OnDisable()
	self:UnregisterEvent('PLAYERBANKSLOTS_CHANGED')
	self:UnregisterEvent('PLAYERBANKBAGSLOTS_CHANGED')
end

function bank:GetNumRows(characterKey)
	local numRows = _G.NUM_BANKGENERIC_SLOTS
	local offset  = _G.BANK_CONTAINER_INVENTORY_OFFSET + _G.NUM_BANKGENERIC_SLOTS
	for container = 1, _G.NUM_BANKBAGSLOTS do
		local numSlots = addon.data.GetContainerInfo(characterKey, offset + container)
		numRows = numRows + (numSlots or 0)
	end
	return numRows
end

function bank:GetRowInfo(characterKey, index)
	-- figure out the correct container
	local slot, container = index, _G.BANK_CONTAINER
	local numSlots = addon.data.GetContainerInfo(characterKey, container)
	local offset   = _G.BANK_CONTAINER_INVENTORY_OFFSET + _G.NUM_BANKGENERIC_SLOTS
	while container <= _G.NUM_BANKBAGSLOTS and slot > numSlots do
		-- indexed slot is not in this bag
		slot      = slot - numSlots
		container = (container == _G.BANK_CONTAINER and 0 or container) + 1
		numSlots  = addon.data.GetContainerInfo(characterKey, offset + container)
	end
	if container > 0 then
		-- map bank bag to inventory slot id
		container = container + _G.BANK_CONTAINER_INVENTORY_OFFSET + _G.NUM_BANKGENERIC_SLOTS
	end

	local location = LibItemLocations:PackInventoryLocation(container, slot, nil, true, true) -- bank|bags
	local itemID, itemLink, count = addon.data.GetContainerSlotInfo(characterKey, container, slot)
	if not itemID then return end

	return location, itemLink, count
end


-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
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
