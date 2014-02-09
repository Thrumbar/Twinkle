local addonName, ns, _ = ...

-- GLOBALS: _G, LibStub, NORMAL_FONT_COLOR, GetCoinTextureString, GetMoney
-- GLOBALS: string, strsplit, ipairs
local LDB     = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-1.0')

local characters = {}
local thisCharacter = ns.data.GetCurrentCharacter()

-- ========================================================
--  Character list
-- ========================================================
local charactersTooltip
local function OnCharactersLDBEnter(self)
	local numColumns = 3
	if LibStub('LibQTip-1.0'):IsAcquired(addonName..'Characters') then
		charactersTooltip:Clear()
	else
		charactersTooltip = LibQTip:Acquire(addonName..'Characters', numColumns,
			'LEFT', strsplit(',', string.rep('RIGHT,', numColumns-1)))
		charactersTooltip:SmartAnchorTo(self)
		charactersTooltip:SetAutoHideDelay(0.25, self)
		charactersTooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	local lineNum
	lineNum = charactersTooltip:AddHeader()
			  charactersTooltip:SetCell(lineNum, 1, addonName .. ': ' .. _G.CHARACTER, 'LEFT', numColumns)
	-- charactersTooltip:AddSeparator(2)

	for _, characterKey in ipairs(characters) do
		lineNum = charactersTooltip:AddLine(ns.data.GetCharacterText(characterKey),
			ns.data.GetLevel(characterKey),
			ns.data.GetAverageItemLevel(characterKey)
		)
	end
	charactersTooltip:Show()
end

local function UpdateCharacters()
	local ldb = LDB:GetDataObjectByName(addonName..'Characters')
	if ldb then
		local levelInfo = ns.data.GetLevel(thisCharacter)
		-- if levelInfo == 90 then
		-- 	levelInfo = ns.data.GetAverageItemLevel(thisCharacter)
		-- end
		ldb.text = string.format('%s (%d)', ns.data.GetCharacterText(thisCharacter), levelInfo)
	end

	-- update tooltip, if shown
	if LibQTip:IsAcquired(addonName..'Characters') then
		OnCharactersLDBEnter()
	end
end
ns.RegisterEvent('PLAYER_LEVEL_UP', UpdateCharacters, 'characters')

-- ========================================================
--  Money
-- ========================================================
local moneyTooltip
local function OnMoneyLDBEnter(self)
	local numColumns = 2
	if LibStub('LibQTip-1.0'):IsAcquired(addonName..'Money') then
		moneyTooltip:Clear()
	else
		moneyTooltip = LibQTip:Acquire(addonName..'Money', numColumns,
			'LEFT', strsplit(',', string.rep('RIGHT,', numColumns-1)))
		moneyTooltip:SmartAnchorTo(self)
		moneyTooltip:SetAutoHideDelay(0.25, self)
		moneyTooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	local lineNum
	lineNum = moneyTooltip:AddHeader()
			  moneyTooltip:SetCell(lineNum, 1, addonName .. ': ' .. _G.MONEY, 'LEFT', numColumns)
	-- moneyTooltip:AddSeparator(2)

	local total
	for _, characterKey in ipairs(characters) do
		local amount = ns.data.GetMoney(characterKey)
		total = (total or 0) + amount

		lineNum = moneyTooltip:AddLine( ns.data.GetCharacterText(characterKey),
			GetCoinTextureString(amount)
		)
	end

	if total then
		moneyTooltip:AddSeparator(2)
		lineNum = moneyTooltip:AddLine(_G.TOTAL, GetCoinTextureString(total))
	end

	moneyTooltip:Show()
end

local sessionEarned = 0
local function UpdateMoney()
	local ldb = LDB:GetDataObjectByName(addonName..'Money')
	if ldb then
		ldb.text = GetCoinTextureString( GetMoney() )
	end

	-- update tooltip, if shown
	if LibQTip:IsAcquired(addonName..'Money') then
		OnMoneyLDBEnter()
	end
end
ns.RegisterEvent('PLAYER_MONEY', UpdateMoney, 'money')

-- ========================================================
--  Setup
-- ========================================================
ns.RegisterEvent('ADDON_LOADED', function(frame, event, arg1)
	if arg1 == addonName then
		-- fill character list
		characters = ns.data.GetCharacters(characters)

		LDB:NewDataObject(addonName..'Characters', {
			type	= 'data source',
			label	= _G.CHARACTER,
			-- icon    = 'Interface\\Icons\\Spell_Holy_EmpowerChampion',
			-- OnClick = OnLDBClick,
			OnEnter = OnCharactersLDBEnter,
			OnLeave = function() end,	-- needed for e.g. NinjaPanel
		})
		UpdateCharacters()

		LDB:NewDataObject(addonName..'Money', {
			type	= 'data source',
			label	= _G.MONEY,
			-- icon    = 'Interface\\Icons\\Spell_Holy_EmpowerChampion',
			-- OnClick = OnLDBClick,
			OnEnter = OnMoneyLDBEnter,
			OnLeave = function() end,	-- needed for e.g. NinjaPanel
		})
		UpdateMoney()

		ns.UnregisterEvent('ADDON_LOADED', 'general')
	end
end, 'general')
