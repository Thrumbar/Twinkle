local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string, bit, math, type
-- "interesting" constants: NUM_BAG_SLOTS:<slots>, BANK_CONTAINER:BANK_CONTAINER_INVENTORY_OFFSET + 1 / BANK_CONTAINER_INVENTORY_OFFSET + NUM_BANKGENERIC_SLOTS, NUM_BANKBAGSLOTS:<slots>, REAGENTBANK_CONTAINER:<slots>

local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')
local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
local inventory       = items:NewModule('Inventory', 'AceEvent-3.0')
      inventory.icon  = 'Interface\\GUILDFRAME\\GuildLogo-NoLogo'
      inventory.title = 'Equipped Items'

function inventory:OnEnable()
	-- self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED', lists.Update, self)
end
function inventory:OnDisable()
	-- self:UnregisterEvent('PLAYER_EQUIPMENT_CHANGED')
end

function inventory:GetNumRows(characterKey)
	return _G.INVSLOT_LAST_EQUIPPED - _G.INVSLOT_FIRST_EQUIPPED + 1
end

function inventory:GetRowInfo(characterKey, slotID)
	local item = addon.data.GetInventoryItemLink(characterKey, slotID, true)
	if not item then return end

	local itemLink
	if type(item) == 'string' then
		itemLink = item
	else
		_, itemLink = GetItemInfo(item)
	end

	local location = LibItemLocations:PackInventoryLocation(nil, slotID, true)
	local level    = itemLink and LibItemUpgrade:GetUpgradedItemLevel(itemLink)
	local count    = 1

	return location, itemLink, count, level
end

-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local bags       = items:NewModule('Bags', 'AceEvent-3.0')
      bags.icon  = 'Interface\\ICONS\\INV_Misc_Bag_07' -- _Red'
      bags.title = _G.INVTYPE_BAG or 'Bags'

function bags:OnEnable()
	-- TODO: check if this plugin is currently displayed
	-- self:RegisterEvent('BAG_UPDATE_DELAYED', items.Update, items)
end
function bags:OnDisable()
	-- self:UnregisterEvent('BAG_UPDATE_DELAYED')
end

function bags:GetNumRows(characterKey)
	local numRows = 0
	for container = 0, _G.NUM_BAG_SLOTS do
		local numSlots = addon.data.GetContainerNumSlots(characterKey, container)
		numRows = numRows + (numSlots or 0)
	end
	return numRows
end

function bags:GetRowInfo(characterKey, index)
	local slot, container = index, 0
	local numSlots = addon.data.GetContainerNumSlots(characterKey, container)
	while container <= _G.NUM_BAG_SLOTS and slot > numSlots do
		-- indexed slot is not in this bag
		container = container + 1
		numSlots  = addon.data.GetContainerNumSlots(characterKey, container)
		slot      = slot - numSlots
	end

	local location = LibItemLocations:PackInventoryLocation(container, slot, nil, nil, true)
	local itemID, itemLink, count = addon.data.GetContainerSlotInfo(characterKey, container, slot)
	if itemID and not itemLink then
		_, itemLink = GetItemInfo(itemID)
	end
	local level = itemLink and LibItemUpgrade:GetUpgradedItemLevel(itemLink)

	return location, itemLink, count, level
end

-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local bank       = items:NewModule('Bank', 'AceEvent-3.0')
      bank.icon  = 'Interface\\MINIMAP\\TRACKING\\Banker'
      bank.title = _G.BANK or 'Bank'

function bank:OnEnable()
	-- self:RegisterEvent('PLAYERBANKSLOTS_CHANGED', lists.Update, self)
	-- self:RegisterEvent('PLAYERBANKBAGSLOTS_CHANGED', lists.Update, self)
end
function bank:OnDisable()
	-- self:UnregisterEvent('PLAYERBANKSLOTS_CHANGED')
	-- self:UnregisterEvent('PLAYERBANKBAGSLOTS_CHANGED')
end

function bank:GetNumRows(characterKey)
	local numRows = _G.NUM_BANKGENERIC_SLOTS
	local offset  = _G.BANK_CONTAINER_INVENTORY_OFFSET + _G.NUM_BANKGENERIC_SLOTS
	for container = 1, _G.NUM_BANKBAGSLOTS do
		local numSlots = addon.data.GetContainerNumSlots(characterKey, offset + container)
		numRows = numRows + (numSlots or 0)
	end
	return numRows
end

function bank:GetRowInfo(characterKey, index)
	local slot, container = index, _G.BANK_CONTAINER
	local offset  = _G.BANK_CONTAINER_INVENTORY_OFFSET + _G.NUM_BANKGENERIC_SLOTS
	local numSlots = addon.data.GetContainerNumSlots(characterKey, container)
	while container <= _G.NUM_BANKBAGSLOTS and slot > numSlots do
		-- indexed slot is not in this bag
		container = (container == _G.BANK_CONTAINER and 0 or container) + 1
		numSlots  = addon.data.GetContainerNumSlots(characterKey, offset + container)
		slot      = slot - numSlots
	end

	local location = LibItemLocations:PackInventoryLocation(container, slot, nil, true, true) -- bank|bags
	local itemID, itemLink, count = addon.data.GetContainerSlotInfo(characterKey, container, slot)
	if itemID and not itemLink then
		_, itemLink = GetItemInfo(itemID)
	end
	local level = itemLink and LibItemUpgrade:GetUpgradedItemLevel(itemLink)

	return location, itemLink, count, level
