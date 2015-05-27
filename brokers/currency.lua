local addonName, addon, _ = ...

-- GLOBALS: _G, NORMAL_FONT_COLOR, LibStub, DataStore
-- GLOBALS: GetCurrencyInfo, ToggleCharacter, AbbreviateLargeNumbers, GetCurrencyListSize, GetCurrencyListInfo, GetCurrencyListLink, ExpandCurrencyList
-- GLOBALS: wipe, unpack, select, pairs, ipairs, strsplit, table, math, string, nop

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Currency')
local characters = {}

--[[
  TODO list:
  	- [config] currency order: [drag handle] [icon] currency name 	[x:ldb] [x:tooltip]
--]]

local function GetGeneralCurrencyInfo(currencyID)
	-- FIXME: for some reason, max counts are not available for undiscovered currencies
	local name, _, texture, _, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(currencyID)
	if currencyID == 824 then
		-- garrison resource: display uncollected as weekly
		weeklyMax = 500
	elseif currencyID == 994 then
		-- seal of tempered fate
		weeklyMax = 3
	end
	return name, texture, totalMax, weeklyMax
end

local function GetGradientColor(percent)
	percent = percent > 1 and percent or percent * 100
    local _, x = math.modf(percent * 0.02)
    return (percent <= 50) and 1 or (percent >= 100) and 0 or (1 - x),
           (percent >= 50) and 1 or (percent <= 0) and 0 or x,
           0
end

local collapsed = {}
local function ScanCurrencies()
	local index = 1
	while index <= GetCurrencyListSize() do
		local name, isHeader, isExpanded, _, isWatched, count, icon, maximum, hasWeeklyLimit = GetCurrencyListInfo(index)
		if isHeader and not isExpanded then
			table.insert(collapsed, index)
			ExpandCurrencyList(index, true)
		elseif not isHeader then
			local link = GetCurrencyListLink(index)
			local currencyID = link and link:match('currency:(%d+)') * 1
			if currencyID then
				if broker.db.profile.showInLDB[currencyID] == nil then
					-- new currency found, add to settings
					broker.db.profile.showInLDB[currencyID] = false
					broker.db.profile.showInTooltip[currencyID] = false
				end
			end
		end
		index = index + 1
	end
	-- restore collapsed states
	for index = #collapsed, 1, -1 do
		ExpandCurrencyList(index, false)
		collapsed[index] = nil
	end
end

local sortCurrency, sortCurrencyReverse
local function SortByCharacter(a, b)
	if sortCurrencyReverse then
		return addon.data.GetName(a) > addon.data.GetName(b)
	else
		return addon.data.GetName(a) < addon.data.GetName(b)
	end
end
local function SortByCurrency(charA, charB)
	local _, _, countA, _, weeklyA = addon.data.GetCurrencyInfo(charA, sortCurrency)
	local _, _, countB, _, weeklyB = addon.data.GetCurrencyInfo(charB, sortCurrency)
	if sortCurrency < 0 then
		-- sorting by weekly amounts
		countA, countB = weeklyA, weeklyB
	end
	if sortCurrencyReverse then
		return countA > countB
	else
		return countA < countB
	end
end
local function SortCurrencyList(self, sortType, btn, up)
	if sortCurrency == sortType then
		sortCurrencyReverse = not sortCurrencyReverse
	else
		sortCurrency = sortType
		sortCurrencyReverse = false
	end

	if sortType == 0 then
		table.sort(characters, SortByCharacter)
	else
		table.sort(characters, SortByCurrency)
	end
	broker:Update()
end

-- --------------------------------------------------------
--  Setup LDB
-- --------------------------------------------------------
local defaults = {
	profile = {
		showInTooltip = {
			[395] = false, -- justice
			[396] = false, -- valor
			[392] =  true, -- honor
			[390] =  true, -- conquest
			[824] =  true, -- garrison resources
			[823] =  true, -- apexis shard
			[994] =  true, -- seal of tempered fate
			[738] = false, -- lesser coin of fortune
			[776] = false, -- war emblem
			[777] = false, -- timeless
		},
		showInLDB = {
			[824] = true, -- garrison resources
			[823] = true, -- apexis shard
			[994] = true, -- seal of tempered fate
		},
		iconFirst = true,
		showWeeklyInLDB = true,
	},
}
function broker:OnEnable()
	characters = brokers:GetCharacters()
	self.db = addon.db:RegisterNamespace('Currency', defaults)
	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', self.Update, self)
	self:RegisterEvent('SHOW_LOOT_TOAST', function(self, event, lootType, link, quantity, specID, sex, isPersonal, lootSource)
		if lootSource == 10 then -- garrison cache
			self:Update()
		end
	end, self)
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('CURRENCY_DISPLAY_UPDATE')
end

