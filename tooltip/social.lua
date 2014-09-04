local addonName, ns, _ = ...

local characters = ns.data.GetCharacters()

-- ================================================
--  Social (Friends / Ignores)
-- ================================================
local friendInfo = {}
local function GetFriendsInfo(unitName)
	if not DataStore:GetMethodOwner('GetContactInfo') then
		return friendInfo
	end

	wipe(friendInfo)
	for _, character in ipairs(characters) do
		-- might just as well be <nil, nil, "">
		local _, _, note = DataStore:GetContactInfo(character, unitName)
		if note then
			friendInfo[ character ] = note
			break
		end
	end
	return friendInfo
end

function ns.AddSocialInfo(self)
	local unitName = self:GetUnit()
	if IsIgnored(unitName) then
		local text = string.format(ERR_IGNORE_ALREADY_S, unitName)
		self:AddLine(text, 1, 0, 0, true)
	else
		local friends = GetFriendsInfo(unitName)
		local text
		for character, note in pairs(friends) do
			local char = ns.data.GetCharacterText(character)
			text = (text and text .. ', ' or '') .. char .. (note ~= '' and ' ('..note..')' or '')
		end
		if text then
			text = DECLENSION_SET:format(BATTLENET_FRIEND, text)
			self:AddLine(text, 0, 1, 0, true)
		end
	end
	self:Show()
end
