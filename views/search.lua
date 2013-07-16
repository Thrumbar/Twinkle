local addonName, ns, _ = ...
local view = {}

if not ns.views then ns.views = {} end
ns.views['search'] = view

function view.Init()
	local panel = CreateFrame("Frame", addonName.."PanelSearch")

	-- FIXME
	panel.Update = view.Update
	view.panel = panel
end

function view.Update(panel)
end

function view.Show(...)
	if not view.panel then
		view.Init()
	end
	view.Update()
end
