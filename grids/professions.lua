local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math

local views = addon:GetModule('views')
local grids = views:GetModule('grids')
local professions = grids:NewModule('professions', 'AceEvent-3.0')
      professions.icon = 'Interface\\Icons\\70_professions_scroll_02'
      professions.title = 'Professions'


local skillLineMappings = {
	-- primary crafting
	{ skillLine = 171, spellID =  2259}, -- 'Alchemy',
	{ skillLine = 164, spellID =  2018}, -- 'Blacksmithing',
	{ skillLine = 333, spellID =  7411}, -- 'Enchanting',
	{ skillLine = 202, spellID =  4036}, -- 'Engineering',
	{ skillLine = 773, spellID = 45357}, -- 'Inscription',
	{ skillLine = 755, spellID = 25229}, -- 'Jewelcrafting',
	{ skillLine = 165, spellID =  2108}, -- 'Leatherworking',
	{ skillLine = 197, spellID =  3908}, -- 'Tailoring',
	-- primary gathering
	{ skillLine = 182, spellID =  2366}, -- 'Herbalism',
	{ skillLine = 186, spellID =  2575}, -- 'Mining',
	{ skillLine = 393, spellID =  8613}, -- 'Skinning',
	-- secondary
	{ skillLine = 794, spellID = 78670}, -- 'Archaeology',
	{ skillLine = 185, spellID =  2550}, -- 'Cooking',
	{ skillLine = 129, spellID =  3273}, -- 'First Aid',
	{ skillLine = 356, spellID =  7620}, -- 'Fishing',
}

function professions:OnEnable()
	self:RegisterEvent('SKILL_LINES_CHANGED', 'Update')
end
function professions:OnDisable()
	self:UnregisterEvent('SKILL_LINES_CHANGED')
end

function professions:GetNumColumns()
	return #skillLineMappings
end

function professions:GetColumnInfo(index)
	local profession = skillLineMappings[index]
	local name, _, icon = GetSpellInfo(profession.spellID)

	local text = string.format('|T%s:0|t', icon)
	local link = GetSpellLink(profession.spellID)
	local tooltipText, justify = nil, nil

	return text, link, tooltipText, justify
end

function professions:GetCellInfo(characterKey, index)
	local profession = skillLineMappings[index]
	local text, link, tooltipText, justify = '-', nil, nil, 'CENTER'

	local name, icon, rank, maxRank, skillLine, spellID, specSpellID = addon.data.GetProfessionInfo(characterKey, profession.skillLine)
	if name then
		local currExpMax = PROFESSION_RANKS[#PROFESSION_RANKS][1]
		local prevExpMax = PROFESSION_RANKS[#PROFESSION_RANKS - 1][1]
		if rank >= currExpMax then
			-- Maxed out for this expansion.
			text = addon.ColorizeText(rank, rank, rank)
		elseif rank >= prevExpMax then
			-- Still leveling for this expansion.
			text = addon.ColorizeText(rank, rank - prevExpMax, currExpMax - prevExpMax)
		else
			-- Horribly outdated.
			text = addon.ColorizeText(rank, 0)
		end
		link = GetSpellLink(specSpellID or spellID)

		justify = 'RIGHT'
	end

	return text, link, tooltipText, justify
end

function professions:OnCellClick(characterKey, index, frame, btn, up)
	local profession = skillLineMappings[index]

	local name, icon, rank, maxRank, skillLine, spellID, specSpellID = addon.data.GetProfessionInfo(characterKey, profession.skillLine)

	-- @todo Add wrapper API.
	local link = DataStore:GetProfessionTradeLink(characterKey, skillLine)
	if link and not IsModifiedClick() then
		-- link = link:match("\124H(.-)\124")
		-- SetItemRef(link)
	end
	return link
end
