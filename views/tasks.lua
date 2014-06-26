local addonName, ns, _ = ...
local view = ns.CreateView("tasks")
view.icon = 'Interface\\Icons\\INV_Enchant_FormulaSuperior_01'

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

function view.Init()
	-- local tab = ns.GetTab()
	-- tab:GetNormalTexture():SetTexture('Interface\\Icons\\INV_Enchant_FormulaSuperior_01')
	-- tab.view = view

	-- local panel = CreateFrame('Frame') --, addonName.."PanelGrids") --]]
	local panel = view.panel

	-- TODO: init

	view.panel = panel
	return panel
end

function view.Update()
	local panel = view.panel
	assert(panel, "Can't update panel before it's created")

	local character = ns.GetSelectedCharacter()
end
