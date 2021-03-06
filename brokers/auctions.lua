local addonName, addon, _ = ...

-- TODO: black market AH

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Auctions')
local characters = {}

local lists = {'Auctions', 'Bids'}
local function GetAuctionState(characterKey)
	local auctions, bids, lastVisit = addon.data.GetAuctionState(characterKey)
	local now = GetTime()

	local numBids, numAuctions, expired
	for _, list in pairs(lists) do
		local numEntries = list == 'Auctions' and auctions or bids
		for i = 1, numEntries or 0 do
			local isGoblin, itemID, count, name, bidPrice, buyPrice, timeLeft = addon.data.GetAuctionInfo(characterKey, list, i)
			if lastVisit + timeLeft < now then
				-- entry is expired
				expired = expired or (not isGoblin)
			end
			numBids = (numBids or 0) + (list == 'Bids' and 1 or 0)
			numAuctions = (numAuctions or 0) + (list == 'Auctions' and 1 or 0)
		end
	end

	return numAuctions or 0, numBids or 0, expired
end

local function GetAuctionStatusText(characterKey)
	local numMails, numExpired = addon.data.GetNumMails(characterKey)
	local numAuctions, numBids, expired = GetAuctionState(characterKey)

    local icon
	if numExpired > 0 then	-- mails that last <7 days count as expired
		icon = 'Interface\\RAIDFRAME\\ReadyCheck-NotReady'
	elseif expired then
		icon = 'Interface\\RAIDFRAME\\ReadyCheck-Waiting'
	elseif numMails > 0 then
		icon = 'Interface\\Minimap\\TRACKING\\Mailbox'
	end

	local faction
	if numAuctions > 0 or numBids > 0 then
		faction = numAuctions .. ' / ' .. numBids
		faction = (expired and _G.RED_FONT_COLOR_CODE or _G.GREEN_FONT_COLOR_CODE) .. faction .. '|r'
	end

	local result = faction
	if neutral then
		result = (faction and faction..', ' or '') .. neutral
	end
	return result, icon
end

function broker:OnEnable()
	self:RegisterEvent('AUCTION_HOUSE_CLOSED', self.Update, self)
	self:RegisterEvent('AUCTION_HOUSE_SHOW', self.Update, self)
	self:RegisterEvent('MAIL_INBOX_UPDATE', self.Update, self)
	self:RegisterEvent('MAIL_CLOSED', self.Update, self) -- DataStore does not update nicely
	-- self:RegisterEvent('MAIL_SHOW', self.Update, self)
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('AUCTION_HOUSE_CLOSED')
	self:UnregisterEvent('AUCTION_HOUSE_SHOW')
	self:UnregisterEvent('MAIL_INBOX_UPDATE')
	self:UnregisterEvent('MAIL_CLOSED')
	-- self:UnregisterEvent('MAIL_SHOW')
end

function broker:OnClick(btn, down)
end

function broker:UpdateLDB()
	local statusText, icon = GetAuctionStatusText(addon.data.GetCurrentCharacter())
	self.text = statusText or '' -- 'No mail or auctions'
	self.icon = icon or 'Interface\\RAIDFRAME\\ReadyCheck-Ready'
end

function broker:UpdateTooltip()
	local numColumns, lineNum = 2
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	-- lineNum = self:AddHeader()
	-- 		  self:SetCell(lineNum, 1, addonName .. ': ' .. _G.AUCTIONS, 'LEFT', numColumns)

	local hasData = false
	for _, characterKey in ipairs(addon.data.GetCharacters(characters)) do
		local statusText, icon = GetAuctionStatusText(characterKey)
		if statusText or icon then
			hasData = true
			lineNum = self:AddLine(
				'|T'..(icon or 'Interface\\RAIDFRAME\\ReadyCheck-Ready')..':0|t ' .. addon.data.GetCharacterText(characterKey),
				statusText
			)
		end
	end
	return not hasData
end
