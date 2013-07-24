local addonName, ns, _ = ...
local search = {}
ns.search = search

-- GLOBALS: TwinkleUI, DataStore, NUM_BAG_SLOTS, SlashCmdList, _G, SEARCH
-- GLOBALS: OptionsList_ClearSelection, GetItemInfo
-- GLOBALS: string, table, pairs, ipairs, wipe, select, type, tonumber, print

local ItemSearch = LibStub('LibItemSearch-1.2')

local searchResults = {}
--[[ Table structure: TODO: itemID => counts, actual location (slot, row/col, ...), itemLink
searchResults = {
	<itemLink> = {
		<<character>|<location>> = <count>,
		... },
	...
} --]]
local resultLocations = {
	VOID_STORAGE,
	MINIMAP_TRACKING_BANKER,
	KEYRING,
	INVTYPE_BAG,
	INVENTORY_TOOLTIP, -- ITEMSLOTTEXT
	MAIL_LABEL,
	TRADE_SKILLS,
}

-- used as fallback if no data returned
local empty = {}
local characters = ns.data.GetCharacters()

function search.Update(self)
	local oldText, text = self.searchString, self:GetText()
	if not text or text == "" or text == SEARCH then
		self.searchString = nil
	else
		self.searchString = string.lower(text)
	end

	if not self.searchString or oldText == self.searchString then
		search.Reset(self)
		return
	end

	local view = ns.GetCurrentView()
	if view and view.name ~= "search" and view.Search then
		view.Search(self.searchString)
	else
		local scrollFrame = _G[addonName.."UI"].sidebar.scrollFrame
		OptionsList_ClearSelection(scrollFrame, scrollFrame.buttons)
		ns.DisplayPanel("search")

		wipe(searchResults)
		for i, characterKey in ipairs(characters) do
			local numMatches = search.Search(self.searchString, characterKey)

			local button = TwinkleUI.sidebar.scrollFrame.buttons[i]
			if button then
				if numMatches > 0 then
					button:SetAlpha(1)
					button.info:SetFormattedText("(%d)", numMatches)
				else
					button:SetAlpha(0.4)
					button.info:SetText("")
				end
			end
		end

		if view and view.Update then
			view.Update()
		end
	end
end

function search.GetResults()
	return searchResults
end

function search.Reset(self)
	if self.searchString then
		ns.UpdateSidebar()
		return
	end

	local view = ns.GetCurrentView()
	if view and view.name ~= "search" and view.Search then
		ns.Update()
	else
		ns.DisplayPanel("default")
	end
end

function search.Search(searchString, characterKey)
	local location, numMatches = nil, 0
	local itemLink, itemID, spellID, count, _
	local containers = DataStore:GetContainers(characterKey)
	for containerName, container in pairs(containers or empty) do
		location = (containerName == "VoidStorage" and 1) or (containerName == "Bag100" and 2) or (containerName == "Bag-2" and 3)
		if not location then
			local bagIndex = tonumber(containerName:match("%d+") or "")
			location = (bagIndex and bagIndex <= NUM_BAG_SLOTS and 4) or 3
		end

		location = string.format("%s|%s", characterKey, resultLocations[location])

		for slot = 1, container.size do
			itemID, itemLink, count = DataStore:GetSlotInfo(container, slot)
			itemLink = itemLink or (itemID and select(2, GetItemInfo(itemID)))
			count = count or 1
			if itemID and ItemSearch:Matches(itemLink, searchString) then
				if not searchResults[itemID] then
					searchResults[itemID] = {}
				elseif searchResults[itemID][location] then
					count = searchResults[itemID][location] + count
				end
				searchResults[itemID][location] = count
				numMatches = numMatches + 1
			end
		end
	end

	location = string.format("%s|%s", characterKey, resultLocations[5])
	local inventory = DataStore:GetInventory(characterKey)
	for _, item in pairs(inventory or empty) do
		itemLink = (item and type(item) == "string") and item or (item and select(2, GetItemInfo(item)))
		itemID = ns.GetLinkID(itemLink)
		count = 1
		if itemID and ItemSearch:Matches(itemLink, searchString) then
			if not searchResults[itemID] then
				searchResults[itemID] = {}
			elseif searchResults[itemID][location] then
				count = searchResults[itemID][location] + count
			end
			searchResults[itemID][location] = count
			numMatches = numMatches + 1
		end
	end

	location = string.format("%s|%s", characterKey, resultLocations[6])
	local mails = DataStore:GetNumMails(characterKey)
	for i = 1, mails or 0 do
		_, _, itemLink = DataStore:GetMailInfo(characterKey, i)
		itemID = ns.GetLinkID(itemLink)
		count = 1
		if itemID and ItemSearch:Matches(itemLink, searchString) then
			if not searchResults[itemID] then
				searchResults[itemID] = {}
			elseif searchResults[itemID][location] then
				count = searchResults[itemID][location] + count
			end
			searchResults[itemID][location] = count
			numMatches = numMatches + 1
		end
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

	return numMatches
end
