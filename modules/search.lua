local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: CreateFrame, PlaySound, EditBox_ClearFocus
-- GLOBALS: hooksecurefunc, pairs, type

local search = addon:NewModule('Search', 'AceEvent-3.0')
local searchResults, emptyTable = {}, {}
local characters

function search:OnEnable()
	-- views module is a requirement
	if not addon:GetModule('views', true) then
		self:Disable()
		return
	end

	characters = addon.data.GetCharacters()

	local searchDelay, lastUpdate = 0.25, 0
	local function SearchDelayed(self)
		local now = GetTime()
		if now >= lastUpdate + searchDelay then
			lastUpdate = now
			self:SetScript('OnUpdate', nil)
			search:Update()
		end
	end

	-- add search box to frame sidebar
	local frame = addon.frame
	local searchbox = CreateFrame('EditBox', '$parentSearchBox', frame.sidebar, 'SearchBoxTemplate')
	      searchbox:SetPoint('TOPLEFT', 9, -46)
	      searchbox:SetSize(160, 20)
	frame.search = searchbox

	searchbox.clearButton:HookScript('OnClick', searchbox.clearButton.Hide)
	searchbox:SetScript('OnEscapePressed', function(self) self.clearButton:Click() end)
	searchbox:SetScript('OnEnterPressed', EditBox_ClearFocus)
	searchbox:SetScript('OnTextChanged', function(self, isUserInput)
		InputBoxInstructions_OnTextChanged(self)
		if self:GetText() == self.searchString then return end
		if isUserInput then
			lastUpdate = GetTime()
			self:SetScript('OnUpdate', SearchDelayed)
		else
			search:Update()
		end
	end)

	self:RegisterMessage('TWINKLE_VIEW_CHANGED', self.UpdateSearch)
	self:RegisterMessage('TWINKLE_CHARACTER_CHANGED', self.UpdateSearch)
	self:RegisterMessage('TWINKLE_SEARCH_RESULTS')
	addon:AutoUpdateModule(self.moduleName)
end

function search:Clear()
	local editBox = addon.frame.search
	editBox.searchString = nil
	-- restore UI state
	addon:Update()
end

function search:UpdateSearch()
	local editBox = addon.frame.search
	if editBox.searchString then
		addon:SendMessage('TWINKLE_SEARCH_RESULTS', searchResults)
	end
end
function search:Update()
	local editBox = addon.frame.search
	local query   = editBox:GetText():trim()
	      query   = query ~= '' and query or nil

	if query == editBox.searchString then
		-- nothing has changed
	elseif not query then
		-- search terms were removed
		self:Clear()
		return
	else
		-- search terms have changed
		editBox.searchString = query

		for characterKey, resultCounts in pairs(searchResults) do
			wipe(resultCounts)
		end
		for viewName, view in addon:GetModule('views'):IterateModules() do
			if view.Search then
				-- also searching unloaded views
				if not view:IsEnabled() then view:Enable() end
				-- gather search results
				for _, characterKey in pairs(characters) do
					local numMatches = view:Search(query, characterKey)
					if (numMatches or 0) > 0 then
						searchResults[characterKey] = searchResults[characterKey] or {}
						searchResults[characterKey][viewName] = numMatches
					end
				end
			end
		end
		addon:SendMessage('TWINKLE_SEARCH_RESULTS', searchResults)
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
	return editBox and editBox.searchString
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
