local addonName, ns, _ = ...

local characters = ns.data.GetCharacters()

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
		local started, completed = DataStore:GetAchievementInfo(characterKey, achievementID)
		if not started then
			-- might be account bound achievement
			started = DataStore:GetAchievementInfo(characterKey, achievementID, true)
			isShared = true
		end

		if completed then
			if not onlyIncomplete then
				-- data is pre-sorted
				table.insert(achievementDone, ns.data.GetCharacterText(characterKey))
			end
		elseif started then
			-- local isShared = nil
			local achievementProgress = 0
			local achievementGoal = 0

			for index = 1, GetAchievementNumCriteria(achievementID) do
				local _, _, _, _, requiredQuantity = GetAchievementCriteriaInfo(achievementID, index)
				local critStarted, critCompleted, progress = DataStore:GetCriteriaInfo(characterKey, achievementID, index, isShared)
				-- if not critStarted and not isShared then
				-- 	critStarted, critCompleted, progress = DataStore:GetCriteriaInfo(characterKey, achievementID, index, true)
				-- 	isShared = critStarted
				-- end

				achievementProgress = achievementProgress + (critCompleted and requiredQuantity or progress or 0)
				achievementGoal     = achievementGoal + requiredQuantity
			end

			achievementInfo[characterKey] = achievementGoal == 0 and 0 or achievementProgress / achievementGoal
		end

		-- only check account achievements for one character
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
