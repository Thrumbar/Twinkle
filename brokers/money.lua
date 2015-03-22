local addonName, addon, _ = ...

-- GLOBALS: _G, ipairs, string, ToggleCharacter, GetMoney, time, date, pairs

local brokers = addon:GetModule('brokers')
local broker  = brokers:NewModule('Money')

local copperPerGold = COPPER_PER_SILVER * SILVER_PER_GOLD
local function GetPrettyAmount(amount, style)
	local negative, amount = amount < 0, tostring(math.abs(amount))
	local gold, silver, copper = amount:sub(1, -5), amount:sub(-4, -3), amount:sub(-2, -1)
	      gold, silver, copper = tonumber(gold) or 0, tonumber(silver) or 0, tonumber(copper) or 0

	local prefix, goldSep, silverSep, copperSep = '', ' ', ' ', ''
	if not style or style == 'icon' then
		goldSep   = '|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t '
		silverSep = '|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t '
		copperSep = '|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t '
	elseif style == 'gsc' then
		prefix    = _G.HIGHLIGHT_FONT_COLOR_CODE
		goldSep   = '|cffffd700g|r '.._G.HIGHLIGHT_FONT_COLOR_CODE
		silverSep = '|cffc7c7cfs|r '.._G.HIGHLIGHT_FONT_COLOR_CODE
		copperSep = '|cffeda55fc|r'
	elseif style == 'dot' then
		prefix    = '|cffffd700'
		goldSep   = '|r.|cffc7c7cf'
		silverSep = '|r.|cffeda55f'
		copperSep = '|r'
	end

	local stringFormat = string.join('', prefix, '%s', goldSep, '%02d', silverSep, '%02d', copperSep)
	return (negative and '-' or '') .. string.format(stringFormat, BreakUpLargeNumbers(gold), silver, copper)
end

function broker:Prune(oldestDate)
	oldestDate = oldestDate or date('%Y-%m-%d', time() - 30*24*60*60)

	for dateStamp, money in pairs(self.db.global.history) do
		if dateStamp < oldestDate then
			self.db.global.history[dateStamp] = nil
		end
	end
end

function broker:GetAccountMoney()
	local money = 0
	for _, characterKey in ipairs(self.characters) do
		if characterKey == addon.data.GetCurrentCharacter() then
			money = money + GetMoney()
		else
			local amount = addon.data.GetMoney(characterKey)
			money = money + (amount or 0)
		end
	end
	return money
end

function broker:GetHistoryValues()
	local today     = date('%Y-%m-%d')
	local timeDiff  = time() -  1*24*60*60
	local lastDay   = date('%Y-%m-%d', timeDiff)
	      timeDiff  = timeDiff -  6*24*60*60
	local lastWeek  = date('%Y-%m-%d', timeDiff)
	      timeDiff  = timeDiff - 11*24*60*60
	local lastMonth = date('%Y-%m-%d', timeDiff)
	-- find last month, length varies from 28-31 days
	while lastMonth:sub(1, 7) == today:sub(1, 7) do
		timeDiff  = timeDiff - 1*24*60*60
		lastMonth = date('%Y-%m-%d', timeDiff)
	end

	local dayDate, weekDate, monthDate
	-- we only need the most recent date before each timespan
	for dateStamp, money in pairs(self.db.global.history) do
		-- some dates might not exist because we didn't log in
		if not monthDate
			or (dateStamp <= lastMonth and dateStamp > monthDate) -- valid date but more recent
			or (dateStamp >  lastMonth and dateStamp < monthDate) -- invalid but closer to lastMonth
		then
			monthDate = dateStamp
		end
		if not weekDate
			or (dateStamp <= lastWeek and dateStamp > weekDate) -- valid date but more recent
			or (dateStamp >  lastWeek and dateStamp < weekDate) -- invalid but closer to lastWeek
		then
			weekDate = dateStamp
		end
		if not dayDate or (dateStamp <= lastDay and dateStamp > dayDate) then
			dayDate = dateStamp
		end
	end

	local session = self.session
	local day     = dayDate   and self.db.global.history[dayDate]   or session
	local week    = weekDate  and self.db.global.history[weekDate]  or session
	local month   = monthDate and self.db.global.history[monthDate] or session
	return session, day, week, month
end

local function MoneySort(keyA, keyB)
	local amountA = addon.data.GetMoney(keyA)
	local amountB = addon.data.GetMoney(keyB)
	return amountA > amountB
end

local defaults = {
	global = {
		history = {},
	},
	profile = {
		ldbFormat = 'icon',
		tooltipFormat = 'gsc',
	},
}
function broker:OnEnable()
	self.characters = addon.data.GetCharacters()
	self.db = addon.db:RegisterNamespace('Money', defaults)
	self:Prune()

	local today = date('%Y-%m-%d')
	self.session = self:GetAccountMoney()
	self.db.global.history[today] = self.session

	-- create config ui
	--[[ local types = {
		history = '*none*',
		tooltipFormat = {
			gsc  = GetPrettyAmount(540321, 'gsc'),
			icon = GetPrettyAmount(540321, 'icon'),
			dot  = GetPrettyAmount(540321, 'dot'),
		},
	}
	types.ldbFormat = types.tooltipFormat

	local optionsTable = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(self.db, types)
	      optionsTable.name = addonName .. ' - Money'
	LibStub('AceConfig-3.0'):RegisterOptionsTable(self.name, optionsTable)
	-- added to options when options panel gets loaded --]]

	self:RegisterEvent('PLAYER_MONEY', self.Update, self)
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('PLAYER_MONEY')
end

function broker:OnClick(btn, down)
end

function broker:UpdateLDB()
	self.text = GetPrettyAmount(GetMoney(), broker.db.profile.ldbFormat)
	self.icon = 'Interface\\Minimap\\Tracking\\Auctioneer'

	local today = date('%Y-%m-%d')
	broker.db.global.history[today] = broker:GetAccountMoney()
end

function broker:UpdateTooltip()
	local numColumns, lineNum = 2
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	-- lineNum = self:AddHeader()
	-- 		  self:SetCell(lineNum, 1, addonName .. ': ' .. _G.MONEY, 'LEFT', numColumns)

	local currentMoney = broker:GetAccountMoney()
	local session, day, week, month = broker:GetHistoryValues()
	local tooltipFormat = broker.db.profile.tooltipFormat
	self:AddLine('This Session', GetPrettyAmount(currentMoney - session, tooltipFormat))
	self:AddLine('Last Day',     GetPrettyAmount(currentMoney - day,     tooltipFormat))
	self:AddLine('Last Week',    GetPrettyAmount(currentMoney - week,    tooltipFormat))
	self:AddLine('Last Month',   GetPrettyAmount(currentMoney - month,   tooltipFormat))
	self:AddLine(' ')
	-- bg: :SetCellColor(lineNum, colNum, r, g, b, a)
	-- bg: :SetLineColor(lineNum, r, g, b, a)

	table.sort(broker.characters, MoneySort)
	for _, characterKey in ipairs(broker.characters) do
		local amount = addon.data.GetMoney(characterKey)

		lineNum = self:AddLine(
			addon.data.GetCharacterText(characterKey),
			GetPrettyAmount(amount, tooltipFormat)
		)
	end

	if currentMoney and currentMoney > 0 then
		self:AddSeparator(2)
		lineNum = self:AddLine(_G.TOTAL, GetPrettyAmount(currentMoney, tooltipFormat))
	end
end
