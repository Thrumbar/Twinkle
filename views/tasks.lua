local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS:
-- GLOBALS:

local views = addon:GetModule('views')
local tasks = views:NewModule('tasks')
      tasks.icon = 'Interface\\Icons\\INV_Enchant_FormulaSuperior_01'
      tasks.title = 'Task List'

--[[
-- Possible tasks:
	- enchant gear
	- gem gear
	- craft item (gems, enchants, inscriptions, glyphs ...)
	- empty mail (expires warning)
	- tend mop farm

-- Possible Adventures:
	- daily dungeon
	- daily scenario
	- daily hc scenario
	- daily rnd pvp
	- daily pet battles
	- weekly valor/conquest cap
	- holiday pvp
	- complete achievements
--]]

function tasks:OnEnable()
	local panel = self.panel

	local panelLeft = panel:CreateTexture(nil, 'BACKGROUND')
	      panelLeft:SetTexture('Interface\\ACHIEVEMENTFRAME\\UI-ACHIEVEMENT-PARCHMENT')
	      panelLeft:SetTexCoord(0.5, 1, 0, 1)
	      panelLeft:SetPoint('TOPLEFT')
		  panelLeft:SetPoint('BOTTOMRIGHT', '$parent', 'BOTTOMRIGHT', -175, 0)
	local panelRight = panel:CreateTexture(nil, 'BACKGROUND')
	      panelRight:SetTexture('Interface\\ACHIEVEMENTFRAME\\UI-ACHIEVEMENT-PARCHMENT')
	      panelRight:SetTexCoord(0, 0.5, 0, 1)
	      panelRight:SetPoint('TOPLEFT', '$parent', 'TOPRIGHT', -175, 0)
		  panelRight:SetPoint('BOTTOMRIGHT')
	local separator = panel:CreateTexture(nil, 'BORDER')
	      separator:SetTexture('Interface\\Common\\bluemenu-vert')
	      separator:SetTexCoord(0.00781250, 0.04687500, 0, 1)
	      separator:SetVertTile(true)
	      separator:SetPoint('TOPLEFT', panelLeft, 'TOPRIGHT', -5, 0)
	      separator:SetPoint('BOTTOMRIGHT', panelLeft, 'BOTTOMRIGHT')
end

function tasks:OnDisable()
	--
end

function tasks:Update()
	local characterKey = addon.GetSelectedCharacter()
	local equipmentSets = DataStore:GetEquipmentSetNames(characterKey)
end
