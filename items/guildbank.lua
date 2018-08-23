local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string

local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
local guildbank       = items:NewModule('GuildBank', 'AceEvent-3.0')
      guildbank.icon  = 'INTERFACE\\ICONS\\achievement_guildperk_mobilebanking'
      guildbank.title = _G.GUILD_BANK or 'Guild Bank'
      guildbank.unchecked = true -- don't show these items by default

function guildbank:OnEnable()
	-- self:RegisterEvent('', 'Update')
end
function guildbank:OnDisable()
	-- self:UnregisterEvent('')
end

function guildbank:GetNumRows(characterKey)
	local numRows = 0
	for tab = 1, _G.MAX_GUILDBANK_TABS do
		numRows = numRows + addon.data.GetContainerInfo(characterKey, 'GuildBank'..tab)
	end
	return numRows
end

function guildbank:GetRowInfo(characterKey, index)
	local slot, container = index, 1
	local numSlots = addon.data.GetContainerInfo(characterKey, 'GuildBank'..container)
	while container <= _G.MAX_GUILDBANK_TABS and slot > numSlots do
		-- indexed slot is not in this tab
		container = container + 1
		numSlots  = addon.data.GetContainerInfo(characterKey, 'GuildBank'..container)
		slot      = slot - numSlots
	end

	local location = LibItemLocations:PackInventoryLocation(container, slot, nil, nil, nil, nil, nil, nil, true)
	local itemID, itemLink, count = addon.data.GetContainerSlotInfo(characterKey, 'GuildBank'..container, slot)
	if not itemID then return end

	return location, itemLink, count
end
