local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: CreateFrame, EditBox_ClearFocus
-- GLOBALS: hooksecurefunc, pairs, type

local views  = addon:GetModule('views')
local search = addon:NewModule('Search', 'AceEvent-3.0')
local searchResults, emptyTable = {}, {}
local currentSearch

function search:Initialize()
	-- add search box to frame sidebar
	local frame = addon.frame
	local searchDelay, lastUpdate = 0.25, 0
	local function SearchDelayed(self)
		local now = GetTime()
		if now >= lastUpdate + searchDelay then
			lastUpdate = now
			self:SetScript('OnUpdate', nil)
			search:Update()
		end
	end

	local searchBox = CreateFrame('EditBox', '$parentSearchBox', frame.sidebar, 'SearchBoxTemplate')
	      searchBox:SetPoint('TOPLEFT', 9, -46)
	      searchBox:SetSize(160, 20)
	frame.search = searchBox

	searchBox.tiptext = nil -- TODO
	searchBox:SetScript('OnEnter', addon.ShowTooltip)
	searchBox:SetScript('OnLeave', addon.HideTooltip)
	searchBox.clearButton:HookScript('OnClick', searchBox.clearButton.Hide)
	searchBox:SetScript('OnEscapePressed', function(self) self.clearButton:Click() end)
	searchBox:SetScript('OnEnterPressed', EditBox_ClearFocus)
	searchBox:SetScript('OnTextChanged', function(self, isUserInput)
		InputBoxInstructions_OnTextChanged(self)
		local query = self:GetText():trim()
		      query = query ~= '' and query or nil
		if query == currentSearch then return end
		if not isUserInput then
			search:Update()
		else
			lastUpdate = GetTime()
			self:SetScript('OnUpdate', SearchDelayed)
		end
	end)
end

function search:OnEnable()
	self:RegisterMessage('TWINKLE_VIEW_CHANGED', self.UpdateSearch)
	self:RegisterMessage('TWINKLE_CHARACTER_CHANGED', self.UpdateSearch)
	self:RegisterMessage('TWINKLE_SEARCH_RESULTS')
	addon:AutoUpdateModule(self.moduleName)
end

function search:UpdateSearch()
	--[[if not addon.frame then return end
	if not addon.frame.search then
		self:Initialize()
	end--]]

	local editBox = addon.frame.search
	if currentSearch then
		addon:SendMessage('TWINKLE_SEARCH_RESULTS', searchResults)
	end
end

function search:Update()
	--if not addon.frame or not addon.frame.search then return end
	if not addon.frame then return end
	if not addon.frame.search then
		self:Initialize()
	end

	local editBox = addon.frame.search
	local query = editBox:GetText():trim()
	      query = query ~= '' and query or nil

	if query == currentSearch then
		-- nothing has changed
	else
		currentSearch = query
		for characterKey, resultCounts in pairs(searchResults) do
			wipe(resultCounts)
		end

		if not query then
			-- search terms were removed, restore UI state
			addon:Update()
		else
			-- search terms have changed
			for _, plugin in addon:IterateModules() do
				if plugin.Search then plugin:Search(query, searchResults) end
			end
			addon:SendMessage('TWINKLE_SEARCH_RESULTS', searchResults)
		end
	end
end

function search:TWINKLE_SEARCH_RESULTS(event, searchResults)
	-- update character result counters
	for _, button in ipairs(addon.frame.sidebar.scrollFrame) do
		local numResults = 0
		for viewName, resultCount in pairs(searchResults[button.element] or emptyTable) do
			numResults = numResults + resultCount
		end
		button.info:SetText(numResults > 0 and '('..numResults..')' or nil)
	end
end

-- extend the base addon
function addon:GetSearch()
	local editBox = addon.frame.search
	return editBox and currentSearch
end

--[[
location = string.format("%s|%s", characterKey, resultLocations[7])
for professionName, profession in pairs(DataStore:GetProfessions(characterKey) or empty) do
	for index = 1, DataStore:GetNumCraftLines(profession) do
		_, _, spellID = DataStore:GetCraftLineInfo(profession, index)
		itemID = spellID and DataStore:GetCraftInfo(spellID)
		itemLink = itemID and select(2, GetItemInfo(itemID))

		if itemLink and ItemSearch:Matches(itemLink, searchString) then
			spellID = -1 * (ns.GetLinkID( GetSpellLink(spellID) )

			if not searchResults[itemID] then
				searchResults[itemID] = {}
			elseif searchResults[itemID][location] then
				spellID = searchResults[characterKey][itemID][location] .. ","..spellID
			end
			searchResults[itemID][location] = spellID
			numMatches = numMatches + 1
		end
	end
end
--]]
