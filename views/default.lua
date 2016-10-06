local addonName, addon, _ = ...

-- GLOBALS: NONE, MINIMAP_TRACKING_MAILBOX, LEVEL, CLASS_ICON_TCOORDS, YELLOW_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, RAID_CLASS_COLORS, TRACKER_FILTER_COMPLETED_QUESTS
-- GLOBALS: FlowContainer_PauseUpdates, FlowContainer_ResumeUpdates, FlowContainer_RemoveAllObjects, FlowContainer_AddObject, FlowContainer_DoLayout, FlowContainer_Initialize, FlowContainer_SetOrientation, FlowContainer_SetHorizontalSpacing, FlowContainer_SetVerticalSpacing, CreateFrame, SecondsToTimeAbbrev, GetItemInfo, GetCoinTextureString
-- GLOBALS: ipairs, table, string, assert, unpack, tonumber

local views = addon:GetModule('views')
local view  = views:NewModule('Default', 'AceTimer-3.0')
      view.icon = 'Interface\\Icons\\INV_Misc_GroupLooking'
      view.title = _G.GENERAL
view:SetEnabledState(true) -- default view must be available

local function UpdateFlowContainer()
	local container = view.panel.contents
	local character = addon:GetSelectedCharacter()
	local containerWidth = container:GetWidth()

	FlowContainer_PauseUpdates(container)
	FlowContainer_RemoveAllObjects(container)

	for i, object in ipairs(container.contents) do
		if type(object) == 'string' then
			if object == 'newline' then
				FlowContainer_AddLineBreak(container)
			end
		else
			if object.update then
				object:update(character)
			end
			if object.span then
				object:SetWidth(object.span * containerWidth - 10)
			end
			FlowContainer_AddObject(container, object)
			-- FlowContainer_AddSpacer(container, 20)
		end
	end

	FlowContainer_ResumeUpdates(container)
	FlowContainer_DoLayout(container)
end

