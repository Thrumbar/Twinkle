local addonName, addon, _ = ...

-- GLOBALS: GetCoinTextureString, GetMoney

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('money')

-- GLOBALS: _G, ipairs, string, ToggleCharacter

local copperPerGold = COPPER_PER_SILVER * SILVER_PER_GOLD
local function GetPrettyAmount(amount)
	local goldAmount = math.floor(amount / copperPerGold)
	local prettyAmount = GetCoinTextureString(amount - goldAmount * copperPerGold)
	if goldAmount > 0 then
		goldAmount = BreakUpLargeNumbers(goldAmount)
		prettyAmount = goldAmount..'|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t '..prettyAmount
	end
	return prettyAmount
end

function broker:OnEnable()
	self:RegisterEvent('PLAYER_MONEY', self.Update, self)
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('PLAYER_MONEY')
end

function broker:OnClick(btn, down)
end

function broker:UpdateLDB()
	self.text = GetPrettyAmount( GetMoney() )
end

function broker:UpdateTooltip()
	local numColumns, lineNum = 2
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	local lineNum
	lineNum = self:AddHeader()
			  self:SetCell(lineNum, 1, addonName .. ': ' .. _G.MONEY, 'LEFT', numColumns)

	local total
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		local amount = addon.data.GetMoney(characterKey)
		total = (total or 0) + amount

		lineNum = self:AddLine( addon.data.GetCharacterText(characterKey),
			GetPrettyAmount(amount)
		)
	end

	if total then
		self:AddSeparator(2)
		lineNum = self:AddLine(_G.TOTAL, GetPrettyAmount(total))
	end
end
