local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local views  = addon:GetModule('views')
local lists  = views:GetModule('lists')
local currencies = lists:NewModule('Currencies', 'AceEvent-3.0')
      currencies.icon = 'Interface\\Icons\\PVECurrency-Justice' -- INV_Misc_Token_Darkmoon_01
      currencies.title = 'Currencies'

function currencies:OnEnable()
	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', 'Update')
end
function currencies:OnDisable()
	self:UnregisterEvent('CURRENCY_DISPLAY_UPDATE')
end

function currencies:GetNumRows(characterKey)
	return addon.data.GetNumCurrencies(characterKey)
end

function currencies:GetRowInfo(characterKey, index)
	local isHeader, name, count, icon, weekly, currencyID = addon.data.GetCurrencyInfoByIndex(characterKey, index)
	local prefix -- = '|T'..icon..':0|t'
	local suffix = AbbreviateLargeNumbers(count)

	return isHeader and 1 or nil, name, prefix, suffix, currencyID and GetCurrencyLink(currencyID)
end

function currencies:GetItemInfo(characterKey, index, itemIndex)
	local icon, link, tooltipText, count, weekly, currencyID
	if itemIndex == 1 then
		local isHeader, title
		_, title, _, icon, weekly, currencyID = addon.data.GetCurrencyInfoByIndex(characterKey, index)
		if currencyID then
			link = GetCurrencyLink(currencyID)
		end
	end
	return icon, link, tooltipText, count
end

local CustomSearch = LibStub('CustomSearch-1.0')
local linkFilters  = {
	number = {
		tags       = {'number', 'no'},
		canSearch  = function(self, operator, search) return tonumber(search) end,
		match      = function(self, text, operator, search)
			local characterKey, hyperlink = text:match('^([^:]-): (.*)')

			-- currency specific search
			local currencyID   = addon.GetLinkID(hyperlink or '')
			local _, _, number = addon.data.GetCurrencyInfo(characterKey, currencyID)

			if number then
				return CustomSearch:Compare(operator, number, search)
			end
		end,
	},
}
for tag, handler in pairs(lists.filters) do
	linkFilters[tag] = handler
end
currencies.filters = linkFilters
