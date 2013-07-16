local addonName, ns, _ = ...
local view = ns.CreateView("containers")

local function GetSlotButton(bag, button)
	-- body
end

function view.Init()
	local tab = ns.GetTab()
	tab:GetNormalTexture():SetTexture("Interface\\Buttons\\Button-Backpack-Up")
	tab.view = view

	local panel = CreateFrame("Frame", addonName.."PanelContainers")
	-- TODO: init stuff

	-- FIXME
	panel.Update = view.Update
	panel.view = view
	view.panel = panel
end

function view.Update(panel)
	local character = ns.GetSelectedCharacter()
	local panel = view.panel
	assert(view.panel, "Can't update panel before it's created")
	local panelName = panel:GetName()
	-- ns.data.GetContainerSlotInfo(character, bag, slot)
end
