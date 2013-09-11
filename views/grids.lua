local addonName, ns, _ = ...
local view = ns.CreateView("grids")

function view.Init()
	local tab = ns.GetTab()
	tab:GetNormalTexture():SetTexture("INTERFACE\\ICONS\\Ability_Ensnare")
	tab.view = view

	local panel = CreateFrame("Frame") --, addonName.."PanelGrids") --]]

	-- TODO: init

	view.panel = panel
	return panel
end

function view.Update()
	local panel = view.panel
	assert(panel, "Can't update panel before it's created")
	-- local character = ns.GetSelectedCharacter()
end
