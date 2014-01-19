local addonName, ns, _ = ...

-- GLOBALS: _G, AUTOCOMPLETE_MAX_BUTTONS, AUTOCOMPLETE_SIMPLE_REGEX, AUTOCOMPLETE_SIMPLE_FORMAT_REGEX, AutoCompleteBox, LE_AUTOCOMPLETE_PRIORITY_GUILD
-- GLOBALS: SendMailNameEditBox, GetAutoCompleteResults, AutoComplete_UpdateResults, Ambiguate, RGBTableToColorCode, GetNumGuildMembers, GetGuildRosterInfo, GetNumClasses, GetClassInfo
-- GLOBALS: pairs, string, table, tContains, hooksecurefunc, strlen, unpack, tonumber

-- ================================================
-- Autocomplete character names
-- ================================================
local LE_AUTOCOMPLETE_PRIORITY_ALTS = 6 -- totally random, just shouldn't collide with Blizzard. value is used for sorting

local function GetGuildMemberClass(character)
	for index = 1, (GetNumGuildMembers()) do
		local fullName, _, _, _, _, _, _, _, _, _, unitClass = GetGuildRosterInfo(index)
		if fullName == character then
			for classIndex = 1, GetNumClasses() do
				local className, classTag, classID = GetClassInfo(classIndex)
				if classTag == unitClass then
					return className, classTag, classID
				end
			end
		end
	end
end

local function SortSuggestions(a, b)
	if math.floor(a.priority) == math.floor(b.priority) then
		return a.name < b.name
	else
		return a.priority > b.priority
	end
end

local firstSuggestion, blizzSuggestion, lastText
local function AddHighlightedText(editBox, text)
	-- local suggestion = blizzSuggestion and Ambiguate(blizzSuggestion.name, editBox.autoCompleteContext or "all")
	if lastText and lastText == text then
		firstSuggestion = nil
	elseif editBox:GetText() == text and firstSuggestion and not firstSuggestion:find('^'..text) then
		firstSuggestion = nil
	end
	if firstSuggestion then
		lastText = text
		editBox:SetText(firstSuggestion)
		editBox:HighlightText(strlen(text), strlen(firstSuggestion))
		editBox:SetCursorPosition(strlen(text))
	end
end

local characters, thisCharacter = ns.data.GetCharacters(), ns.data.GetCurrentCharacter(), nil
local function AddAltsToAutoComplete(parent, text, cursorPosition)
	if not parent or not parent.autoCompleteParams or text == '' then return end
	-- possible flags can be found here: http://wow.go-hero.net/framexml/16650/AutoComplete.lua
	local include, exclude = parent.autoCompleteParams.include, parent.autoCompleteParams.exclude
	local newResults = GetAutoCompleteResults(text, include, exclude, AUTOCOMPLETE_MAX_BUTTONS+1, cursorPosition)
	blizzSuggestion = newResults[1]

	if parent == SendMailNameEditBox and cursorPosition <= strlen(text) then
		-- add suitable alts to autocomplete
		for _, characterKey in pairs(characters) do
			if characterKey ~= thisCharacter then
				local characterName, characterFullName = ns.data.GetName(characterKey), ns.data.GetFullName(characterKey)
				if characterName:lower():find('^'..text:lower()) then
					local index
					-- check if this character is already on our list
					for i, entry in pairs(newResults) do
						if entry.name and entry.name == characterFullName then
							index = i
							break
						end
					end

					local _, _, classID = ns.data.GetClass(characterKey)
					if not index then
						index = #newResults + 1
						newResults[index] = {}
					end
					local priority = tonumber(string.format('%d.%.2d', LE_AUTOCOMPLETE_PRIORITY_ALTS, classID))
					-- Ambiguate(characterFullName, parent.autoCompleteContext or 'all')
					newResults[index].name     = characterFullName
					newResults[index].priority = priority
				end
			end
		end
	end

	-- color guild members by class
	for index, suggestion in pairs(newResults) do
		if suggestion.priority == LE_AUTOCOMPLETE_PRIORITY_GUILD then
			local _, _, classID = GetGuildMemberClass(suggestion.name)
			if classID then
				newResults[index].priority = tonumber(string.format('%d.%.2d', LE_AUTOCOMPLETE_PRIORITY_GUILD, classID))
			end
		end
	end

	table.sort(newResults, SortSuggestions)

	AutoComplete_UpdateResults(AutoCompleteBox, newResults)
	-- prepare output of first match
	firstSuggestion = nil
	if newResults[1] and (not blizzSuggestion or blizzSuggestion.name ~= newResults[1].name) then
		local name = Ambiguate(newResults[1].name, parent.autoCompleteContext or "all")
		local newText = string.gsub(text, AUTOCOMPLETE_SIMPLE_REGEX,
			string.format(AUTOCOMPLETE_SIMPLE_FORMAT_REGEX, name,
			string.match(text, AUTOCOMPLETE_SIMPLE_REGEX)),
			1)
		firstSuggestion = newText

		if not blizzSuggestion then
			AddHighlightedText(parent, text)
		end
	end
end

-- UnitIsGroupLeader(unit, LE_PARTY_HOME) local leader = '|TInterface\\GroupFrame\\UI-Group-LeaderIcon:0|t'
-- local contact = '|TInterface\\FriendsFrame\\UI-Toast-FriendOnlineIcon:0|t' -- PlusManz-PlusManz, UI-Toast-FriendRequestIcon, UI-Toast-ToastIcons
-- Battlenet-Battleneticon, Battlenet-WoWicon
local alt   = '\124TInterface\\COMMON\\ReputationStar:10:10:0:0:32:32:0:16:0:16\124t'
local guild = ''
ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 == addonName then
		local your_character = string.gsub(_G.UNIT_YOU_SOURCE, _G.CHARACTER, '%%s')
		for index = 1, GetNumClasses() do
			local priority
			local className, classTag, classID = GetClassInfo(index)

			-- class coloring for alts
			priority = tonumber(string.format('%d.%.2d', LE_AUTOCOMPLETE_PRIORITY_ALTS, classID))
			_G.AUTOCOMPLETE_COLOR_KEYS[priority] = {
				key  = alt .. RGBTableToColorCode(_G.RAID_CLASS_COLORS[classTag]),
				text = string.format(your_character, className),
			}

			-- class coloring for guild members
			priority = tonumber(string.format('%d.%.2d', LE_AUTOCOMPLETE_PRIORITY_GUILD, classID))
			_G.AUTOCOMPLETE_COLOR_KEYS[priority] = {
				key  = guild .. RGBTableToColorCode(_G.RAID_CLASS_COLORS[classTag]),
				text = _G.AUTOCOMPLETE_COLOR_KEYS[LE_AUTOCOMPLETE_PRIORITY_GUILD].text,
			}
		end
		hooksecurefunc('AutoComplete_Update', AddAltsToAutoComplete)

		-- overwrite whatever completions blizzard has supplied before
		hooksecurefunc("AutoCompleteEditBox_AddHighlightedText", AddHighlightedText)

		ns.UnregisterEvent('ADDON_LOADED', 'autocomplete')
	end
end, 'autocomplete')
