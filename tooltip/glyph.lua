local addonName, ns, _ = ...

-- FIXME: Several glyphs have the save name but are for different classes (e.g. Stampede)
-- GLOBALS: _G, DataStore, wipe, ipairs
local tinsert, tsort, tconcat = table.insert, table.sort, table.concat

local glyphKnown = {}
local glyphUnknown = {}
local function GetGlyphKnownInfo(glyph, onlyUnknown)
	wipe(glyphKnown)
	wipe(glyphUnknown)
	-- TODO: add level learnable info "Mychar (60)"
	for _, character in ipairs(ns.data.GetCharacters()) do
		local isKnown, canLearn = DataStore:IsGlyphKnown(character, glyph)
		if isKnown and not onlyUnknown then
			tinsert(glyphKnown, ns.data.GetCharacterText(character))
		elseif canLearn then
			tinsert(glyphUnknown, ns.data.GetCharacterText(character))
		end
	end
	-- glyphs only known/learnable for 1 class, so we can sort by |cxxxxxxxxName|r
	tsort(glyphKnown)
	tsort(glyphUnknown)
	return glyphKnown, glyphUnknown
end

-- <glyph: itemID | glyph name>
function ns.AddGlyphInfo(tooltip, glyph)
	local onlyUnknown = false -- TODO: config
	local linesAdded = false
	local known, unknown = GetGlyphKnownInfo(glyph, onlyUnknown)

	local list = not onlyUnknown and tconcat(known, ", ")
	if list and list ~= "" then
		tooltip:AddLine(_G.RED_FONT_COLOR_CODE.._G.ITEM_SPELL_KNOWN..": ".._G.FONT_COLOR_CODE_CLOSE..list, nil, nil, nil, true)
		linesAdded = true
	end
	list = tconcat(unknown, ", ")
	if list and list ~= "" then
		tooltip:AddLine(_G.GREEN_FONT_COLOR_CODE.._G.UNKNOWN..": ".._G.FONT_COLOR_CODE_CLOSE..list, nil, nil, nil, true)
		linesAdded = true
	end
	return linesAdded
end
