local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')

local views = addon:GetModule('views')
local items = views:GetModule('items')
local inventory       = items:NewModule('Inventory', 'AceEvent-3.0')
      inventory.icon  = 'Interface\\GUILDFRAME\\GuildLogo-NoLogo'
      inventory.title = 'Equipped Items'

function inventory:OnEnable()
	-- self:RegisterEvent('UNIT_FACTION', lists.Update, self)
end
function inventory:OnDisable()
	-- self:UnregisterEvent('UNIT_FACTION')
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

	local key   = string.format('inventory:%.4d', slotID) -- tonumber(string.format('-2.%.4d', slotID))
	local level = LibItemUpgrade:GetUpgradedItemLevel(itemLink)
	local count = 1

	return key, itemLink, count, level
end

-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local bags       = items:NewModule('Bags', 'AceEvent-3.0')
      bags.icon  = 'Interface\\MINIMAP\\TRACKING\\Banker'
      bags.title = 'Bags'

function bags:OnEnable()
	-- TODO: check if this plugin is currently displayed
	-- self:RegisterEvent('BAG_UPDATE_DELAYED', items.Update, items)
end
function bags:OnDisable()
	-- self:UnregisterEvent('BAG_UPDATE_DELAYED')
end

function bags:GetNumRows(characterKey)
	return 0
end

function bags:GetRowInfo(characterKey, index)
	local identifier, itemID, hyperlink, count
	return identifier, itemID, hyperlink, count
end

-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: GetItemInfo
-- GLOBALS: string

-- local views = addon:GetModule('views')
-- local items = views:GetModule('items')
local bank       = items:NewModule('Bank', 'AceEvent-3.0')
      bank.icon  = 'INTERFACE\\ICONS\\achievement_guildperk_mobilebanking'
      bank.title = 'Bank'

function bank:OnEnable()
	-- self:RegisterEvent('UNIT_FACTION', lists.Update, self)
end
function bank:OnDisable()
	-- self:UnregisterEvent('UNIT_FACTION')
end

function bank:GetNumRows(characterKey)
	return 0
end

function bank:GetRowInfo(characterKey, index)
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
	-- self:RegisterEvent('UNIT_FACTION', lists.Update, self)
end
function voidstorage:OnDisable()
	-- self:UnregisterEvent('UNIT_FACTION')
end

function voidstorage:GetNumRows(characterKey)
	return 0
end

function voidstorage:GetRowInfo(characterKey, index)
	return
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
      mails.title = 'Mails'

function mails:OnEnable()
	-- self:RegisterEvent('UNIT_FACTION', lists.Update, self)
end
function mails:OnDisable()
	-- self:UnregisterEvent('UNIT_FACTION')
end

function mails:GetNumRows(characterKey)
	return 0
end

function mails:GetRowInfo(characterKey, index)
	return
end
