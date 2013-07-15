local addonName, ns, _ = ...
local data = {}
ns.data = data

function data.GetCharacters(useTable)
	wipe(useTable)
	for characterName, characterKey in pairs(DataStore:GetCharacters()) do
		table.insert(useTable, characterKey)
	end
	table.sort(useTable)
end

function data.GetCurrentCharacter()
	return DataStore:GetCharacter()
end

function data.GetCharacterText(characterKey)
	local text
	if IsAddOnLoaded('DataStore_Characters') then
		local faction = DataStore:GetCharacterFaction(characterKey)
		if faction == "Horde" then
			text = '|TInterface\\WorldStateFrame\\HordeIcon.png:22|t '
		elseif faction == "Alliance" then
			text = '|TInterface\\WorldStateFrame\\AllianceIcon.png:22|t '
		else
			text = '|TInterface\\WorldStateFrame\\BothIcon.png:22|t '
		end

		text = text .. (DataStore:GetColoredCharacterName(characterKey) or '') .. '|r'
	else
		local _, _, characterName = strsplit('.', characterKey)
		text = characterName
	end
	return text
end
