local addonName, addon, _ = ...

-- ================================================
--  Recipes
-- ================================================
local recipeKnownCharacters, recipeUnknownCharacters = {}, {}
local function SortByName(a, b)
	local nameA = a:gsub('|c........', ''):gsub('|r', '')
	local nameB = b:gsub('|c........', ''):gsub('|r', '')
	return nameA < nameB
end
local function SortBySkill(a, b)
	local skillA = a:match("%((.-)%)") or math.huge
	local skillB = b:match("%((.-)%)") or math.huge
	if skillA ~= skillB then
		return tonumber(skillA) > tonumber(skillB)
	else
		return SortByName(a, b)
	end
end
local function GetRecipeKnownInfo(craftedName, professionName, requiredSkill)
	local onlyUnknown = false -- TODO: config

	wipe(recipeKnownCharacters)
	wipe(recipeUnknownCharacters)

	local selfKnown = nil
	for _, character in ipairs(addon.data.GetCharacters()) do
		local _, _, rank, _, skillLine = addon.data.GetProfessionInfo(character, professionName)
		local isKnown = addon.data.IsRecipeKnown(character, craftedName, skillLine)
		if isKnown and character == thisCharacter then
			selfKnown = true
		end

		local charName = addon.data.GetCharacterText(character)
		if isKnown and not onlyUnknown then
			table.insert(recipeKnownCharacters, charName)
		elseif isKnown == false and rank > 0 then
			local characterText
			if not requiredSkill or rank >= requiredSkill then
				characterText = charName
			else
				characterText = string.format("%s %s(%d)|r", charName, RED_FONT_COLOR_CODE, rank)
			end
			--[[ local learnableColor = (not requiredSkill and HIGHLIGHT_FONT_COLOR_CODE)
				or (skillLevel >= requiredSkill and GREEN_FONT_COLOR_CODE)
				or RED_FONT_COLOR_CODE
			local characterText = string.format("%s %s(%d)|r", charName, learnableColor, rank) --]]
			table.insert(recipeUnknownCharacters, characterText)
		end
	end
	table.sort(recipeKnownCharacters, SortByName)
	table.sort(recipeUnknownCharacters, SortBySkill)
	return recipeKnownCharacters, recipeUnknownCharacters, selfKnown
end

function addon.AddCraftInfo(tooltip, professionName, craftedName, requiredSkill)
	local onlyUnknown = false -- TODO: config
	local linesAdded = false
	local known, unknown, selfKnown = GetRecipeKnownInfo(craftedName, professionName, requiredSkill)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		if selfKnown then
			-- don't show duplicate ITEM_SPELL_KNOWN line
			local line, text
			for lineNum = tooltip:NumLines(), 1, -1 do
				line = _G[tooltip:GetName().."TextLeft"..lineNum]
				text = line:GetText()
				if text and text == ITEM_SPELL_KNOWN then
					line:SetText(nil)
					break
				end
			end
		end

		tooltip:AddLine(RED_FONT_COLOR_CODE..ITEM_SPELL_KNOWN..": "..FONT_COLOR_CODE_CLOSE..list, 1, 1, 1, true)
		linesAdded = true
	end

	list = table.concat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(GREEN_FONT_COLOR_CODE..UNKNOWN..": "..FONT_COLOR_CODE_CLOSE..list, 1, 1, 1, true)
		linesAdded = true
	end
	return linesAdded
end
