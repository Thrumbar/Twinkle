local addonName, addon, _ = ...

-- GLOBALS:

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('auctions')

local lists = {'Auctions', 'Bids'}
local function GetAuctionStatus(characterKey)
	local lastVisit = DataStore:GetAuctionHouseLastVisit(characterKey) or 0
	local now = GetTime()

	local numBids, numAuctions, expired
	local numGoblinBids, numGoblinAuctions, goblinExpired
	for _, list in pairs(lists) do
		local numEntries = list == 'Auctions' and DataStore:GetNumAuctions(characterKey) or DataStore:GetNumBids(characterKey)
		for i = 1, numEntries do
			local isGoblin, itemID, count, name, bidPrice, buyPrice, timeLeft = DataStore:GetAuctionHouseItemInfo(characterKey, list, i)
			if lastVisit + timeLeft < now then
				-- entry is expired
				goblinExpired = goblinExpired or isGoblin
				expired = expired or (not isGoblin)
			end
			if isGoblin then
				numGoblinBids = (numGoblinBids or 0) + (list == 'Bids' and 1 or 0)
				numGoblinAuctions = (numGoblinAuctions or 0) + (list == 'Auctions' and 1 or 0)
			else
				numBids = (numBids or 0) + (list == 'Bids' and 1 or 0)
				numAuctions = (numAuctions or 0) + (list == 'Auctions' and 1 or 0)
			end
		end
	end

	return numAuctions or 0, numBids or 0, expired,
		numGoblinAuctions or 0, numGoblinBids or 0, goblinExpired
end

local function GetAuctionStatusText(characterKey)
	local numMails = DataStore:GetNumMails(characterKey) or 0 -- GetInboxNumItems()
	local auctionsFaction, bidsFaction, factionExpired,
	      auctionsGoblin, bidsGoblin, goblinExpired = GetAuctionStatus(characterKey)

    local icon
	if (DataStore:GetNumExpiredMails(characterKey, 7) or 0) > 0 then	-- mails that last <7 days count as expired
		icon = 'Interface\\RAIDFRAME\\ReadyCheck-NotReady'
	elseif factionExpired or goblinExpired then
		icon = 'Interface\\RAIDFRAME\\ReadyCheck-Waiting'
	elseif numMails > 0 then
		icon = 'Interface\\Minimap\\TRACKING\\Mailbox'
	end

	local faction
	if auctionsFaction > 0 or bidsFaction > 0 then
		faction = auctionsFaction .. ' / ' .. bidsFaction
		faction = (factionExpired and _G.RED_FONT_COLOR_CODE or _G.GREEN_FONT_COLOR_CODE) .. faction .. '|r'
	end

	local neutral
	if auctionsGoblin > 0 or bidsGoblin > 0 then
		neutral = auctionsGoblin .. ' / ' .. bidsGoblin
		neutral = (factionExpired and _G.ORANGE_FONT_COLOR_CODE or _G.GREEN_FONT_COLOR_CODE) .. neutral .. '|r'
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
	local statusText, icon = GetAuctionStatusText(brokers:GetCharacter())
	self.text = statusText or '' -- 'No mail or auctions'
	self.icon = icon or 'Interface\\RAIDFRAME\\ReadyCheck-Ready'
end

function broker:UpdateTooltip()
	local numColumns, lineNum = 2
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	local lineNum
	lineNum = self:AddHeader()
			  self:SetCell(lineNum, 1, addonName .. ': ' .. _G.AUCTIONS, 'LEFT', numColumns)

	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local statusText, icon = GetAuctionStatusText(characterKey)
		if statusText or icon then
			lineNum = self:AddLine(
				'|T'..icon..':0|t ' .. addon.data.GetCharacterText(characterKey),
				statusText
			)
		end
	end
end
