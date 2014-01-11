local addonName, ns, _ = ...

local characters = ns.data.GetCharacters()
local thisCharacter = ns.data.GetCurrentCharacter()

-- ================================================
--  Achievements
-- ================================================
local achievementInfo = {}
local achievementDone = {}
local function GetAchievementCompletionInfo(achievementID, onlyIncomplete)
	wipe(achievementInfo)
	wipe(achievementDone)

	local isShared
	for _, characterKey in ipairs(characters) do
		local progress, goal, isShared = DataStore:GetAchievementProgress(characterKey, achievementID)
		if characterKey ~= thisCharacter or isShared then
			if not progress or progress <= 0 then
				-- ignore
			elseif progress == goal then
				if not onlyIncomplete then
					-- data is pre-sorted
					table.insert(achievementDone, ns.data.GetCharacterText(characterKey))
				end
			else
				achievementInfo[characterKey] = goal == 0 and 0 or progress / goal
			end
		end

		-- check account achievements for only one character
		if isShared then break end
	end
	return achievementInfo, achievementDone, isShared
end

function ns.AddAchievementInfo(tooltip, achievementID)
	local onlyIncomplete = false

	local linesAdded, data = nil, nil
	local incomplete, complete, isShared = GetAchievementCompletionInfo(achievementID, onlyIncomplete)
	for _, characterKey in pairs(characters) do
		local progress = incomplete[characterKey]
		if progress then
			if isShared then
				data = string.format('%d%%', progress*100)
				break
			else
				local characterText = ns.data.GetCharacterText(characterKey)
				data = (data and data .. ', ' or '') .. string.format('%s (%d%%)', characterText, progress*100)
			end
		end
	end

	if not onlyIncomplete and #complete > 0 then
		if not linesAdded then ns.AddEmptyLine(tooltip) end
		tooltip:AddLine(string.format('%s: %s', _G.ACHIEVEMENTFRAME_FILTER_COMPLETED, table.concat(complete, ', ')), nil, nil, nil, true)
		linesAdded = (linesAdded or 0) + 1
	end
	if data then
		if not linesAdded then ns.AddEmptyLine(tooltip) end
		tooltip:AddLine(string.format('%s: %s', _G.ACHIEVEMENTFRAME_FILTER_INCOMPLETE, data), nil, nil, nil, true)
		linesAdded = (linesAdded or 0) + 1
	end

	return linesAdded
end
