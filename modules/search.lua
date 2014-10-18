local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: CreateFrame, PlaySound, EditBox_ClearFocus
-- GLOBALS: hooksecurefunc, pairs, type

local search = addon:NewModule('Search', 'AceEvent-3.0')
local characters

local function SearchCurrentView(event, ...)
	local views = addon:GetModule('views')
	local view  = views:GetActiveView()
	local characterKey = addon:GetSelectedCharacter()
	local searchString = addon:GetSearch()

	if not searchString or not view.Search then return end
	view:Search(searchString, characterKey)
end

function search:OnEnable()
	characters = addon.data.GetCharacters()

	-- add search box to frame sidebar
	local frame = addon.frame
	local searchbox = CreateFrame('EditBox', '$parentSearchBox', frame.sidebar, 'SearchBoxTemplate')
	      searchbox:SetPoint('BOTTOM', 4, 2)
	      searchbox:SetSize(160, 20)
	searchbox.clearFunc = function() self:Clear() end
	searchbox:SetScript('OnTextChanged', function(self, userInput)
		if self:GetText() == self.searchString or not userInput then return end
		search:Update()
	end)
	searchbox:SetScript('OnEscapePressed', function(self) self.clearButton:Click() end)
	searchbox:SetScript('OnEnterPressed', EditBox_ClearFocus)
	frame.search = searchbox

	-- slightly reposition sidebar scrollFrame
	frame.sidebar.scrollFrame:SetPoint('BOTTOMRIGHT', searchbox, 'TOPRIGHT', -22, 0)

	self:RegisterMessage('TWINKLE_VIEW_CHANGED', SearchCurrentView)
	self:RegisterMessage('TWINKLE_CHARACTER_CHANGED', SearchCurrentView)
end

function search:Clear()
	local views = addon:GetModule('views', true)
	if not views then return end

	for name, view in views:IterateModules() do
		local icon = view.tab:GetNormalTexture()
		icon:SetDesaturated(false)
		icon:SetAlpha(1)
	end

	addon.frame.search.searchString = nil
	addon:UpdateCharacters()
	addon:Update()
end

local searchResults = {}
function search:Update()
	local editBox = addon.frame.search
	local newText = editBox:GetText()
	if newText == '' or newText == _G.SEARCH then
		editBox:clearFunc()
		newText = nil
	end

	editBox.searchString = newText
	local views = addon:GetModule('views', true)
	if not views then return end

	wipe(searchResults)
	for viewName, view in views:IterateModules() do
		if view.Search then
			if not view:IsEnabled() then view:Enable() end
			local numResults = 0
			if newText then
				-- gather search results
				for _, characterKey in pairs(characters) do
					local numMatches = view:Search(newText, characterKey)
					if numMatches and type(numMatches) == 'number' and numMatches > 0 then
						numResults = numResults + numMatches
						searchResults[characterKey] = (searchResults[characterKey] or 0) + numMatches
					end
				end
			elseif view == views:GetActiveView() then
				-- reset search
				view:Update()
			end

			-- update tab highlight
			local icon = view.tab:GetNormalTexture()
			if numResults > 0 or not newText then
				icon:SetDesaturated(false)
				icon:SetAlpha(1)
			else
				icon:SetDesaturated(true)
				icon:SetAlpha(0.5)
			end
		end
	end

	-- add result counter/indicator
	for index, button in pairs(addon.frame.sidebar.scrollFrame.buttons) do
		local numResults = searchResults[button.element]
		if numResults and numResults > 0 then
			button.info:SetText('('..numResults..')')
		else
			button.info:SetText('')
		end
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
