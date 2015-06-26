local addonName, ns, _ = ...

-- ================================================
--  Quests
-- ================================================
local questInfo = {}
-- TODO: abstract to ns.data
-- TODO: return list of characters that completed quest, too
local function GetOnQuestInfo(questID, onlyActive)
	wipe(questInfo)
	for _, characterKey in ipairs(ns.data.GetCharacters()) do
		local hasQuest, progress = DataStore:GetQuestProgress(characterKey, questID)
		local characterName = ns.data.GetCharacterText(characterKey)
		if hasQuest then
			if progress == 0 then
				table.insert(questInfo, characterName)
			else
				local text = string.format('%s (%d%%)', characterName, progress*100)
				table.insert(questInfo, text)
			end
		else
			for i = 1, DataStore:GetQuestLogSize(characterKey) or 0 do
				local isHeader, questLink, _, _, completed = DataStore:GetQuestLogInfo(characterKey, i)
				local qID = questLink and ns.GetLinkID(questLink)
				if not isHeader and qID == questID and completed ~= 1 then
					table.insert(questInfo, characterName)
					break
				end
			end
		end
	end
	return questInfo
end

function ns.AddOnQuestInfo(tooltip, questID)
	local linesAdded = nil
	local onlyActive = false -- TODO: config
	local questInfo = GetOnQuestInfo(questID, onlyActive)
	if #questInfo > 0 then
		-- QUEST_COMPLETE: "Quest abgeschlossen"
		-- ERR_QUEST_ACCEPTED_S: "Quest angenommen: ..."
		local text = string.format(ERR_QUEST_ACCEPTED_S, table.concat(questInfo, ", "))
		ns.AddEmptyLine(tooltip, true)
		tooltip:AddLine(text, nil, nil, nil, true)
		linesAdded = true
	end
	return linesAdded
end
