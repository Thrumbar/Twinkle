local addonName, ns, _ = ...
local moduleName = 'Currency'

-- GLOBALS: _G, NORMAL_FONT_COLOR, LibStub, DataStore
-- GLOBALS: GetCurrencyInfo, ToggleCharacter, AbbreviateLargeNumbers, RGBToColorCode
-- GLOBALS: wipe, unpack, select, pairs, ipairs, strsplit, table, math, string

--[[
  TODO list:
  	- [config] currency order
  	- [config] currencies to display in LDB
  	- [config] currencies to display in tooltip
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
	392,	-- honor
	390,	-- conquest
	738,	-- lesser coin of fortune
	776,	-- loot coin
	777,	-- timeless
}
local showCurrencyInLDB = {
	396, -- valor
	776, -- warforged
	777, -- timless
}
local associatedQuests = {
	[738] = { 33133, 33134 }
}

-- ========================================================
--  Gathering data
-- ========================================================
local function GetGeneralCurrencyInfo(currencyID)
	local name, _, texture, _, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(currencyID)
	if currencyID == 395 or currencyID == 396 or currencyID == 392 or currencyID == 390 then
		weeklyMax = weeklyMax and math.floor(weeklyMax / 100)
		totalMax  = totalMax  and math.floor(totalMax / 100)
	end

	return name, texture, totalMax, weeklyMax, associatedQuests[currencyID]
end

local currencyReturns = {}
local function GetCurrencyHeaders()
	wipe(currencyReturns)
	for i, currencyID in ipairs(showCurrency) do
		local name, texture, _, weeklyMax = GetGeneralCurrencyInfo(currencyID)
		table.insert(currencyReturns, texture and '|T'..texture..':0|t' or name)
		table.insert(currencyReturns, weeklyMax > 0 and '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t' or '')
	end
	return unpack(currencyReturns)
end

-- ========================================================
--  Display data
-- ========================================================
local function GetPercentageColourGradient(percent)
	percent = percent > 1 and percent or percent * 100
    local _, x = math.modf(percent * 0.02)
    return (percent <= 50) and 1 or (percent >= 100) and 0 or (1 - x),
           (percent >= 50) and 1 or (percent <= 0) and 0 or x,
           0
end

local function PrettyPrint(characterKey, currencyID, total, weekly)
	local name, texturePath, totalMax, weeklyMax, quests = GetGeneralCurrencyInfo(currencyID)

	total = total or 0
	local totalText = AbbreviateLargeNumbers(total)
	if totalMax > 0 then
		totalText = RGBToColorCode( GetPercentageColourGradient(1 - (total / totalMax)) ) .. totalText .. '|r'
	end

	weekly = weekly or 0
	local weeklyText = AbbreviateLargeNumbers(weekly)
	if weeklyMax == 0 then
		weeklyText = ''
	else
		weeklyText = RGBToColorCode( GetPercentageColourGradient(1 - (weekly / weeklyMax)) ) .. weeklyText .. '|r'
	end

	if quests then
		local isDone = false
		for _, questID in pairs(quests) do
			if DataStore:IsWeeklyQuestCompletedBy(characterKey, questID) then
				isDone = true
				break
			end
		end
		if isDone then
			if weeklyMax > 0 or totalMax > 0 then
				totalText = (totalText ~= '' and totalText .. ' ' or '') .. '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t'
			else
				totalText = _G.GRAY_FONT_COLOR_CODE .. totalText .. '|r'
			end
		end
	end

	return totalText, weeklyText
end

local function GetCurrencyCounts(characterKey, prettyPrint)
	wipe(currencyReturns)
	local hasData
	for index, currencyID in ipairs(showCurrency) do
		local _, name, total, _, weekly = ns.data.GetCurrencyInfo(characterKey, currencyID)
		if (total and total > 0) or (weekly and weekly > 0) then
			hasData = true
		end
		if prettyPrint then
			local prettyTotal, prettyWeekly = PrettyPrint(characterKey, currencyID, total, weekly)
			table.insert(currencyReturns, prettyTotal)
			table.insert(currencyReturns, prettyWeekly)
		else
			table.insert(currencyReturns, total or 0)
			table.insert(currencyReturns, weekly or 0)
		end
	end
	return hasData and currencyReturns or nil
end

-- ========================================================
--  LDB Display & Sorting
-- ========================================================
-- forward declaration
local OnLDBEnter = function() end

local sortCurrencyIndex, sortCurrencyReverse
local function SortByCharacter(a, b)
	if sortCurrencyReverse then
		return ns.data.GetName(a) > ns.data.GetName(b)
	else
		return ns.data.GetName(a) < ns.data.GetName(b)
	end
end
local function SortByCurrency(a, b)
	local countA = GetCurrencyCounts(a)
	      countA = countA and countA[sortCurrencyIndex] or 0
	local countB = GetCurrencyCounts(b)
	      countB = countB and countB[sortCurrencyIndex] or 0
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
local function NOOP() end -- does nothing
OnLDBEnter = function(self)
	local numColumns = (#showCurrency * 2) + 1
	if LibStub('LibQTip-1.0'):IsAcquired(addonName..moduleName) then
		tooltip:Clear()
	else
		tooltip = LibQTip:Acquire(addonName..moduleName, numColumns, 'LEFT', strsplit(',', string.rep('RIGHT,', numColumns-1)))
		tooltip:SmartAnchorTo(self)
		tooltip:SetAutoHideDelay(0.25, self)
		tooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	local lineNum
	lineNum = tooltip:AddHeader()
			  tooltip:SetCell(lineNum, 1, addonName .. ': ' .. _G.CURRENCY, 'LEFT', numColumns)
	-- tooltip:AddSeparator(2)

	lineNum = tooltip:AddLine(_G.CHARACTER, GetCurrencyHeaders())
	for column = 1, numColumns do
		-- make list sortable
		tooltip:SetCellScript(lineNum, column, 'OnMouseUp', SortCurrencyList, column-1)
		if column%2 == 0 then
			-- show tooltip for currency headers
			local cell = tooltip.lines[lineNum].cells[column]
			      cell.link = 'currency:'..showCurrency[column/2]
			tooltip:SetCellScript(lineNum, column, 'OnEnter', ns.ShowTooltip, tooltip)
			tooltip:SetCellScript(lineNum, column, 'OnLeave', ns.HideTooltip, tooltip)
		end
	end
	tooltip:AddSeparator(2)

	for _, characterKey in ipairs(characters) do
		local data = GetCurrencyCounts(characterKey, true)
		if data then
			lineNum = tooltip:AddLine( ns.data.GetCharacterText(characterKey),  unpack(data))
			tooltip:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
		end
	end

	tooltip:Show()
end

local function Update(self)
	local currencies = GetCurrencyCounts(thisCharacter, true)
	local currenciesString
	if currencies then
		for _, currencyID in ipairs(showCurrencyInLDB) do
			local currencyIndex
			-- get corresponding index in data
			for index, currency in ipairs(showCurrency) do
				if currency == currencyID then
					currencyIndex = index
					break
				end
			end

			-- append to displayed text
			local index = currencyIndex * 2 - 1
			local _, _, texturePath = GetCurrencyInfo(currencyID)
			currenciesString = (currenciesString and currenciesString .. ' ' or '')
				.. string.format('%2$s%3$s |T%1$s:0|t', texturePath,
					currencies[index],
					currencies[index+1] ~= '' and ' ('..currencies[index+1]..')' or '')
		end
	end

	local ldb = LDB:GetDataObjectByName(addonName..moduleName)
	if ldb then
		ldb.text = currenciesString
	end

	-- update tooltip, if shown
	if LibQTip:IsAcquired(addonName..moduleName) then
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
		LDB:NewDataObject(addonName..moduleName, {
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
		-- Update() -- not needed here, since we need CURRENCY_DISPLAY_UPDATE first

		ns.UnregisterEvent('ADDON_LOADED', 'currencies')
	end
end, 'currencies')

ns.RegisterEvent('CURRENCY_DISPLAY_UPDATE', Update, 'currencies_update')
-- ns.RegisterEvent('PLAYER_MONEY', function()
-- 	Update()
-- 	ns.UnregisterEvent('PLAYER_MONEY', 'currencies_init')
-- end, 'currencies_init')
