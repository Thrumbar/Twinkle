local addonName, ns, _ = ...

-- GLOBALS: AUTOCOMPLETE_MAX_BUTTONS, AUTOCOMPLETE_SIMPLE_REGEX, AUTOCOMPLETE_SIMPLE_FORMAT_REGEX, AutoCompleteBox
-- GLOBALS: SendMailNameEditBox, GetAutoCompleteResults, AutoComplete_UpdateResults
-- GLOBALS: pairs, string, table, tContains, hooksecurefunc, strlen, unpack

-- ================================================
-- Autocomplete character names
-- ================================================
local function GetCleanName(text)
	if not text then return '' end
	text = string.gsub(text, "\124c%x%x%x%x%x%x%x%x", ""):gsub("\124r", "")
	-- text = text:match("\124c%x%x%x%x%x%x%x%x(.-)\124r") or text
	return text
end
local function SortNames(a, b)
	if a.priority ~= b.priority then
		return a.priority > b.priority
	else
		local nameA = GetCleanName(a.name)
		local nameB = GetCleanName(b.name)
		return nameA < nameB
		--[[ if (nameA ~= a and nameB ~= b) or (nameA == a and nameB == b) then
			return nameA < nameB
		else
			-- show our own characters first
			return nameA ~= a
		end --]]
	end
end

local characters, thisCharacter, lastQuery = ns.data.GetCharacters(), ns.data.GetCurrentCharacter(), nil
local function AddAltsToAutoComplete(parent, text, cursorPosition)
	if parent == SendMailNameEditBox and cursorPosition <= strlen(text) then
		-- possible flags can be found here: http://wow.go-hero.net/framexml/16650/AutoComplete.lua
		local include, exclude = parent.autoCompleteParams.include, parent.autoCompleteParams.exclude
		local newResults = GetAutoCompleteResults(text, include, exclude, AUTOCOMPLETE_MAX_BUTTONS+1, cursorPosition)
		for _, characterKey in pairs(characters) do
			if characterKey ~= thisCharacter then
				local character = ns.data.GetFullName(characterKey)
				if character:lower():find('^'..text:lower()) then
					local index
					for i, entry in pairs(newResults) do
						if entry.name and entry.name == character then
							index = i
							break
						end
					end

					-- /run for k, v in pairs(_G) do if k:find('LE_AUTOCOMPLETE_PRIORITY_') then print(k, v) end end
					character = ns.data.GetCharacterText(characterKey)
					if index then
						-- sometimes alts are on our flist/guild, color them nicely, too!
						newResults[index].name = character
						newResults[index].priority = LE_AUTOCOMPLETE_PRIORITY_FRIEND
					else
						table.insert(newResults, { name = character, priority = LE_AUTOCOMPLETE_PRIORITY_FRIEND })
					end
				end
			end
		end
		table.sort(newResults, SortNames)
		AutoComplete_UpdateResults(AutoCompleteBox, newResults)

		-- also write out the first match
		local currentText = parent:GetText()
		if newResults[1] and currentText ~= lastQuery then
			lastQuery = currentText
			local newText = string.gsub(currentText, parent.autoCompleteRegex or AUTOCOMPLETE_SIMPLE_REGEX,
				string.format(parent.autoCompleteFormatRegex or AUTOCOMPLETE_SIMPLE_FORMAT_REGEX, newResults[1].name,
				string.match(currentText, parent.autoCompleteRegex or AUTOCOMPLETE_SIMPLE_REGEX)),
				1)

			parent:SetText( GetCleanName(newText) )
			parent:HighlightText(strlen(currentText), strlen(newText))
			parent:SetCursorPosition(strlen(currentText))
		end
	end
end

local function CleanAutoCompleteOutput(self)
	local editBox = self:GetParent().parent
	if not editBox.addSpaceToAutoComplete then
		local newText = GetCleanName( editBox:GetText() )
		editBox:SetText(newText)
		editBox:SetCursorPosition(strlen(newText))
	end
end

ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 == addonName then
		hooksecurefunc('AutoComplete_Update', AddAltsToAutoComplete)
		-- hooksecurefunc('AutoCompleteButton_OnClick', CleanAutoCompleteOutput)
		for i = 1, AUTOCOMPLETE_MAX_BUTTONS do
			_G['AutoCompleteButton'..i]:HookScript('OnClick', CleanAutoCompleteOutput)
		end

		ns.UnregisterEvent('ADDON_LOADED', 'autocomplete')
	end
end, 'autocomplete')