function view:Load()
	local panel = self.panel

	local portrait = CreateFrame('Frame', '$parentPortrait', panel)
		  portrait:SetPoint('TOPLEFT', 5, -5)
		  portrait:SetSize(70, 70)
	local ring = portrait:CreateTexture('$parentRing', 'OVERLAY')
		  ring:SetTexture('Interface\\TalentFrame\\spec-filagree')
		  ring:SetTexCoord(0.00390625, 0.27734375, 0.48437500, 0.75781250)
		  ring:SetAllPoints()
		  portrait.ring = ring
	local ringIcon = portrait:CreateTexture('$parentIcon', 'ARTWORK')
		  ringIcon:SetPoint('CENTER', ring, 'CENTER')
		  ringIcon:SetSize(56, 56)
		  portrait.icon = ringIcon
	      portrait:SetScale(60/70)
	panel.portrait = portrait

	-- TODO: add smaller spec icons

	local name = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
		  name:SetJustifyH('LEFT')
		  name:SetPoint('BOTTOMLEFT', ringIcon, 'RIGHT', 7, 2)
	panel.name = name

	local level = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		  level:SetPoint('TOPLEFT', ringIcon, 'RIGHT', 7, -2)
		  level:SetJustifyH('LEFT')
	panel.level = level

	local guild = panel:CreateFontString(nil, nil, 'GameFontNormal')
		  guild:SetPoint('RIGHT', panel, 'TOPRIGHT', -10, 0)
		  guild:SetPoint('BOTTOMLEFT', name, 'BOTTOMRIGHT')
		  guild:SetJustifyH('RIGHT')
	panel.guild = guild

	local xp = panel:CreateFontString(nil, nil, 'GameFontNormal')
		  xp:SetPoint('TOPRIGHT', guild, 'BOTTOMRIGHT', 0, -4)
		  xp:SetJustifyH('RIGHT')
	panel.xp = xp

	local background = panel:CreateTexture(nil, 'BACKGROUND')
		  background:SetTexture('Interface\\EncounterJournal\\UI-EJ-JournalBG')
	      background:SetTexCoord(395/1024, 782/1024, 3/512, 426/512)
	      -- background:SetTexture('Interface\\TALENTFRAME\\spec-paper-bg')
		  -- background:SetTexCoord(0, 0.76, 0, 0.86)
		  background:SetPoint('TOPLEFT', 0, -40 -20)
		  background:SetPoint('BOTTOMRIGHT')

	-- flowcontainer that'll hold all our precious data
	local contents = CreateFrame('Frame', nil, panel)
		  contents:SetSize(panel:GetWidth() - 24, panel:GetHeight() - 60 - 20)
		  contents:SetPoint('TOPLEFT', background, 'TOPLEFT', 12, -10)
		  contents:SetPoint('BOTTOMRIGHT', background, 'BOTTOMRIGHT', -12, 10)
		  contents.contents = {}
	panel.contents = contents

	FlowContainer_Initialize(contents)
	FlowContainer_SetOrientation(contents, 'horizontal')
	FlowContainer_SetHorizontalSpacing(contents, 10)
	FlowContainer_SetVerticalSpacing(contents, 10)

	local money = contents:CreateFontString(nil, nil, 'GameFontNormal')
	money:SetJustifyH('LEFT')
	money.update = function(self, character)
		local moneyString = GetCoinTextureString(addon.data.GetMoney(character)):gsub('(%d%d%d+)', BreakUpLargeNumbers)
		self:SetText(moneyString)
	end
	table.insert(contents.contents, money)

	local location = contents:CreateFontString(nil, nil, 'GameFontNormal')
	location:SetJustifyH('LEFT')
	location.span = 1/2
	location.update = function(self, character)
		local location, isResting = addon.data.GetLocation(character)
		self:SetFormattedText('|T%s|t %s', isResting and 'Interface\\CHARACTERFRAME\\UI-StateIcon:16:16:0:0:32:32:0:16:0:16' or 'Interface\\CURSOR\\Crosshairs:16:16', location)
	end
	table.insert(contents.contents, location)

	local mail = contents:CreateFontString(nil, nil, 'GameFontNormal')
	mail:SetJustifyH('LEFT')
	mail.update = function(self, character)
		self:SetFormattedText('|T%s:0|t %d', 'Interface\\MINIMAP\\TRACKING\\Mailbox', addon.data.GetNumMails(character))
	end
	table.insert(contents.contents, mail)

	local mailFrame = CreateFrame('Frame', nil, contents)
	mailFrame:SetAllPoints(mail)
	mailFrame:SetScript('OnEnter', addon.ShowTooltip)
	mailFrame:SetScript('OnLeave', addon.HideTooltip)
	mailFrame.tiptext = function(self, tooltip)
		tooltip:ClearLines()
		local character = addon:GetSelectedCharacter()
		local groupIndex, groupCount
		local numLines = 0

		for i = 1, addon.data.GetNumMails(character) do
			if i == 1 then
				tooltip:AddLine(MINIMAP_TRACKING_MAILBOX)
			end

			local sender, expiresIn, icon, count, link, money, text, returned = addon.data.GetMailInfo(character, i)
			local cmpSender, cmpExpiry, _, cmpCount, cmpLink, _
			if groupIndex then
				cmpSender, cmpExpiry, _, cmpCount, cmpLink = addon.data.GetMailInfo(character, groupIndex)
			end

			link 		= link 	    and link:match('|H.-:(.-):')
			expiresIn 	= expiresIn and string.format(SecondsToTimeAbbrev(expiresIn))
			cmpLink 	= cmpLink   and cmpLink:match('|H.-:(.-):')
			cmpExpiry 	= cmpExpiry and string.format(SecondsToTimeAbbrev(cmpExpiry))

			if link then
				if not groupIndex or (cmpSender == sender and cmpLink == link and cmpExpiry == expiresIn) then
					groupCount = (groupCount or 0) + count
				elseif cmpLink then
					cmpLink = tonumber(cmpLink)
					_, cmpLink = GetItemInfo(cmpLink)

					if not cmpLink then
						view:ScheduleTimer(self:GetScript('OnEnter'), 0.1, self)
						return
					end

					tooltip:AddDoubleLine(cmpLink..'x'..groupCount, cmpSender..' ('..cmpExpiry..')')
					groupCount = count
					numLines = numLines + 1
				end
				groupIndex = i
			end

			if numLines >= 15 then
				tooltip:AddLine('...')
				break
			end
		end

		if groupIndex and numLines < 15 then
			local cmpSender, cmpExpiry, _, cmpCount, cmpLink = addon.data.GetMailInfo(character, groupIndex)
			tooltip:AddDoubleLine(cmpLink..'x'..groupCount, cmpSender..' ('..string.format(SecondsToTimeAbbrev(cmpExpiry or 0))..')')
		end
	end
	mail.trigger = mailFrame

	local auctionsFrame = CreateFrame('Frame', nil, contents)
	local auctions = auctionsFrame:CreateFontString(nil, nil, 'GameFontNormal')
	auctions:SetJustifyH('LEFT')
	auctions.update = function(self, character)
		local auctions, bids = addon.data.GetAuctionState(character)
		self:SetFormattedText('|T%s:0|t %d / %d', 'Interface\\MINIMAP\\TRACKING\\Auctioneer', auctions, bids)
	end
	table.insert(contents.contents, auctions)

	auctionsFrame:SetAllPoints(auctions)
	auctionsFrame:SetScript('OnEnter', addon.ShowTooltip)
	auctionsFrame:SetScript('OnLeave', addon.HideTooltip)
	auctionsFrame.tiptext = function(self, tooltip)
		local character = addon:GetSelectedCharacter()
		local auctions, bids = addon.data.GetAuctionState(character)

		local numLines = 0
		for i = 1, bids do
			if i == 1 then tooltip:AddLine('Bids') end
			local isGoblin, itemID, count, name, price1, price2, timeLeft = addon.data.GetAuctionInfo(character, 'Bids', i)
			local itemName = GetItemInfo(itemID)

			-- delay if we don't have data
			if not itemName then
				view:ScheduleTimer(self:GetScript('OnEnter'), 0.1, self)
				return
			end

			local text = string.format('%s%s|r|T%s:0|t',
				isGoblin and YELLOW_FONT_COLOR_CODE or GREEN_FONT_COLOR_CODE,
				itemName,
				timeLeft > 0 and '' or 'Interface\\FriendsFrame\\StatusIcon-Away')
			tooltip:AddDoubleLine(text, GetCoinTextureString(price1))
			numLines = numLines + 1
			if numLines >= 10 then
				tooltip:AddLine('...')
				break
			end
		end

		numLines = 0
		for i = 1, auctions do
			if i == 1 then tooltip:AddLine('Auctions') end
			local isGoblin, itemID, count, name, price1, price2, timeLeft = addon.data.GetAuctionInfo(character, 'Auctions', i)
			local itemName = GetItemInfo(itemID)

			-- delay if we don't have data
			if not itemName then
				view:ScheduleTimer(self:GetScript('OnEnter'), 0.1, self)
				return
			end

			local text = string.format('%s%s|r|T%s:0|t',
				isGoblin and YELLOW_FONT_COLOR_CODE or GREEN_FONT_COLOR_CODE,
				itemName,
				timeLeft > 0 and '' or 'Interface\\FriendsFrame\\StatusIcon-Away')
			tooltip:AddDoubleLine(text, GetCoinTextureString(price2))
			numLines = numLines + 1
			if numLines >= 10 then
				tooltip:AddLine("...")
				break
			end
		end
	end
	auctions.trigger = auctionsFrame

	local dailyQuestTable = {}
	local dailies = contents:CreateFontString(nil, nil, 'GameFontNormal')
	dailies:SetJustifyH('LEFT')
	dailies.update = function(self, character)
		dailyQuestTable = addon.data.GetDailyQuests(character, dailyQuestTable)
		table.sort(dailyQuestTable)

		self:SetFormattedText('|T%s:0|t %d', 'Interface\\GossipFrame\\DailyActiveQuestIcon', #dailyQuestTable)
	end
	table.insert(contents.contents, dailies)

	local garrisonResources = contents:CreateFontString(nil, nil, 'GameFontNormal')
	garrisonResources:SetJustifyH('LEFT')
	garrisonResources.update = function(self, character)
		if addon.data.GetGarrisonLevel(character) > 0 then
			local _, _, total, icon, collectible = addon.data.GetCurrencyInfo(character, 824)
			local countText = addon.ColorizeText(BreakUpLargeNumbers(total), 10000 - total, 10000)
			if collectible and collectible > 0 then
				countText = countText .. '+' .. addon.ColorizeText(collectible, 500 - collectible, 500)
			end
			self:SetFormattedText('|T%s:0|t %s', icon, countText)
		else
			self:SetText(nil)
		end
	end
	table.insert(contents.contents, garrisonResources)

	local dailiesFrame = CreateFrame('Frame', nil, contents)
	dailiesFrame:SetAllPoints(mail)
	dailiesFrame:SetScript('OnEnter', addon.ShowTooltip)
	dailiesFrame:SetScript('OnLeave', addon.HideTooltip)
	dailiesFrame.tiptext = function(self, tooltip)
		tooltip:ClearLines()

		for i, title in ipairs(dailyQuestTable) do
			if i == 1 then
				tooltip:AddLine(TRACKER_FILTER_COMPLETED_QUESTS)
			end
			tooltip:AddLine(title)

			if i >= 15 then
				tooltip:AddLine('...')
				break
			end
		end
	end
	dailies.trigger = dailiesFrame

	local professions = contents:CreateFontString(nil, nil, 'GameFontNormal')
	professions:SetJustifyH('LEFT')
	professions.update = function(self, character)
		local prof1, prof2, arch, fishing, cooking, firstAid = addon.data.GetProfessions(character)

		local profText = nil
		if prof1 then
			local name, icon, rank, maxRank = addon.data.GetProfessionInfo(character, prof1)
			profText = '|T' .. (icon or '') .. ':0|t ' .. rank
		end
		if prof2 then
			local name, icon, rank, maxRank = addon.data.GetProfessionInfo(character, prof2)
			profText = (profText and profText .. ' ' or '') .. '|T' .. (icon or '') .. ':0|t ' .. rank
		end
		self:SetText(profText)
	end
	table.insert(contents.contents, professions)

	local professionsFrame = CreateFrame('Frame', nil, contents)
	professionsFrame:SetAllPoints(mail)
	professionsFrame:SetScript('OnEnter', addon.ShowTooltip)
	professionsFrame:SetScript('OnLeave', addon.HideTooltip)
	professionsFrame.tiptext = function(self, tooltip)
		local character = addon:GetSelectedCharacter()
		local now = time()
		for recipeID, expires in ipairs(addon.data.GetProfessionCooldowns(character)) do
			local name, _, icon = GetSpellInfo(recipeID)
			tooltip:AddDoubleLine('|T' .. icon .. ':0|t ' .. name, SecondsToTime(expires - now))
		end
	end
	professions.trigger = professionsFrame

	local expansion = GetAccountExpansionLevel()
	local worldBosses = setmetatable({
		[LE_EXPANSION_MISTS_OF_PANDARIA] = {
			[1] = 'Interface\\Icons\\inv_hand_1h_shaclaw',          -- 691, WORLD_BOSS_SHA_OF_ANGER
			[2] = 'Interface\\Icons\\inv_mushanbeastmount',         -- 725, WORLD_BOSS_GALLEON
			[3] = 'Interface\\Icons\\inv_pet_babycloudserpent',     -- 814, WORLD_BOSS_NALAK
			[4] = 'Interface\\Icons\\inv_zandalaribabyraptorwhite', -- 826, WORLD_BOSS_OONDASTA
			[5] = 'Interface\\Icons\\inv_pet_cranegod',             -- 857-860, WORLD_BOSS_FOUR_CELESTIALS
			[6] = 'Interface\\Icons\\spell_fire_rune',              -- 861, WORLD_BOSS_ORDOS
		},
		[LE_EXPANSION_WARLORDS_OF_DRAENOR] = {
			-- local _, bossName, _, _, icon = EJ_GetCreatureInfo(1, journalBossID)
			[7] = 'Interface\\Icons\\CreaturePortrait_FomorHand', 	-- 1291, qid:37460, drov = 1211, qid:37462, tarlna
			[9] = 'Interface\\Icons\\inv_helm_suncrown_d_01', 		-- 1262, qid:37464, rukhmar
			[15] = 'Interface\\Icons\\warlock_summon_doomguard', 	-- 1452, qid:94015, supreme lord kazzak
		},
	}, {
		__index = function(key)
			self[key] = {}
			return self[key]
		end
	})

	local worldBoss = contents:CreateFontString(nil, nil, 'GameFontNormal')
	worldBoss:SetJustifyH('LEFT')
	worldBoss.update = function(self, character)
		local character = addon:GetSelectedCharacter()
		local lockouts, numLockouts = '', 0
		for bossID, icon in pairs(worldBosses[expansion]) do
			local hasLockout = addon.data.IsWorldBossKilledBy(character, bossID)
			numLockouts = numLockouts + (hasLockout and 1 or 0)
			lockouts = lockouts .. '' .. ('|T%2$s:%1$d|t '):format(16,
				hasLockout and 'Interface\\PetBattles\\DeadPetIcon' or icon)
		end
		self:SetText('|TInterface\\Scenarios\\ScenarioIcon-Boss:0|t '..lockouts or '')
	end
	table.insert(contents.contents, worldBoss)

	local function SortByName(a, b) if a.name ~= b.name then return a.name < b.name else return a.id < b.id end end
	local function SortByID(a, b) return a.id < b.id end

	local lfgData = {}
	local lfgs = contents:CreateFontString(nil, nil, 'GameFontNormal')
	lfgs:SetJustifyH('LEFT')
	lfgs.update = function(self, character)
		local data = addon.data.GetRandomLFGState(character, lfgData)
		table.sort(data, SortByName)

		local status
		for _, dungeon in ipairs(data) do
			-- TODO: indicate "dungeon complete, but not all bosses looted"
			status = string.format('%s|T%s:0|t %s', status and status.."|n|T:0|t " or '',
				dungeon.complete and 'Interface\\RAIDFRAME\\ReadyCheck-Ready' or 'Interface\\FriendsFrame\\StatusIcon-Offline',
				dungeon.name
			)
		end
		self:SetFormattedText('|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:0|t %s', status or NONE)
	end
	table.insert(contents.contents, 'newline')
	table.insert(contents.contents, lfgs)

	local lfrs = contents:CreateFontString(nil, nil, 'GameFontNormal')
	lfrs:SetJustifyH('LEFT')
	lfrs.update = function(self, character)
		local data = addon.data.GetLFRState(character, lfgData)
		table.sort(data, SortByID)

		local status
		for _, dungeon in ipairs(data) do
			status = string.format('%s|T%s:0|t %s', status and status..'|n|T:0|t ' or '',
				dungeon.complete and 'Interface\\RAIDFRAME\\ReadyCheck-Ready' or
				dungeon.killed and dungeon.killed > 0 and 'Interface\\FriendsFrame\\StatusIcon-Online' or 'Interface\\FriendsFrame\\StatusIcon-Offline',
				dungeon.name
			)
		end
		self:SetFormattedText('|TInterface\\LFGFRAME\\BattlenetWorking18:0:0:0:0:64:64:12:52:12:52|t %s', status or NONE)
	end
	table.insert(contents.contents, 'newline')
	table.insert(contents.contents, lfrs)

	-- Character text notes.
	local notes = CreateFrame('ScrollFrame', '$parentNotesScroll', contents, 'UIPanelScrollFrameTemplate')
	notes:SetSize(200, 4*14)
	notes.edit = CreateFrame('EditBox', '$parentNotes', notes, 'InputBoxInstructionsTemplate')
	notes.edit:SetFontObject('GameFontHighlight')
	notes.edit:EnableMouse(true)
	notes.edit:SetMultiLine(true)
	notes.edit:SetAutoFocus(false)
	notes.edit:SetSize(notes:GetSize())
	notes.edit:SetAllPoints()
	notes.edit:SetTextInsets(6, 6, 6, 6)
	notes.edit.Left:Hide() notes.edit.Right:Hide() notes.edit.Middle:Hide()
	notes.edit.Instructions:SetPoint('TOPLEFT', 6, -6)
	notes.edit.Instructions:SetPoint('BOTTOMRIGHT', -6, 6)
	notes.edit.Instructions:SetText('Store notes for this character.')
	notes.edit:SetScript('OnEditFocusGained', nop)
	notes.edit:SetScript('OnEscapePressed', EditBox_ClearFocus)
	notes.edit:SetScript('OnEditFocusLost', function(self, character)
		EditBox_ClearHighlight(self)
		local character = self.character or addon:GetSelectedCharacter()
		local unitName, realmName = addon.data.GetName(character), addon.data.GetRealm(character)
		local dbKey = unitName .. ' - ' .. realmName
		if not addon.db.sv.char[dbKey] then addon.db.sv.char[dbKey] = {} end
		addon.db.sv.char[dbKey].notes = self:GetText()
	end)

	local backdrop = {
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border', edgeSize = 16,
		insets = { left = 4, right = 3, top = 4, bottom = 3 },
	}
	notes.scrollBarHideable = true
	notes.noScrollThumb = true
	notes.scrollStep = 11 -- equals line height
	notes.ScrollBar:Hide()
	notes:SetBackdrop(backdrop)
	notes:SetBackdropColor(0, 0, 0)
	notes:SetBackdropBorderColor(0.4, 0.4, 0.4)
	notes:SetScrollChild(notes.edit)
	notes:SetScript('OnScrollRangeChanged', function(self, x, y)
		-- Scroll text while typing.
		local min, max = self.ScrollBar:GetMinMaxValues()
		local delta = max < y and self.scrollStep or -1 * self.scrollStep
		self.ScrollBar:SetMinMaxValues(0, y)
		local scroll = self:GetVerticalScroll() + delta
		scroll = scroll < 0 and 0 or (scroll > y and y or scroll)
		self:SetVerticalScroll(scroll)
	end)
	notes:SetScript('OnMouseDown', function(self) self.edit:SetFocus() end)
	notes.update = function(self, character)
		-- Save data when changing characters.
		if self.edit.character ~= character then self.edit:ClearFocus() end

		self:SetVerticalScroll(0)
		local unitName, realmName = addon.data.GetName(character), addon.data.GetRealm(character)
		local dbKey = unitName .. ' - ' .. realmName
		local text = addon.db.sv.char[dbKey] and addon.db.sv.char[dbKey].notes or ''
		self.edit:SetText(text)
		self.edit.character = character
	end
	table.insert(contents.contents, 'newline')
	table.insert(contents.contents, notes)

	-- TODO: hearth location, raid ids
	-- TODO: register update events

	view.panel = panel

	-- this is the default view, display it upon loading
	views:Show(self)

	return panel
end

function view:Update()
	local panel = self.panel
	local character = addon:GetSelectedCharacter()

	local name = addon.data.GetName(character)
	local _, class = addon.data.GetClass(character)
	panel.name:SetFormattedText('|c%s%s|r', RAID_CLASS_COLORS[class].colorStr, name)
	panel.portrait.icon:SetTexture('Interface\\TargetingFrame\\UI-Classes-Circles')
	panel.portrait.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))

	local level = addon.data.GetLevel(character)
	local raceName, race = addon.data.GetRace(character)
	panel.level:SetFormattedText('%s %d %s', LEVEL, level, raceName)

	local guild, rank, rankIndex = addon.data.GetGuildInfo(character)
	panel.guild:SetFormattedText('%s%s', guild or '',
		(rankIndex and rankIndex == 0) and ' |TInterface\\GROUPFRAME\\UI-Group-LeaderIcon:0|t' or '')

	local xpText
	if level < MAX_PLAYER_LEVEL then
		xpText = '|TInterface\\COMMON\\ReputationStar:16:16:0:0:32:32:16:32:16:32|t ' .. addon.data.GetXPInfo(character)
	else
		xpText = addon.data.GetAverageItemLevel(character) .. ' |TInterface\\GROUPFRAME\\UI-GROUP-MAINTANKICON:0|t'
	end
	panel.xp:SetText(xpText)

	UpdateFlowContainer()
	return 0 -- TODO: get proper "result count" considering lfg, bosses etc
end