function broker:OnClick(btn, down)
	if btn == 'RightButton' then
		InterfaceOptionsFrame_OpenToCategory(addonName)
	else
		ToggleCharacter('TokenFrame')
	end
end

function broker:UpdateLDB()
	ScanCurrencies()

	local characterKey, currenciesString = brokers:GetCharacter(), nil
	for currencyID, isShown in pairs(broker.db.profile.showInLDB) do
		if isShown then
			local _, name, total, icon, weekly = addon.data.GetCurrencyInfo(characterKey, currencyID)
			local _, _, totalMax, weeklyMax = GetGeneralCurrencyInfo(currencyID)

			local text = AbbreviateLargeNumbers(total)
			if totalMax > 0 then
				local r, g, b = GetGradientColor(1 - (total / totalMax))
				text = ('|cff%02x%02x%02x%s|r'):format(r*255, g*255, b*255, text)
			end
			if addon.db.profile.showWeeklyInLDB and weeklyMax and weekly > 0 then
				local r, g, b = GetGradientColor(1 - (weekly / weeklyMax))
				local weeklyText = ('|cff%02x%02x%02x%s|r'):format(r*255, g*255, b*255, AbbreviateLargeNumbers(weekly))
				text = ('%s (%s%s)'):format(text, '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t', weeklyText)
			end

			if broker.db.profile.iconFirst then
				text = '|T'..icon..':0|t ' .. text
			else
				text = text .. ' |T'..icon..':0|t'
			end
			currenciesString = (currenciesString and currenciesString .. ' ' or '') .. text
		end
	end

	self.text = currenciesString
	self.icon = 'Interface\\Minimap\\Tracking\\BattleMaster'
end

function broker:UpdateTooltip()
	self:SetColumnLayout(1, 'LEFT')
	local lineNum, column = self:AddHeader(_G.CHARACTER), 2
	-- sort by character name
	self:SetCellScript(lineNum, 1, 'OnMouseUp', SortCurrencyList, 0)
	for currencyID, isShown in pairs(broker.db.profile.showInTooltip) do
		if isShown then
			local name, texture, totalMax, weeklyMax = GetGeneralCurrencyInfo(currencyID)
			if column > #self.columns then column = self:AddColumn('RIGHT') end
			self:SetCell(lineNum, column, texture and '|T'..texture..':0|t' or name)
			self.lines[lineNum].cells[column].link = 'currency:'..currencyID
			self:SetCellScript(lineNum, column, 'OnEnter', addon.ShowTooltip, self)
			self:SetCellScript(lineNum, column, 'OnLeave', addon.HideTooltip, self)
			self:SetCellScript(lineNum, column, 'OnMouseUp', SortCurrencyList, currencyID)
			column = column + 1

			if weeklyMax and weeklyMax > 0 then
				if column > #self.columns then column = self:AddColumn('RIGHT') end
				self:SetCell(lineNum, column, '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t')
				self:SetCellScript(lineNum, column, 'OnMouseUp', SortCurrencyList, -1*currencyID)
				column = column + 1
			end
		end
	end
	self:AddSeparator(2)

	local addLine = true
	for _, characterKey in ipairs(characters) do
		if addLine then lineNum = self:AddLine(); addLine = false end
		self:SetCell(lineNum, 1, addon.data.GetCharacterText(characterKey))
		self:SetLineScript(lineNum, 'OnEnter', nop) -- show highlight on row

		local column = 2
		for currencyID, isShown in pairs(broker.db.profile.showInTooltip) do
			-- FIXME: this can lead to incorrect assignment due to order
			if isShown then
				local _, name, total, _, weekly = addon.data.GetCurrencyInfo(characterKey, currencyID)
				addLine = addLine or ((total or 0) > 0 or (weekly or 0) > 0)

				local _, _, totalMax, weeklyMax = GetGeneralCurrencyInfo(currencyID)
				local text = AbbreviateLargeNumbers(total)
				if totalMax > 0 then
					local r, g, b = GetGradientColor(1 - (total / totalMax))
					text = ('|cff%02x%02x%02x%s|r'):format(r*255, g*255, b*255, text)
				end
				self:SetCell(lineNum, column, text, 'RIGHT')
				column = column + 1

				if weeklyMax and weeklyMax > 0 then
					local r, g, b = GetGradientColor(1 - (weekly / weeklyMax))
					text = ('|cff%02x%02x%02x%s|r'):format(r*255, g*255, b*255, AbbreviateLargeNumbers(weekly))
					self:SetCell(lineNum, column, text, 'RIGHT')
					column = column + 1
				end
			end
		end
	end

	if addLine then lineNum = self:AddLine() end
	self:SetCell(lineNum, 1, _G.GRAY_FONT_COLOR_CODE..'Left click: open token frame'..'|r', 'LEFT', #self.columns)
end
