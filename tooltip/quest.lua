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
		-- if characterKey ~= ns.data.GetCurrentCharacter() then
			local numActiveQuests = DataStore:GetQuestLogSize(characterKey) or 0
			for i = 1, numActiveQuests do
				local isHeader, questLink, _, _, completed = DataStore:GetQuestLogInfo(characterKey, i)
				local qID = questLink and ns.GetLinkID(questLink)

				if not isHeader and qID == questID and completed ~= 1 then
					local progress = DataStore:GetQuestProgressPercentage(characterKey, questID) or 0
					local characterName = ns.data.GetCharacterText(characterKey)
					if progress == 0 then
						table.insert(questInfo, characterName)
					else
						local text = string.format('%s (%d%%)', characterName, progress*100)
						table.insert(questInfo, text)
					end
					break
				end
			end
		-- end
	end

	-- ERR_QUEST_PUSH_ACCEPTED_S = "%1$s hat Eure Quest angenommen."
	-- ERR_QUEST_PUSH_ALREADY_DONE_S = "%s hat die Quest abgeschlossen"
	-- QUEST_COMPLETE = "Quest abgeschlossen"

	return questInfo
end

function ns.AddOnQuestInfo(tooltip, questID)
	local linesAdded = nil
	local onlyActive = false -- TODO: config
	local questInfo = GetOnQuestInfo(questID, onlyActive)
	if #questInfo > 0 then
		-- QUEST_TOOLTIP_ACTIVE: "Ihr befindet Euch auf dieser Quest."
		-- ERR_QUEST_ACCEPTED_S: "Quest angenommen: ..."
		-- ERR_QUEST_PUSH_ONQUEST_S: "... hat diese Quest bereits"
		local text = string.format(ERR_QUEST_ACCEPTED_S, table.concat(questInfo, ", "))
		ns.AddEmptyLine(tooltip, true)
		tooltip:AddLine(text, nil, nil, nil, true)
		linesAdded = true
	end
	return linesAdded
end
