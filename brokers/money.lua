local addonName, addon, _ = ...

-- GLOBALS: GetCoinTextureString, GetMoney

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('money')

-- GLOBALS: _G, ipairs, string, ToggleCharacter

function broker:OnEnable()
	self:RegisterEvent('PLAYER_MONEY', self.Update)
	self:Update()
end
function broker:OnDisable()
	self:UnregisterEvent('PLAYER_MONEY')
end

function broker:OnClick(self, btn, down)
end

function broker:UpdateLDB()
	self.text = GetCoinTextureString( GetMoney() )
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
			GetCoinTextureString(amount)
		)
	end

	if total then
		self:AddSeparator(2)
		lineNum = self:AddLine(_G.TOTAL, GetCoinTextureString(total))
	end
end
