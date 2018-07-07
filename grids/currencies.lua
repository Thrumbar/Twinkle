local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local views = addon:GetModule('views')
local grids = views:GetModule('grids')
local currencies = grids:NewModule('currencies', 'AceEvent-3.0')
      currencies.icon = 'Interface\\Icons\\ability_racial_packhobgoblin' -- pvecurrency-justice
      currencies.title = 'Currencies'

function currencies:OnEnable()
	-- @todo Add event for money updates.
	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', 'Update')
end
function currencies:OnDisable()
	self:UnregisterEvent('CURRENCY_DISPLAY_UPDATE')
end

function currencies:GetNumColumns()
	return 1 + addon.data.GetNumCurrencies(characterKey)
end

function currencies:GetColumnInfo(index)
	local text, link, tooltipText, justify

	if index == 1 then
		-- Gold
		return 'Gold |TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t', nil, nil, 'RIGHT'
	end
	index = index + 1

	local _, name, count, icon, weekly, currencyID = addon.data.GetCurrencyInfoByIndex(addon.data.GetCurrentCharacter(), -1 * index)
	if name then
		text = '|T' .. icon .. ':0|t'
		link = GetCurrencyLink(currencyID)
	end
	return text, link, tooltipText, justify
end

function currencies:GetCellInfo(characterKey, index)
	local text, link, tooltipText, justify

	if index == 1 then
		-- Gold
		local value = addon.data.GetMoney(characterKey)
		return AbbreviateLargeNumbers(math.floor(value/COPPER_PER_GOLD)), nil, GetCoinTextureString(value), 'RIGHT'
	end
	index = index + 1

	local _, name, count, _, weekly, currencyID = addon.data.GetCurrencyInfoByIndex(characterKey, -1 * index)
	if name then
		text = AbbreviateLargeNumbers(count)
		local _, _, _, _, weeklyMax, totalMax = GetCurrencyInfo(currencyID)
		if count > 0 and totalMax > 0 then
			text = addon.ColorizeText(text, count, totalMax)
		end
	end
	return text, link, tooltipText, justify
end
