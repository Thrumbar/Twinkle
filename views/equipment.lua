local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: CreateFrame, IsModifiedClick, HandleModifiedItemClick, GetItemIcon, GetInventorySlotInfo
-- GLOBALS: ipairs

local views = addon:GetModule('views')
local equipment = views:NewModule('equipment')
      equipment.icon = 'Interface\\Icons\\Achievement_Arena_2v2_6' -- Achievement_Arena_3v3_6
      -- equipment.title = 'Equipment'

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
local function OnItemClick(self, btn, up)
	if IsModifiedClick() and self.link then
		HandleModifiedItemClick(self.link)
	end
end
local function SetSlotItem(slotID, itemLink)
	local slotButton
	for index, button in ipairs(equipment.panel) do
		if button:GetID() == slotID then
			slotButton = button
			break
		end
	end
	if not slotButton then return end

	if not itemLink then
		slotButton.icon:SetTexture(slotButton.emptyIcon)
		slotButton.link = nil
	else
		local itemIcon = GetItemIcon(itemLink)
		slotButton.icon:SetTexture(itemIcon)
		slotButton.link = itemLink
	end
end

-- TODO: have DataMore store equipment sets & display those
-- TODO: display item info, i.e. gems, enchants, item level, quality
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
			slotButton:SetPoint('TOPLEFT', panel[1], 'TOPRIGHT', 4, 0)
		elseif index == 17 then
			-- main hand
			slotButton:SetPoint('TOPLEFT', panel[8], 'BOTTOMLEFT', 0, -12)
		elseif index == 18 then
			-- off hand
			slotButton:SetPoint('TOPLEFT', panel[16], 'BOTTOMLEFT', 0, -12)
		else
			slotButton:SetPoint('TOPLEFT', panel[index-1], 'BOTTOMLEFT', 0, -4)
		end
	end
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
