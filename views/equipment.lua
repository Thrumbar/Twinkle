local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: LoadAddOn, CreateFrame, IsModifiedClick, HandleModifiedItemClick, GetItemIcon, GetInventorySlotInfo, GetItemInfo, GetItemStats, GetItemGem, SetDesaturation
-- GLOBALS: ipairs, pairs, wipe

local views = addon:GetModule('views')
local equipment = views:NewModule('equipment', 'AceTimer-3.0')
      equipment.icon = 'Interface\\Icons\\Achievement_Arena_2v2_6' -- Achievement_Arena_3v3_6
      -- equipment.title = 'Equipment'

local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')

-- skull: Achievement_BG_killingblow_30
-- chest armor: INV_Chest_Plate16
-- helm (token): Achievement_Dungeon_Outland_Dungeon_Hero
-- filled chest: Trade_Archaeology_ChestofTinyGlassAnimals

local slotInfo = {
	-- left aligned
	'HeadSlot', 	-- 1 	_G.INVSLOT_HEAD
	'NeckSlot', 	-- 2 	_G.INVSLOT_NECK
	'ShoulderSlot', -- 3 	_G.INVSLOT_SHOULDER
	'BackSlot', 	-- 15 	_G.INVSLOT_BACK
	'ChestSlot', 	-- 5 	_G.INVSLOT_CHEST
	'ShirtSlot', 	-- 4 	_G.INVSLOT_BODY
	'TabardSlot', 	-- 19 	_G.INVSLOT_TABARD
	'WristSlot', 	-- 9 	_G.INVSLOT_WRIST
	-- right aligned
	'HandsSlot', 	-- 10	_G.INVSLOT_HAND
	'WaistSlot', 	-- 6	_G.INVSLOT_WAIST
	'LegsSlot', 	-- 7	_G.INVSLOT_LEGS
	'FeetSlot', 	-- 8	_G.INVSLOT_FEET
	'Finger0Slot', 	-- 11	_G.INVSLOT_FINGER1
	'Finger1Slot', 	-- 12	_G.INVSLOT_FINGER2
	'Trinket0Slot', -- 13	_G.INVSLOT_TRINKET1
	'Trinket1Slot', -- 14	_G.INVSLOT_TRINKET2
	-- bottom aligned
	'MainHandSlot', 	 -- 16	_G.INVSLOT_MAINHAND
	'SecondaryHandSlot', -- 17	_G.INVSLOT_OFFHAND
}

local gemColorNames = {
	['EMPTY_SOCKET_RED']		= 'Red',
	['EMPTY_SOCKET_BLUE']		= 'Blue',
	['EMPTY_SOCKET_YELLOW']		= 'Yellow',
	['EMPTY_SOCKET_HYDRAULIC']	= 'Hydraulic',
	['EMPTY_SOCKET_COGWHEEL']	= 'Cogwheel',
	['EMPTY_SOCKET_META']		= 'Meta',
	['EMPTY_SOCKET_PRISMATIC']	= 'Prismatic',
	['EMPTY_SOCKET_NO_COLOR']	= 'Prismatic',
}

local function OnItemClick(self, btn, up)
	if IsModifiedClick() and self.link then
		HandleModifiedItemClick(self.link)
	end
end

local function SetSocketInfo(socket, socketColor, socketGem)
	local gemInfo = _G.GEM_TYPE_INFO[socketColor]
	if socketColor == 'Meta' or socketColor == 'Prismatic' then
		SetDesaturation(socket.bg, 1)
	else
		SetDesaturation(socket.bg, nil)
	end
	socket.bg:SetTexture(gemInfo.tex)
	socket.bg:SetTexCoord(gemInfo.left, gemInfo.right, gemInfo.top, gemInfo.bottom)

	if socketGem then
		-- socket is filled
		socket.link = socketGem
		socket.fill:SetTexture( GetItemIcon(socketGem) )
		socket.fill:Show()
	else
		-- socket is empty
		socket.link = nil
		socket.fill:Hide()
	end
end

