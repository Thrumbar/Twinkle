local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string

local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
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
	local numAuctions, numBids = addon.data.GetAuctionState(characterKey)
	return numAuctions + numBids
end

function auction:GetRowInfo(characterKey, index)
	local numAuctions, numBids = addon.data.GetAuctionState(characterKey)
	local list = index > numAuctions and 'bidder' or 'owner'
	if index > numAuctions then index = index - numAuctions end

	local isGoblin, itemID, count, name, price1, price2, timeLeft = addon.data.GetAuctionInfo(characterKey, list, index)
	if not itemID then return end
	local _, itemLink = GetItemInfo(itemID)
	local location = LibItemLocations:PackInventoryLocation(0, index, nil, nil, nil, nil, nil, nil, nil, true)

	return location, itemLink, count
end
