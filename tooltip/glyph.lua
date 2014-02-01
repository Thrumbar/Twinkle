local addonName, ns, _ = ...
-- FIXME: Several glyphs have the save name but are for different classes (e.g. Stampede)
local characters = ns.data.GetCharacters()

-- ================================================
--  Glyphs
-- ================================================
local glyphKnown = {}
local glyphUnknown = {}
local function GetGlyphKnownInfo(glyph, onlyUnknown)
	wipe(glyphKnown)
	wipe(glyphUnknown)
	-- TODO: add level learnable info "Mychar (60)"
	for _, character in ipairs(characters) do
		local isKnown, canLearn = DataStore:IsGlyphKnown(character, glyph)
		if isKnown and not onlyUnknown then
			table.insert(glyphKnown, ns.data.GetCharacterText(character))
		elseif canLearn then
			table.insert(glyphUnknown, ns.data.GetCharacterText(character))
		end
	end
	-- glyphs only known/lernable for 1 class, so wie can sort by |cxxxxxxxxName|r
	table.sort(glyphKnown)
	table.sort(glyphUnknown)
	return glyphKnown, glyphUnknown
end

-- <glyph: itemID | glyph name>
function ns.AddGlyphInfo(tooltip, glyph)
	local onlyUnknown = false -- TODO: config
	local linesAdded = false
	local known, unknown = GetGlyphKnownInfo(glyph, onlyUnknown)

	local list = not onlyUnknown and table.concat(known, ", ")
	if list and list ~= "" then
		tooltip:AddLine(RED_FONT_COLOR_CODE..ITEM_SPELL_KNOWN..": "..FONT_COLOR_CODE_CLOSE..list, nil, nil, nil, true)
		linesAdded = true
	end
	list = table.concat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(GREEN_FONT_COLOR_CODE..UNKNOWN..": "..FONT_COLOR_CODE_CLOSE..list, nil, nil, nil, true)
		linesAdded = true
	end
	return linesAdded
end