local itemStats = {}
local function SetSlotItem(slotID, itemLink)
	local slotButton
	for index, button in ipairs(equipment.panel) do
		if button:GetID() == slotID then
			slotButton = button
			break
		end
	end
	if not slotButton then return end

	-- hide sockets, will be shown later if necessary
	for gemIndex = 1, _G.MAX_NUM_SOCKETS do
		slotButton[gemIndex]:Hide()
	end

	if not itemLink then
		slotButton.icon:SetTexture(slotButton.emptyIcon)
		slotButton.link = nil
		slotButton.level:SetText('')
		slotButton.upgrade:SetText('')
	else
		local itemIcon = GetItemIcon(itemLink)
		slotButton.icon:SetTexture(itemIcon)
		slotButton.link = itemLink

		-- item level & quality
		local _, _, quality, itemLevel = GetItemInfo(itemLink)
		if not quality then
			equipment:ScheduleTimer(SetSlotItem, 0.1, slotID, itemLink)
			return
		end
		local qualityColor = _G.ITEM_QUALITY_COLORS[quality]
		slotButton.level:SetText(itemLevel)
		slotButton.level:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)

		-- item upgrades
		local upgraded, maxUpgrade, iLvlDelta = LibItemUpgrade:GetItemUpgradeInfo(itemLink)
		if not upgraded or maxUpgrade == 0 then
			slotButton.upgrade:SetText('')
		else
			slotButton.upgrade:SetText('*')
			local color = (upgraded == 0 and _G.RED_FONT_COLOR)
				or (upgraded ~= maxUpgrade and _G.YELLOW_FONT_COLOR)
				or _G.GREEN_FONT_COLOR
			slotButton.upgrade:SetTextColor(color.r, color.g, color.b)
		end

		-- sockets
		wipe(itemStats)
		itemStats = GetItemStats(itemLink, itemStats)

		local gemIndex = 1
		-- display available sockets
		for statName, amount in pairs(itemStats) do
			local dataColor = gemColorNames[statName]
			if dataColor then
				-- item has socket(s)
				for i = 1, amount do
					local _, gemLink = GetItemGem(itemLink, gemIndex)
					SetSocketInfo(slotButton[gemIndex], dataColor, gemLink)
					slotButton[gemIndex]:Show()
					gemIndex = gemIndex + 1
				end
			end
		end

		-- there might be additional sockets
		for gemIndex = 1, _G.MAX_NUM_SOCKETS do
			local _, gemLink = GetItemGem(itemLink, gemIndex)
			if gemLink then
				if not slotButton[gemIndex]:IsShown() then
					-- additional gem found
					SetSocketInfo(slotButton[gemIndex], 'Prismatic', gemLink)
					slotButton[gemIndex]:Show()
				end
			end
		end
	end
end

-- TODO: have DataMore store equipment sets & display those
-- TODO: display more item info: enchant, reforge
function equipment.OnEnable(self)
	local panel = self.panel

	for index, slotName in ipairs(slotInfo) do
		local slotID, texture = GetInventorySlotInfo(slotName)
		local slotButton = CreateFrame('Button', '$parentSlot'..slotID, panel, 'ItemButtonTemplate', slotID)
		      slotButton.emptyIcon = texture
		      slotButton.icon:SetTexture(texture)
		panel[index] = slotButton

		slotButton:SetScript('OnEnter', addon.ShowTooltip)
		slotButton:SetScript('OnLeave', addon.HideTooltip)
		slotButton:SetScript('OnClick', OnItemClick)

		if index == 1 then
			-- left column
			slotButton:SetPoint('TOPLEFT', 10, -10)
		elseif index == 9 then
			-- right column
			slotButton:SetPoint('TOPLEFT', panel[1], 'TOPRIGHT', 64, 0)
		elseif index == 17 then
			-- main hand
			slotButton:SetPoint('TOPLEFT', panel[8], 'BOTTOMLEFT', 0, -12)
		elseif index == 18 then
			-- off hand
			slotButton:SetPoint('TOPLEFT', panel[16], 'BOTTOMLEFT', 0, -12)
		else
			slotButton:SetPoint('TOPLEFT', panel[index-1], 'BOTTOMLEFT', 0, -4)
		end

		-- item level
		local level = slotButton:CreateFontString(nil, nil, 'NumberFontNormal')
		      level:SetPoint('TOPLEFT', '$parent', 'TOPRIGHT', 4, 0)
		slotButton.level = level

		-- item upgrades
		slotButton.upgrade = _G[slotButton:GetName()..'Stock']
		slotButton.upgrade:SetText('')
		slotButton.upgrade:Show()

		-- item sockets
		for socketIndex = 1, _G.MAX_NUM_SOCKETS do
			local socket = CreateFrame('Frame', nil, slotButton)
				  socket:SetSize(16, 16)
				  socket:SetScript('OnEnter', addon.ShowTooltip)
				  socket:SetScript('OnLeave', addon.HideTooltip)
				  socket:SetScript('OnMouseDown', OnItemClick)
				  socket:Hide()
			slotButton[socketIndex] = socket

			local bg = socket:CreateTexture(nil, 'BACKGROUND')
				  bg:SetAllPoints()
			socket.bg = bg
			local fill = socket:CreateTexture(nil, 'ARTWORK')
				  fill:SetPoint('CENTER', socket, 'CENTER')
				  fill:SetSize(13, 13)
				  fill:Hide()
			socket.fill = fill

			if socketIndex == 1 then
				socket:SetPoint('TOPLEFT', slotButton.level, 'BOTTOMLEFT', 0, -4)
			else
				socket:SetPoint('TOPLEFT', slotButton[socketIndex - 1], 'TOPRIGHT', 2, 0)
			end
		end
	end

	-- we need access to gem info
	LoadAddOn('Blizzard_ItemSocketingUI')
end

function equipment.OnDisable()
	--
end

function equipment.Update()
	local characterKey = addon.GetSelectedCharacter()
	for slotID = _G.INVSLOT_FIRST_EQUIPPED, _G.INVSLOT_LAST_EQUIPPED do
		local itemLink = addon.data.GetInventoryItemLink(characterKey, slotID)
		SetSlotItem(slotID, itemLink)
	end
end
