local addonName, ns, _ = ...
local view = ns.CreateView("search")

function view.Init()
	local tab = ns.GetTab()
	tab:GetNormalTexture():SetTexture("Interface\\MINIMAP\\TRACKING\\None")
	tab.view = view

	local panel = CreateFrame("Frame") --, addonName.."PanelSearch")

	-- TODO: init

	view.panel = panel
	return panel
end

function view.Update()
	local panel = view.panel
	assert(panel, "Can't update panel before it's created")
	-- local character = ns.GetSelectedCharacter()
end
