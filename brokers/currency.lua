local addonName, ns, _ = ...

-- GLOBALS: CURRENCY, NORMAL_FONT_COLOR
-- GLOBALS: GetCurrencyInfo
-- GLOBALS: wipe, unpack, select, pairs, ipairs

local LDB     = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-1.0')

local thisCharacter = ns.data.GetCurrentCharacter()
local showCurrency = {
	395,	-- justice
	396,	-- valor
	-- 392,	-- honor
	-- 390,	-- conquest
	738,	-- lesser coin of fortune
	776,	-- loot coin
	777,	-- timeless
}

local function ShowCurrency(name)
	local currencyName
	for _, currencyID in ipairs(showCurrency) do
		currencyName = GetCurrencyInfo(currencyID)
		if name == currencyName then
			return currencyID
		end
	end
end

local currencyInfos = {}
local currencyReturns = {}
local function GetCurrencyHeaders()
	wipe(currencyReturns)
	local name, texture
	for i, currencyID in ipairs(showCurrency) do
		name, _, texture = GetCurrencyInfo(currencyID)
		table.insert(currencyReturns, texture and '|T'..texture..':0|t' or name)
	end
	return unpack(currencyReturns)
end

local function GetCurrencyCounts(characterKey, asTable)
	wipe(currencyInfos)

	local numCurrencies = ns.data.GetNumCurrencies(characterKey or thisCharacter)
	local isHeader, name, count, icon, currencyID
	for index = 1, numCurrencies do
		isHeader, name, count, icon = ns.data.GetCurrencyInfo(characterKey or thisCharacter, index)
		currencyID = ShowCurrency(name)
		if not isHeader and currencyID then
			currencyInfos[currencyID] = count
		end
	end

	wipe(currencyReturns)
	for _, currencyID in pairs(showCurrency) do
		table.insert(currencyReturns, currencyInfos[currencyID] or '')
	end
	if asTable then
		return currencyReturns
	else
		return unpack(currencyReturns)
	end
end

local characters = {}
local tooltip
local function OnEnter(self)
	local numColumns = #showCurrency + 1
	if LibStub('LibQTip-1.0'):IsAcquired('TwinkleCurrency') then
		tooltip:Clear()
	else
		tooltip = LibQTip:Acquire(addonName..'Currency', numColumns)
		tooltip:SmartAnchorTo(self)
		tooltip:SetAutoHideDelay(0.25, self)
		tooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	local lineNum
	lineNum = tooltip:AddHeader()
			  tooltip:SetCell(lineNum, 1, addonName .. 'Currency', 'CENTER', numColumns)
	-- tooltip:AddSeparator(2)

	lineNum = tooltip:AddLine('', GetCurrencyHeaders())
	-- tooltip:SetCellScript(lineNum, 1, 'OnMouseUp', SortGuildList, 'note')
	tooltip:AddSeparator(2)

	for _, characterKey in ipairs(ns.data.GetCharacters(characters)) do
		lineNum = tooltip:AddLine( ns.data.GetCharacterText(characterKey),  GetCurrencyCounts(characterKey) )
	end

	tooltip:Show()
end

local function Update(self)
	local currencies = GetCurrencyCounts(nil, true)
	for i = #currencies, 1, -1 do
		if currencies[i] == '' then
			table.remove(currencies, i)
		else
			local _, _, icon = GetCurrencyInfo( showCurrency[i] )
			currencies[i] = string.format('%1$s|T%2$s:0|t', currencies[i], icon)
		end
	end

	local ldb = LDB:GetDataObjectByName(addonName..'Currency')
	if ldb then
		ldb.text = table.concat(currencies, ' ')
	end

	-- update tooltip, if shown
	if LibQTip:IsAcquired(addonName..'Currency') then
		OnEnter(self)
	end
end

local function OnClick(self, btn, down)
	-- body
end

ns.RegisterEvent('ADDON_LOADED', function(frame, event, arg1)
	if arg1 == addonName then
		local plugin = LDB:NewDataObject(addonName..'Currency', {
			type	= 'data source',
			label	= CURRENCY,
			-- text 	= CURRENCY,
			-- icon    = 'Interface\\Icons\\Spell_Holy_EmpowerChampion',

			OnClick = OnClick,
			OnEnter = OnEnter,
			OnLeave = function() end,	-- needed for e.g. NinjaPanel
		})

		ns.UnregisterEvent('ADDON_LOADED', 'currencies')
	end
end, 'currencies')

ns.RegisterEvent('CURRENCY_DISPLAY_UPDATE', Update, 'currencies_update')
