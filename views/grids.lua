local addonName, ns, _ = ...
local view = ns.CreateView("grids")

local LibItemUpgrade = LibStub("LibItemUpgradeInfo-1.0")
local LibReforging = LibStub("LibReforgingInfo-1.0")

function view.Init()
	local tab = ns.GetTab()
	tab:GetNormalTexture():SetTexture("INTERFACE\\ICONS\\Ability_Ensnare")
	tab.view = view

	local panel = CreateFrame("Frame") --, addonName.."PanelGrids") --]]

	-- TODO: init

	panel.slots = {}
	for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local info = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			  info:SetJustifyH("LEFT")
		if panel.slots[slotID - 1] then
			info:SetPoint("TOPLEFT", panel.slots[slotID - 1], "BOTTOMLEFT", 0, -2)
		else
			info:SetPoint("TOPLEFT")
		end
		panel.slots[slotID] = info
	end


	view.panel = panel
	return panel
end

local stats = {}
local reforgingStats = {
	"ITEM_MOD_SPIRIT_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT"
}

function view.Update()
	local panel = view.panel
	assert(panel, "Can't update panel before it's created")

	local character = ns.GetSelectedCharacter()

	for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local itemLink = ns.data.GetInventoryItemLink(character, slotID)
		if itemLink then
			local upgradeID = LibItemUpgrade:GetUpgradeID(itemLink)
			local currentUpgrade = LibItemUpgrade:GetCurrentUpgrade(upgradeID) or 0
			local maxUpgrade = LibItemUpgrade:GetMaximumUpgrade(upgradeID) or 0
			local itemLevel = LibItemUpgrade:GetUpgradedItemLevel(itemLink) or 0

			local reforgeID = LibReforging:GetReforgeID(itemLink)
			local reforged = ''
			if reforgeID then
				wipe(stats)
				stats = GetItemStats(itemLink, stats)
				local from = LibReforging:GetReforgedStatIDs(reforgeID)
				local statValue = stats and math.floor((stats[ reforgingStats[from] ] or 0) * 0.4) or 0
				local from, to = LibReforging:GetReforgedStatNames(reforgeID)
				reforged = string.format("%d %s => %s", statValue, from, to)
			end

			local color = ''
			if currentUpgrade == maxUpgrade then
				if currentUpgrade == 0 then
					color = GRAY_FONT_COLOR_CODE
				else
					color = GREEN_FONT_COLOR_CODE
				end
			elseif currentUpgrade == 0 then
				color = RED_FONT_COLOR_CODE
			else
				color = YELLOW_FONT_COLOR_CODE
			end

			panel.slots[slotID]:SetFormattedText("%d (%s%d/%d|r)    %s", itemLevel, color, currentUpgrade, maxUpgrade, reforged)
		else
			panel.slots[slotID]:SetText('')
		end
	end
end
