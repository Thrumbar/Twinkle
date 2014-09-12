local addonName, addon, _ = ...

-- GLOBALS: _G
-- TODO: sort lockouts
-- TODO: SHIFT-click to post lockoutLink to chat
-- TODO: display defeated/available bosses OnEnter

local brokers = addon:GetModule('brokers')
local broker = brokers:NewModule('Lockouts')

local instanceLockouts = {}
local function GetCharacterInstanceLockouts(characterKey)
	local hasData = nil
	wipe(instanceLockouts)

	-- DataStore:IsEncounterDefeated()
	for lockoutID, lockoutLink in DataStore:IterateInstanceLockouts(characterKey) do
		hasData = true
		local instanceName, difficulty, reset, isExtended, isRaid, numDefeated, numBosses = DataStore:GetInstanceLockoutInfo(characterKey, lockoutID)
		local color = (reset == 0 and _G.GRAY_FONT_COLOR_CODE)
			or (numDefeated > 0 and _G.GREEN_FONT_COLOR_CODE)
			or _G.NORMAL_FONT_COLOR_CODE
		local rowText = string.format('%s%d/%d|r', color, numDefeated, numBosses)
		table.insert(instanceLockouts, rowText)
	end
	return hasData and instanceLockouts or nil
end

local function GetFlexLockouts(characterKey)
	local numDefeated, numBosses = 0, 0
	for instanceID, instanceName, status, reset, defeated, bosses in DataStore:IterateLFGs(characterKey, _G.TYPEID_DUNGEON, _G.LFG_SUBTYPEID_FLEXRAID) do
		numDefeated = numDefeated + (defeated or 0)
		numBosses   = numBosses + (bosses or 0)
	end
	return numDefeated, numBosses
end

local function GetInstanceLockouts(characterKey, difficulty, instanceName)
	local numDefeated, numBosses, hasID = 0, 0, nil
	for lockoutID, lockoutLink in DataStore:IterateInstanceLockouts(characterKey) do
		local name, diff, reset, _, _, defeated, bosses = DataStore:GetInstanceLockoutInfo(characterKey, lockoutID)
		if diff == difficulty and name == instanceName then
			numDefeated = numDefeated + defeated
			numBosses   = numBosses + bosses
			hasID       = reset ~= 0
		end
	end
	return numDefeated, numBosses, hasID
end

function broker:OnEnable()
	-- local currencyID, currencyQuantity, specificQuantity, specificLimit, overallQuantity, overallLimit, periodPurseQuantity, periodPurseLimit, purseQuantity, purseLimit, isWeekly = GetLFGDungeonRewardCapInfo(dungeonID)
	-- local dungeonName, typeID, subtypeID, minLvl, maxLvl, recLvl, minRecLvl, maxRecLvl, expansionId, groupId, textureFilename, difficulty, maxPlayers, dungeonDescription, isHoliday, bonusRepAmount, forceHide, _ = GetLFGDungeonInfo(dungeonID)
	-- local instances = GetLFRChoiceOrder()
	-- TYPEID_DUNGEON, LFG_SUBTYPEID_FLEXRAID
	--[[
	DataStore:GetLFGInfo("Default.Die Aldor.Thany", 730) => false, 1410310801, 3
	GetLFGDungeonInfo(730) => "Niedergang", 1, 5, 90, 90, 90, 90, 90, 4, 0, "ORGRIMMARDOWNFALL", 14, 25, "Mit der dunklen Macht, die unter Pandaria schlummerte, will Garrosh Azeroth einer neuen Ordnung unterwerfen. Haltet ihn auf!", false, 0, false, 7
	GetLFGDungeonRewardCapInfo(730) => TODO: check this on thany
	0, 1, 0, 1, 0, 1, 0, 0, 0, 0, true,
	"Immerseus", 1,
	"Die gefallenen Besch\195\188tzer", 1,
	"Norushen", 1,
	"Sha des Stolzes", 1,
	"Galakras", 1,
	"Eiserner Koloss", 1,
	"Dunkelschamanen der Kor'kron", 1,
	"General Nazgrim", 1,
	"Malkorok", 1,
	"Die Sch\195\164tze Pandarias", 1,
	"Thok der Blutr\195\188nstige", 1,
	"Belagerungsingenieur Ru\195\159schmied", 1,
	"Die Getreuen der Klaxxi", 1,
	"Garrosh H\195\182llschrei", 1
	--]]

	-- self:RegisterEvent('EVENT_NAME', self.Update, self)
	self:Update()
