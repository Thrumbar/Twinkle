local addonName, addon, _ = ...
local plugin = addon:GetModule('Tooltip')

-- ================================================
--  Item counts
-- ================================================
local LOCATION_COUNT, SEPARATOR = '%s: %s%s|r', ', '
local locationLabels = { BAGSLOT, _G.BANK or 'Bank', VOID_STORAGE, AUCTIONS, BAG_FILTER_EQUIPMENT, MAIL_LABEL, REAGENT_BANK }
function addon.AddItemCounts(tooltip, itemID)
	-- TODO: use only one line if item is unique
	-- local _, _, _, _, _, _, _, maxStack = GetItemInfo(itemID)

	local linesAdded = false
	local overallCount, hasMultiple = 0, false
	local character = (plugin.db.global.itemCounts.onlyThisCharOnBOP and addon.IsItemBOP(itemID)) and addon.data.GetCurrentCharacter() or nil

	for _, characterKey in ipairs(addon.data.GetCharacters()) do
		if not character or characterKey == character then
			local baseCount, text = overallCount, nil
			for i, count in pairs(addon.data.GetItemCounts(characterKey, itemID)) do
				if count > 0 then
					if overallCount > 0 then hasMultiple = true end
					overallCount = overallCount + count
					text = (text and text..SEPARATOR or '') .. LOCATION_COUNT:format(locationLabels[i], GREEN_FONT_COLOR_CODE, AbbreviateLargeNumbers(count))
				end
			end

			if overallCount - baseCount > 0 then
				if not linesAdded then addon.AddEmptyLine(tooltip, true) end
				tooltip:AddDoubleLine(addon.data.GetCharacterText(characterKey), text)
				linesAdded = true
			end
		end
	end
	if plugin.db.global.itemCounts.showGuilds then
		for guild, count in pairs(addon.data.GetGuildsItemCounts(itemID)) do
			if overallCount > 0 and count > 0 then hasMultiple = true end
			if not linesAdded then addon.AddEmptyLine(tooltip, true) end
			tooltip:AddDoubleLine(guild , LOCATION_COUNT:format(GUILD_BANK, GREEN_FONT_COLOR_CODE, AbbreviateLargeNumbers(count)))
			linesAdded = true
			if plugin.db.global.itemCounts.includeGuildCountInTotal then
				overallCount = overallCount + count
			end
		end
	end
	if plugin.db.global.itemCounts.showTotals and hasMultiple then
		tooltip:AddDoubleLine(' ', LOCATION_COUNT:format(TOTAL, '', AbbreviateLargeNumbers(overallCount)), nil, nil, nil, 1, 1, 1)
		linesAdded = true
	end

	return linesAdded
end
