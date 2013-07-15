local addonName, ns, _ = ...
local view = {}

if not ns.views then ns.views = {} end
ns.views['default'] = view

function view.Init()
	local panel = CreateFrame("Frame")
	local text = panel:CreateFontString(nil, nil, "GameFontNormal")
		text:SetAllPoints(panel)
		text:SetWordWrap(true)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("MIDDLE")
		text:SetText('Hi and welcome!|nThere is more to come, oh my little stars')

	-- FIXME
	panel.Update = ns.Update
	view.panel = panel
end

function view.Update(panel)
	local currentCharacter = ns.GetSelectedCharacter()
	print('update default view', character)
end

function view.Show(...)
	if not view.panel then
		view.Init()
	end
	view.Update()
end

--[[-- gold colored horizontal line:
local line = frame:CreateTexture()
line:SetTexture(0.74, 0.52, 0.06)
line:SetSize(339, 1)
--]]