end
function broker:OnDisable()
	-- self:UnregisterEvent('EVENT_NAME')
end

function broker:OnClick(btn, down)
	-- do something, like show a UI
end

function broker:UpdateLDB()
	-- self.text = 'foo'
end

local function NOOP() end -- do nothing
function broker:UpdateTooltip()
	local numColumns = 4
	self:SetColumnLayout(numColumns, 'LEFT', 'RIGHT')

	local lineNum = self:AddHeader()
	self:SetCell(lineNum, 1, addonName .. ': ' .. _G.RAID, 'LEFT', numColumns)
	-- self:AddSeparator(2)

	-- _G.ERR_LOOT_GONE
	--[[ for _, characterKey in ipairs(brokers:GetCharacters()) do
		local data = GetCharacterInstanceLockouts(characterKey, true)
		if data then
			lineNum = self:AddLine(addon.data.GetCharacterText(characterKey),  unpack(data))
			self:SetLineScript(lineNum, 'OnEnter', NOOP) -- show highlight on row
		end
	end --]]

	self:AddSeparator(2)
	lineNum = self:AddHeader('Character', 'Flex', 'Normal', 'Heroic')
	lineNum = self:AddLine()
	for _, characterKey in ipairs(brokers:GetCharacters()) do
		self:SetCell(lineNum, 1, addon.data.GetCharacterText(characterKey))

		-- FIXME: MoP only has one flex instance group
		local flexDefeated, flexBosses = GetFlexLockouts(characterKey)
		local color = (flexDefeated > 0 and _G.GREEN_FONT_COLOR_CODE) or _G.NORMAL_FONT_COLOR_CODE
		self:SetCell(lineNum, 2, string.format('%s%d/%d|r', color, flexDefeated, flexBosses))

		-- FIXME: chinese have separate lockous
		local defeated10, defeated25, hasID
		defeated10, nBosses, locked = GetInstanceLockouts(characterKey, 3, 'Schlacht um Orgrimmar') -- 10 normal
		hasID = hasID or locked
		defeated25, _, locked = GetInstanceLockouts(characterKey, 4, 'Schlacht um Orgrimmar') -- 25 normal
		hasID = hasID or locked
		local nDefeated = math.max(defeated10, defeated25)
		local color = (not hasID and nDefeated > 0 and _G.GRAY_FONT_COLOR_CODE) or (nDefeated > 0 and _G.GREEN_FONT_COLOR_CODE) or _G.NORMAL_FONT_COLOR_CODE
		self:SetCell(lineNum, 3, string.format('%s%d/%d|r', color, nDefeated, nBosses))

		hasID = false
		defeated10, hcBosses, locked = GetInstanceLockouts(characterKey, 5, 'Schlacht um Orgrimmar') -- 10 heroic
		hasID = hasID or locked
		defeated25, _, locked = GetInstanceLockouts(characterKey, 6, 'Schlacht um Orgrimmar') -- 25 heroic
		hasID = hasID or locked
		local hcDefeated = math.max(defeated10, defeated25)
		local color = (not hasID and hcDefeated and _G.GRAY_FONT_COLOR_CODE) or (hcDefeated > 0 and _G.GREEN_FONT_COLOR_CODE) or _G.NORMAL_FONT_COLOR_CODE
		self:SetCell(lineNum, 4, string.format('%s%d/%d|r', color, hcDefeated, hcBosses))

		if flexDefeated ~= 0 or nDefeated ~= 0 or hcDefeated ~= 0 then
			-- when adding a character line, create new followup
			lineNum = self:AddLine()
		end
	end
	-- remove excess line
	for column = 1, numColumns do
		self:SetCell(lineNum, column, nil)
	end
end
