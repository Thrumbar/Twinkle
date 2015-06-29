local addonName, addon, _ = ...

-- ================================================
--  Quests
-- ================================================
local questInfo = {}
-- TODO: return list of characters that completed quest, too
local function GetOnQuestInfo(questID, onlyActive)
	wipe(questInfo)
	for _, characterKey in ipairs(addon.data.GetCharacters()) do
		local characterName = addon.data.GetCharacterText(characterKey)
		local progress = addon.data.GetQuestProgress(characterKey, questID)
		if progress then
			if progress == 0 then
				table.insert(questInfo, characterName)
			else
				local text = string.format('%s (%d%%)', characterName, progress*100)
				table.insert(questInfo, text)
			end
		end
	end
	return questInfo
end

function addon.AddOnQuestInfo(tooltip, questID)
	local linesAdded = nil
	local onlyActive = false -- TODO: config
	local questInfo = GetOnQuestInfo(questID, onlyActive)
	if #questInfo > 0 then
		-- QUEST_COMPLETE: "Quest abgeschlossen"
		-- ERR_QUEST_ACCEPTED_S: "Quest angenommen: ..."
		local text = string.format(ERR_QUEST_ACCEPTED_S, table.concat(questInfo, ", "))
		addon.AddEmptyLine(tooltip, true)
		tooltip:AddLine(text, nil, nil, nil, true)
		linesAdded = true
	end
	return linesAdded
end
