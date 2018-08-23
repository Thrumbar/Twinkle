local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string, bit, math, type
-- "interesting" constants: NUM_BAG_SLOTS:<slots>, BANK_CONTAINER:BANK_CONTAINER_INVENTORY_OFFSET + 1 / BANK_CONTAINER_INVENTORY_OFFSET + NUM_BANKGENERIC_SLOTS, NUM_BANKBAGSLOTS:<slots>

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

	local itemLink = addon.data.GetInventoryItemLink(characterKey, index)
	if not itemLink then return end

	local location = LibItemLocations:PackInventoryLocation(nil, index, true)
	local count    = 1

	return location, itemLink, count
end
