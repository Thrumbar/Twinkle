local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: GetItemInfo
-- GLOBALS: string

local LibItemLocations = LibStub('LibItemLocations', true)

local views = addon:GetModule('views')
local items = views:GetModule('items')
local mails       = items:NewModule('Mails', 'AceEvent-3.0')
      mails.icon  = 'Interface\\MINIMAP\\TRACKING\\Mailbox'
      mails.title = _G.INBOX or 'Mails'

function mails:OnEnable()
	self:RegisterEvent('MAIL_INBOX_UPDATE', 'Update')
end
function mails:OnDisable()
	self:UnregisterEvent('MAIL_INBOX_UPDATE')
end

function mails:GetNumRows(characterKey)
	return addon.data.GetNumMails(characterKey)
end

function mails:GetRowInfo(characterKey, index)
	local mailIndex, attachmentIndex = 0, index
	local location = LibItemLocations:PackInventoryLocation(mailIndex, attachmentIndex, nil, nil, nil, nil, nil, true)
	local sender, expires, _, count, itemLink = addon.data.GetMailInfo(characterKey, index)

	--[[ if timeLeft then
		if timeLeft <= 7*24*60*60 then
			item.level:SetTextColor(1, 0, 0)
		else
			item.level:SetTextColor(1, 0.82, 0)
		end
		item.level:SetFormattedText(SecondsToTimeAbbrev(timeLeft))
	else
		item.level:SetTextColor(1, 1, 1)
		item.level:SetFormattedText("%4d", iLevel or 0)
	end --]]

	return location, itemLink, count
end

-- ======================================
-- local addonName, addon, _ = ...

-- GLOBALS: _G
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
