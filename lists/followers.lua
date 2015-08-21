local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS: ipairs, tonumber, math
-- TODO: group followers: working, active, inactive

local _, class = UnitClass('player')
local views    = addon:GetModule('views')
local lists    = views:GetModule('lists')
local plugin   = lists:NewModule('Followers', 'AceEvent-3.0')
      plugin.icon = 'Interface\\Icons\\Achievement_WorldEvent_Brewmaster'
      -- 'Interface\\Icons\\ACHIEVEMENT_GUILDPERK_EVERYONES A HERO_RANK2'
      plugin.title = _G.GARRISON_FOLLOWERS_TITLE
      plugin.excludeItemSearch = true

local mechanics = {}
function plugin:OnEnable()
	for _, mechanic in pairs(C_Garrison.GetAllEncounterThreats(LE_FOLLOWER_TYPE_GARRISON_6_0)) do
		mechanics[mechanic.id] = true
	end
	for _, mechanic in pairs(C_Garrison.GetAllEncounterThreats(LE_FOLLOWER_TYPE_SHIPYARD_6_2)) do
		mechanics[mechanic.id] = true
	end

	-- self:RegisterEvent('USE_GLYPH', 'Update')
end
function plugin:OnDisable()
	-- self:UnregisterEvent('USE_GLYPH')
end

local character, followers = nil, {}
local function SortFollowers(a, b)
	local aType, bType = C_Garrison.GetFollowerTypeByID(a), C_Garrison.GetFollowerTypeByID(b)
	local aInactive = select(14, addon.data.GetFollowerInfo(character, a))
	local bInactive = select(14, addon.data.GetFollowerInfo(character, b))
	if aType ~= bType then
		return aType > bType
	elseif aInactive ~= bInactive then
		return not aInactive
	else
		return C_Garrison.GetFollowerNameByID(a) < C_Garrison.GetFollowerNameByID(b)
	end
end
function plugin:GetNumRows(characterKey)
	local numFollowers = addon.data.GetNumFollowers(characterKey)
	if characterKey ~= character then
		wipe(followers)
		character = characterKey
		for followerID in pairs(addon.data.GetFollowers(characterKey)) do
			table.insert(followers, followerID)
		end
		table.sort(followers, SortFollowers)
	end
	return numFollowers
end

function plugin:GetRowInfo(characterKey, index)
	local garrFollowerID = followers[index]
	if not garrFollowerID then return end
	local suffix, prefix = '', nil

	-- also available C_Garrison.GetFollower ... PortraitIconIDByID, DisplayIDByID, SourceTextByID
	-- local specID = C_Garrison.GetFollowerClassSpecByID(garrFollowerID)
	local name = C_Garrison.GetFollowerNameByID(garrFollowerID)
	local quality, level, iLevel, skill1, skill2, skill3, skill4, trait1, trait2, trait3, trait4, xp, levelXP, inactive = addon.data.GetFollowerInfo(characterKey, garrFollowerID)
	local link = addon.data.GetFollowerLink(characterKey, garrFollowerID)

	local building
	for _, buildingID, _, followerID in (DataStore:IteratePlots(characterKey) or nop) do
		if followerID and followerID == garrFollowerID then
			building = buildingID
			break
		end
	end
	building = building and select(4, C_Garrison.GetBuildingInfo(building)) or nil
	if building then
		prefix = '|T' .. building .. ':15|t'
	elseif inactive then
		prefix = '|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t'
	end

	if level < 100 then level = '  ' .. level end
	local labelFormat, traitFormat = '%3$s%2$s|r %1$s', '%2$s|T:1:1|t|T%1$s:15|t'
	local color = RGBTableToColorCode(_G.ITEM_QUALITY_COLORS[quality])
	local label = labelFormat:format(name, (iLevel and iLevel > 600) and iLevel or level, color)
	for i = 1, 4 + 4 do
		local abilityID = select(3 + i, addon.data.GetFollowerInfo(characterKey, garrFollowerID))
		if abilityID > 0 then
			local mechanicID, _, icon = C_Garrison.GetFollowerAbilityCounterMechanicInfo(abilityID)
			if icon and mechanics[mechanicID] then
				-- most traits don't counter any mechanics
				suffix = traitFormat:format(icon, suffix)
			end
		end
	end

	return nil, label, prefix, suffix, link
end

function plugin:GetItemInfo(characterKey, index, itemIndex)
	local garrFollowerID = followers[index]
	if not garrFollowerID or itemIndex > 4 then return end

	local icon, link, tooltipText, count
	local abilityID = select(3 + 4 + itemIndex, addon.data.GetFollowerInfo(characterKey, garrFollowerID))
	if abilityID and abilityID > 0 then
		-- link = C_Garrison.GetFollowerAbilityLink(abilityID)
		icon = C_Garrison.GetFollowerAbilityIcon(abilityID)
		tooltipText = '|T' .. icon .. ':0|t ' .. C_Garrison.GetFollowerAbilityName(abilityID)
			.. '|n' .. C_Garrison.GetFollowerAbilityDescription(abilityID)
		count = 1
	end
	return icon, link, tooltipText, count
end
