local addonName, ns, _ = ...

-- ================================================
--  Currencies
-- ================================================
local currencyInfo = {}
local function GetCurrencyInfo(currencyID)
	wipe(currencyInfo)
	for _, character in ipairs(ns.data.GetCharacters()) do
		local isHeader, _, count, _ = ns.data.GetCurrencyInfo(character, currencyID)
		if count and count > 0 then -- and not isHeader and
			currencyInfo[character] = count
		end
	end
	return currencyInfo
end

function ns.AddCurrencyInfo(tooltip, currencyID)
	local showTotals = true -- TODO: config

	local linesAdded, overallCount = nil, 0
	local data = GetCurrencyInfo(currencyID)
	for _, characterKey in pairs(ns.data.GetCharacters()) do
		local count = data[characterKey]
		if count then
			local characterText = ns.data.GetCharacterText(characterKey)
			if overallCount == 0 then
				ns.AddEmptyLine(tooltip, true)
			end
			tooltip:AddDoubleLine(characterText, AbbreviateLargeNumbers(count))
			overallCount = overallCount + count
			linesAdded = (linesAdded or 0) + 1
		end
	end
	if showTotals and linesAdded and linesAdded > 1 then
		tooltip:AddDoubleLine(' ', string.format('%s: %s', TOTAL, AbbreviateLargeNumbers(overallCount)),
			nil, nil, nil, 1, 1, 1)
	end

	return linesAdded
end
