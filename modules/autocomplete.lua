local addonName, addon, _ = ...

-- GLOBALS: _G, AUTOCOMPLETE_MAX_BUTTONS, AUTOCOMPLETE_SIMPLE_REGEX, AUTOCOMPLETE_SIMPLE_FORMAT_REGEX, AutoCompleteBox, LE_AUTOCOMPLETE_PRIORITY_GUILD, LE_AUTOCOMPLETE_PRIORITY_ACCOUNT_CHARACTER, LE_AUTOCOMPLETE_PRIORITY_ACCOUNT_CHARACTER_SAME_REALM
-- GLOBALS: SendMailNameEditBox, GetAutoCompleteResults, AutoComplete_UpdateResults, Ambiguate, RGBTableToColorCode, GetNumGuildMembers, GetGuildRosterInfo, GetNumClasses, GetClassInfo
-- GLOBALS: pairs, string, table, tContains, hooksecurefunc, strlen, unpack, tonumber

local autocomplete = addon:NewModule('autocomplete')
local floor = math.floor
local characters, thisCharacter

-- ================================================
-- Autocomplete character names
-- ================================================
local function GetGuildCharacterInfo(name)
	for index = 1, (GetNumGuildMembers()) do
		local fullName, _, _, _, _, _, _, _, _, _, unitClass = GetGuildRosterInfo(index)
		if fullName == name then
			for classIndex = 1, GetNumClasses() do
				local className, classTag, classID = GetClassInfo(classIndex)
				if classTag == unitClass then
					return name, fullName, classID
				end
			end
		end
	end
end

local function GetAccountCharacterInfo(name)
	for _, characterKey in pairs(characters) do
		local characterName = addon.data.GetName(characterKey)
		if characterName == name then
			local characterFullName = addon.data.GetFullName(characterKey)
			local _, _, classID = addon.data.GetClass(characterKey)
			return characterName, characterFullName, classID
		end
	end
end

local function SortSuggestions(a, b)
	if floor(a.priority) == floor(b.priority) then
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

local function AddAltsToAutoComplete(parent, text, cursorPosition)
	if text == '' or not parent or not parent.autoCompleteParams or #parent.autoCompleteParams < 2 then return end
	-- @see https://www.townlong-yak.com/framexml/live/AutoComplete.lua
	local newResults = GetAutoCompleteResults(text, AUTOCOMPLETE_MAX_BUTTONS+1, cursorPosition, unpack(parent.autoCompleteParams))
	blizzSuggestion = newResults[1]

	for index, suggestion in pairs(newResults) do
		-- color guild members by class
		if suggestion.priority == LE_AUTOCOMPLETE_PRIORITY_GUILD then
			local characterName, fullName, classID = GetGuildCharacterInfo(suggestion.name)
			if classID then
				newResults[index].priority = tonumber(string.format('%d.%.2d', LE_AUTOCOMPLETE_PRIORITY_GUILD, classID))
			end
		-- color own known characters by class
		elseif suggestion.priority == LE_AUTOCOMPLETE_PRIORITY_ACCOUNT_CHARACTER
			or suggestion.priority == LE_AUTOCOMPLETE_PRIORITY_ACCOUNT_CHARACTER_SAME_REALM then
			local characterName, characterFullName, classID = GetAccountCharacterInfo(suggestion.name)
			if classID then
				newResults[index].priority = tonumber(string.format('%d.%.2d', suggestion.priority, classID))
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
local alt   = '\124TInterface\\COMMON\\ReputationStar:10:10:0:0:32:32:0:16:0:16\124t '
local guild = ''
function autocomplete:OnEnable()
	characters = addon.data.GetAllCharacters()
	thisCharacter = addon.data.GetCurrentCharacter()

	local yourCharacter = string.gsub(_G.UNIT_YOU_SOURCE, _G.CHARACTER, '%%s')
	for index = 1, GetNumClasses() do
		local priority
		local className, classTag, classID = GetClassInfo(index)

		-- class coloring for alts
		priority = tonumber(string.format('%d.%.2d', LE_AUTOCOMPLETE_PRIORITY_ACCOUNT_CHARACTER, classID))
		_G.AUTOCOMPLETE_COLOR_KEYS[priority] = {
			key  = alt .. RGBTableToColorCode(_G.RAID_CLASS_COLORS[classTag]),
			text = string.format(yourCharacter, className),
		}

		-- class coloring for alts on this realm
		priority = tonumber(string.format('%d.%.2d', LE_AUTOCOMPLETE_PRIORITY_ACCOUNT_CHARACTER_SAME_REALM, classID))
		_G.AUTOCOMPLETE_COLOR_KEYS[priority] = {
			key  = alt .. RGBTableToColorCode(_G.RAID_CLASS_COLORS[classTag]),
			text = string.format(yourCharacter, className),
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
end
