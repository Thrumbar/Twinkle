local addonName, ns, _ = ...
local view = ns.CreateView("tasks")

function view.Init()
	local tab = ns.GetTab()
	tab:GetNormalTexture():SetTexture('Interface\\Icons\\INV_Enchant_FormulaSuperior_01')
	tab.view = view

	local panel = CreateFrame('Frame') --, addonName.."PanelGrids") --]]

	-- TODO: init

	view.panel = panel
	return panel
end

function view.Update()
	local panel = view.panel
	assert(panel, "Can't update panel before it's created")

	local character = ns.GetSelectedCharacter()
end
