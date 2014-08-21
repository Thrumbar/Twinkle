local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: CreateFrame, PlaySound, EditBox_ClearFocus
-- GLOBALS: hooksecurefunc, pairs, type

local search = addon:NewModule('Search')

function search:OnEnable()
	-- add search box to frame sidebar
	local frame = addon.frame
	local searchbox = CreateFrame('EditBox', '$parentSearchBox', frame.sidebar, 'SearchBoxTemplate')
	      searchbox:SetPoint('BOTTOM', 4, 2)
	      searchbox:SetSize(160, 20)
	searchbox.clearFunc = function() self:Clear() end
	-- TODO: add a slight delay when typing quickly
	searchbox:SetScript('OnTextChanged', function() self:Update() end)
	searchbox:SetScript('OnEscapePressed', function(self) self.clearButton:Click() end)
	searchbox:SetScript('OnEnterPressed', EditBox_ClearFocus)
	frame.search = searchbox

	-- slightly reposition sidebar scrollFrame
	frame.sidebar.scrollFrame:SetPoint('BOTTOMRIGHT', searchbox, 'TOPRIGHT', -22, 0)

	-- make sure all views are always up to date & filtered properly
	local function OnViewUpdate()
		search.updating = true
		search:Update(true) -- forced update
		search.updating = nil
	end
	local views = addon:GetModule('views', true)
	if views then
		-- hook into existing views
		for name, view in views:IterateModules() do
			hooksecurefunc(view, 'Update', OnViewUpdate)
		end
		-- also, mind future views!
		hooksecurefunc(views, 'NewModule', function(viewName)
			hooksecurefunc(views:GetModule(viewName), 'Update', OnViewUpdate)
		end)
	end
end

function search:Clear()
	local views = addon:GetModule('views', true)
	if views then
		for name, view in views:IterateModules() do
			local icon = view.tab:GetNormalTexture()
			icon:SetDesaturated(false)
			icon:SetAlpha(1)
		end
	end

	addon:UpdateCharacters()
	if not self.updating then
		addon:Update()
	end
end

function search:Update(forced)
	local editBox = addon.frame.search
	local oldText, newText = editBox.searchString, editBox:GetText()
	if newText == oldText and not forced then
		return
	elseif newText == '' or newText == _G.SEARCH then
		editBox:clearFunc()
		return
	else
		editBox.searchString = newText
	end

	local views = addon:GetModule('views', true)
	if views then
		-- desaturate all tabs, so we can highlight them later
		for name, view in views:IterateModules() do
			local icon = view.tab:GetNormalTexture()
			icon:SetDesaturated(true)
			icon:SetAlpha(0.5)
		end

		-- TODO: FIXME: this will not return results for characters outside our scroll range
		local scrollFrame = addon.frame.sidebar.scrollFrame
		for index, button in pairs(scrollFrame.buttons) do
			local numResults = 0
			-- ask views for their search results
			for name, view in views:IterateModules() do
				if view.Search then
					-- TODO: replace this with plain :Update() and let modules react to search?
					local numMatches = view:Search(editBox.searchString, button.element)
					if numMatches and type(numMatches) == 'number' and numMatches > 0 then
						numResults = numResults + numMatches
						local icon = view.tab:GetNormalTexture()
						icon:SetDesaturated(false)
						icon:SetAlpha(1)
					end
				end
			end

			if numResults > 0 then
				button.info:SetFormattedText('(%d)', numResults)
			else
				button.info:SetText('')
			end
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
