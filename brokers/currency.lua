local addonName, ns, _ = ...

-- GLOBALS: _G, NORMAL_FONT_COLOR, LibStub
-- GLOBALS: GetCurrencyInfo, ToggleCharacter
-- GLOBALS: wipe, unpack, select, pairs, ipairs, strsplit

--[[
  TODO list:
  	- [config] currency order
  	- [config] currencies to display in LDB
  	- [config] currencies to display in tooltip
  	- [feature] colorize for current/max count
  	- [feature] colorize for current/weekly count
  	- [feature] add indicator for related (weekly) quests

	[drag handle] [icon] currency name 		[x:ldb] [x:tooltip]

--]]

local LDB     = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-1.0')

local characters = {}
local thisCharacter = ns.data.GetCurrentCharacter()
local currencies = {}
local showCurrency = {
	395,	-- justice
	396,	-- valor
	-- 392,	-- honor
	-- 390,	-- conquest
	738,	-- lesser coin of fortune
	776,	-- loot coin
	777,	-- timeless
}
local showCurrencyInLDB = {
	[396] = true,
	[776] = true,
	[777] = true,
}


-- ========================================================
--  Gathering data
-- ========================================================
local function ShowCurrency(name)
	local currencyName
	for _, currencyID in ipairs(showCurrency) do
		currencyName = GetCurrencyInfo(currencyID)
		if name == currencyName then
			return currencyID
		end
	end
end

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
	wipe(currencyReturns)
	for _, currencyID in pairs(showCurrency) do
		local isHeader, name, count, icon = ns.data.GetCurrencyInfo(characterKey or thisCharacter, currencyID)
		table.insert(currencyReturns, count or 0)
	end

	if asTable then
		return currencyReturns
	else
		return unpack(currencyReturns)
	end
end

--[[
local function GetCharacterCurrencyInfo(character, currency)
	local name, currentAmount, _, weeklyAmount, weeklyMax, totalMax = GetCurrencyInfo(currency)
	if character ~= thisCharacter then
		currentAmount = 0
		weeklyAmount = DataStore:GetCurrencyWeeklyAmount(character, currency)
		if IsAddOnLoaded('DataStore_Currencies') then
			_, _, currentAmount = DataStore:GetCurrencyInfoByName(character, name)
		end
	end
	currentAmount = currentAmount or 0
	weeklyAmount  = weeklyAmount or 0

	if totalMax%100 == 99 then -- valor and justice caps are weird
		totalMax  = math.floor(totalMax/100)
		weeklyMax = math.floor(weeklyMax/100)
	end

	return currentAmount, totalMax, weeklyAmount, weeklyMax
end
--]]

-- ========================================================
--  LDB Display & Sorting
-- ========================================================
-- forward declaration
local OnLDBEnter = function() end

local sortCurrencyIndex, sortCurrencyReverse
local function SortByCharacter(a, b)
	return ns.data.GetName(a) < ns.data.GetName(b)
end
local function SortByCurrency(a, b)
	local countA = select(sortCurrencyIndex, GetCurrencyCounts(a))
	local countB = select(sortCurrencyIndex, GetCurrencyCounts(b))
	if sortCurrencyReverse then
		return countA > countB
	else
		return countA < countB
	end
end
local function SortCurrencyList(self, sortType, btn, up)
	if sortType == 0 then
		table.sort(characters, SortByCharacter)
	else
		if sortCurrencyIndex == sortType then
			sortCurrencyReverse = not sortCurrencyReverse
		else
			sortCurrencyIndex = sortType
			sortCurrencyReverse = false
		end
		table.sort(characters, SortByCurrency)
	end
	OnLDBEnter()
end

local tooltip
local function OnLDBEnter(self)
	local numColumns = #showCurrency + 1
	if LibStub('LibQTip-1.0'):IsAcquired('TwinkleCurrency') then
		tooltip:Clear()
	else
		tooltip = LibQTip:Acquire(addonName..'Currency', numColumns, 'LEFT', strsplit(',', string.rep('RIGHT,', numColumns-1)))
		tooltip:SmartAnchorTo(self)
		tooltip:SetAutoHideDelay(0.25, self)
		tooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	local lineNum
	lineNum = tooltip:AddHeader()
			  tooltip:SetCell(lineNum, 1, addonName .. 'Currency', 'CENTER', numColumns)
	tooltip:AddSeparator(2)

	lineNum = tooltip:AddLine(_G.CHARACTER, GetCurrencyHeaders())
	for column = 1, numColumns do
		-- make list sortable
		tooltip:SetCellScript(lineNum, column, 'OnMouseUp', SortCurrencyList, column-1)
		if column > 1 then
			-- show tooltip for currency headers
			local cell = tooltip.lines[lineNum].cells[column]
			      cell.link = 'currency:'..showCurrency[column-1]
			tooltip:SetCellScript(lineNum, column, 'OnEnter', ns.ShowTooltip, tooltip)
			tooltip:SetCellScript(lineNum, column, 'OnLeave', ns.HideTooltip, tooltip)
		end
	end
	tooltip:AddSeparator(2)

	for _, characterKey in ipairs(characters) do
		lineNum = tooltip:AddLine( ns.data.GetCharacterText(characterKey),  GetCurrencyCounts(characterKey) )
	end

	tooltip:Show()
end

local function Update(self)
	local currencies = GetCurrencyCounts(nil, true)
	for i = #currencies, 1, -1 do
		if currencies[i] == '' or not showCurrencyInLDB[ showCurrency[i] ] then
			table.remove(currencies, i)
		else
			local _, _, icon = GetCurrencyInfo( showCurrency[i] )
			currencies[i] = string.format('%1$s |T%2$s:0|t', currencies[i], icon)
		end
	end

	local ldb = LDB:GetDataObjectByName(addonName..'Currency')
	if ldb then
		ldb.text = table.concat(currencies, ' ')
	end

	-- update tooltip, if shown
	if LibQTip:IsAcquired(addonName..'Currency') then
		OnLDBEnter(self)
	end
end

local function OnLDBClick(self, btn, down)
	ToggleCharacter("TokenFrame")
end

-- ========================================================
--  Setup
-- ========================================================
ns.RegisterEvent('ADDON_LOADED', function(frame, event, arg1)
	if arg1 == addonName then
		local plugin = LDB:NewDataObject(addonName..'Currency', {
			type	= 'data source',
			label	= _G.CURRENCY,
			-- text 	= CURRENCY,
			-- icon    = 'Interface\\Icons\\Spell_Holy_EmpowerChampion',

			OnClick = OnLDBClick,
			OnEnter = OnLDBEnter,
			OnLeave = function() end,	-- needed for e.g. NinjaPanel
		})

		-- fill character list
		characters = ns.data.GetCharacters(characters)

		-- fill currencies list
		for _, characterKey in ipairs(characters) do
			for index = 1, ns.data.GetNumCurrencies(characterKey) or 0 do
				local isHeader, name = ns.data.GetCurrencyInfoByIndex(characterKey, index)
				if not isHeader and not ns.Find(currencies, name) then
					-- TODO: would be more useful to have currencyID instead ...
					table.insert(currencies, name)
				end
			end
		end

		ns.UnregisterEvent('ADDON_LOADED', 'currencies')
	end
end, 'currencies', true)

ns.RegisterEvent('CURRENCY_DISPLAY_UPDATE', Update, 'currencies_update')
