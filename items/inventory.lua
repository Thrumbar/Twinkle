local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string, bit, math, type
-- "interesting" constants: NUM_BAG_SLOTS:<slots>, BANK_CONTAINER:BANK_CONTAINER_INVENTORY_OFFSET + 1 / BANK_CONTAINER_INVENTORY_OFFSET + NUM_BANKGENERIC_SLOTS, NUM_BANKBAGSLOTS:<slots>, REAGENTBANK_CONTAINER:<slots>

local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
local inventory       = items:NewModule('Inventory', 'AceEvent-3.0')
      inventory.icon  = 'Interface\\GUILDFRAME\\GuildLogo-NoLogo'
      inventory.title = _G.BAG_FILTER_EQUIPMENT

function inventory:OnEnable()
	self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED', 'Update')
end
function inventory:OnDisable()
	self:UnregisterEvent('PLAYER_EQUIPMENT_CHANGED')
end

function inventory:GetNumRows(characterKey)
	local equipment = _G.INVSLOT_LAST_EQUIPPED - _G.INVSLOT_FIRST_EQUIPPED + 1
	local bagBags   = _G.NUM_BAG_SLOTS
	local bankBags  = _G.NUM_BANKBAGSLOTS
	return equipment + bagBags + bankBags
end

function inventory:GetRowInfo(characterKey, index)
	if index > _G.CONTAINER_BAG_OFFSET + _G.NUM_BAG_SLOTS then
		-- bank bags follow way later
		index = index - _G.CONTAINER_BAG_OFFSET - _G.NUM_BAG_SLOTS
		index = index + _G.BANK_CONTAINER_INVENTORY_OFFSET + _G.NUM_BANKGENERIC_SLOTS
	end

	local itemLink = addon.data.GetInventoryItemLink(characterKey, index, true)
	if not itemLink then return end

	if type(itemLink) ~= 'string' then
		_, itemLink = GetItemInfo(itemLink)
	end

	local location = LibItemLocations:PackInventoryLocation(nil, index, true)
	local count    = 1

	return location, itemLink, count
end

-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
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
	if itemID and not itemLink then
		_, itemLink = GetItemInfo(itemID)
	end

	return location, itemLink, count
end
