local addonName, ns, _ = ...
local view = ns.CreateView("grids")
view.icon = "INTERFACE\\ICONS\\Ability_Ensnare"

local LibItemUpgrade = LibStub("LibItemUpgradeInfo-1.0")
local LibReforging   = LibStub("LibReforgingInfo-1.0")

local function OnClick(self, btn, up)
	if not self.itemLink then return end
	HandleModifiedItemClick(self.itemLink)
end

function view.Init()
	-- local tab = ns.GetTab()
	-- tab:GetNormalTexture():SetTexture("INTERFACE\\ICONS\\Ability_Ensnare")
	-- tab.view = view

	-- local panel = CreateFrame('Frame', addonName..'PanelGrids')
	local panel = view.panel

	-- TODO: init

	local container = CreateFrame('Frame', '$parentGrid', panel)
	      container:SetPoint('TOPLEFT', 10, -36)
	      container:SetPoint('BOTTOMRIGHT', -10, -40)
	for row = 1, 11 do
		for column = 1, 11 do
			local slotButton = CreateFrame('Button', ('$parentRow%dCol%d'):format(row, column), container, 'ItemButtonTemplate')
			      slotButton:SetScale(0.8)
			      slotButton:SetScript('OnEnter', ns.ShowTooltip)
			      slotButton:SetScript('OnLeave', ns.HideTooltip)
			      slotButton:SetScript('OnClick', OnClick)

			if column == 1 and row == 1 then
				slotButton:SetPoint('TOPLEFT', 0, 0)
			elseif column == 1 then
				slotButton:SetPoint('TOPLEFT', ('$parentRow%dCol%d'):format(row-1, 1), 'BOTTOMLEFT', 0, -2)
			else
				slotButton:SetPoint('TOPLEFT', ('$parentRow%dCol%d'):format(row, column-1), 'TOPRIGHT', 4, 0)
			end
		end
	end

	view.panel = panel
	return panel
end

function view.Update()
	local panel = view.panel
	assert(panel, "Can't update panel before it's created")

	local character = ns.GetSelectedCharacter()

	for row = 1, 11 do
		for column = 1, INVSLOT_LAST_EQUIPPED - INVSLOT_FIRST_EQUIPPED do
			local slotButton = ('%sRow%dCol%d'):format(panel:GetName(), row, column)
		end
	end
end