end


-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local reagents       = items:NewModule('ReagentBank', 'AceEvent-3.0')
      reagents.icon  = 'INTERFACE\\ICONS\\INV_Fabric_Linen_01' -- INV_Enchant_EssenceArcaneLarge, INV_Fabric_Linen_01/Silk_03/Wool_03, INV_Misc_Fish_08, INV_Misc_Food_04/08/19/Vendor_PinkTurnip
      reagents.title = 'Reagent Bank'

function reagents:OnEnable()
	-- self:RegisterEvent('PLAYERREAGENTBANKSLOTS_CHANGED', lists.Update, self)
end
function reagents:OnDisable()
	-- self:UnregisterEvent('PLAYERREAGENTBANKSLOTS_CHANGED')
end

function reagents:GetNumRows(characterKey)
	return 0
end

function reagents:GetRowInfo(characterKey, index)
	-- local location = LibItemLocations:PackInventoryLocation(container, slot, nil, nil, nil, nil, true) -- reagentBank
	return
end

-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local voidstorage       = items:NewModule('VoidStorage', 'AceEvent-3.0')
      voidstorage.icon  = 'INTERFACE\\ICONS\\Spell_Nature_AstralRecalGroup'
      voidstorage.title = 'Void Storage'

function voidstorage:OnEnable()
	-- events: VOID_STORAGE_UPDATE, VOID_STORAGE_CONTENTS_UPDATE, VOID_TRANSFER_DONE
	-- self:RegisterEvent('VOID_STORAGE_CONTENTS_UPDATE', lists.Update, self)
end
function voidstorage:OnDisable()
	-- self:UnregisterEvent('VOID_STORAGE_CONTENTS_UPDATE')
end

function voidstorage:GetNumRows(characterKey)
	-- FIXME: this is specific to DataStore_Containers! It treats VS as one big place => 160 slots
	return addon.data.GetContainerNumSlots(characterKey, 'VoidStorage')
end

function voidstorage:GetRowInfo(characterKey, index)
	-- FIXME: this is specific to DataStore_Containers!
	local slotsPerTab = 80
	local slot, container = index%slotsPerTab, math.ceil(index/slotsPerTab)
	local location = LibItemLocations:PackInventoryLocation(container, slot, nil, nil, nil, true) -- player|voidStorage

	-- void storage removes enchants, gems etc
	local itemID, _, count = addon.data.GetContainerSlotInfo(characterKey, 'VoidStorage', index)
	local _, itemLink, _, level = GetItemInfo(itemID)

	return location, itemLink, count, level
end


-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local mails       = items:NewModule('Mails', 'AceEvent-3.0')
      mails.icon  = 'Interface\\MINIMAP\\TRACKING\\Mailbox'
      mails.title = _G.INBOX or 'Mails'

function mails:OnEnable()
	-- self:RegisterEvent('MAIL_INBOX_UPDATE', lists.Update, self)
end
function mails:OnDisable()
	-- self:UnregisterEvent('MAIL_INBOX_UPDATE')
end

function mails:GetNumRows(characterKey)
	-- FIXME: depends on DataStore_Mails
	return DataStore:GetNumMails(characterKey) or 0
end

function mails:GetRowInfo(characterKey, index)
	-- FIXME: depends on DataStore_Mails
	local mailIndex, attachmentIndex = 0, index
	local location = LibItemLocations:PackInventoryLocation(mailIndex, attachmentIndex, nil, nil, nil, nil, nil, true)
	local _, count, itemLink = DataStore:GetMailInfo(characterKey, index)
	local level    = itemLink and LibItemUpgrade:GetUpgradedItemLevel(itemLink)

	return location, itemLink, count, level
end


-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local guildbank       = items:NewModule('GuildBank', 'AceEvent-3.0')
      guildbank.icon  = 'INTERFACE\\ICONS\\achievement_guildperk_mobilebanking'
      guildbank.title = _G.GUILD_BANK or 'Guild Bank'

function guildbank:OnEnable()
	-- self:RegisterEvent('', lists.Update, self)
end
function guildbank:OnDisable()
	-- self:UnregisterEvent('')
end

function guildbank:GetNumRows(characterKey)
	return 0
end

function guildbank:GetRowInfo(characterKey, index)
	-- local location = LibItemLocations:PackInventoryLocation(container, slot, nil, nil, nil, nil, nil, nil, true)
	-- return location, itemLink, count, level
end


-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local auction       = items:NewModule('AuctionHouse', 'AceEvent-3.0')
      auction.icon  = 'INTERFACE\\ICONS\\INV_Misc_Coin_02'
      auction.title = _G.BUTTON_LAG_AUCTIONHOUSE or 'Auction House'

function auction:OnEnable()
	-- self:RegisterEvent('', lists.Update, self)
end
function auction:OnDisable()
	-- self:UnregisterEvent('')
end

function auction:GetNumRows(characterKey)
	return 0
end

function auction:GetRowInfo(characterKey, index)
	-- local location = LibItemLocations:PackInventoryLocation(container, slot, nil, nil, nil, nil, nil, nil, nil, true)
	-- return location, itemLink, count, level
end
