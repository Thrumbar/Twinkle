local addonName, addon, _ = ...

-- GLOBALS: NONE, MINIMAP_TRACKING_MAILBOX, LEVEL, CLASS_ICON_TCOORDS, YELLOW_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, RAID_CLASS_COLORS, TRACKER_FILTER_COMPLETED_QUESTS
-- GLOBALS: FlowContainer_PauseUpdates, FlowContainer_ResumeUpdates, FlowContainer_RemoveAllObjects, FlowContainer_AddObject, FlowContainer_DoLayout, FlowContainer_Initialize, FlowContainer_SetOrientation, FlowContainer_SetHorizontalSpacing, FlowContainer_SetVerticalSpacing, CreateFrame, SecondsToTimeAbbrev, GetItemInfo, GetCoinTextureString
-- GLOBALS: ipairs, table, string, assert, unpack, tonumber

local views = addon:GetModule('views')
local view  = views:NewModule('default', 'AceTimer-3.0')
      view.icon = 'Interface\\Icons\\INV_Misc_GroupLooking'
      view.title = 'General'

local function UpdateFlowContainer(container)
	local character = addon.GetSelectedCharacter()
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

function view:OnEnable()
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
		  background:SetTexture('Interface\\TALENTFRAME\\spec-paper-bg')
		  background:SetTexCoord(0, 0.76, 0, 0.86)
		  background:SetPoint('TOPLEFT', 0, -40 -20)
		  background:SetPoint("BOTTOMRIGHT")

	-- flowcontainer that'll hold all our precious data
	local contents = CreateFrame('Frame', nil, panel)
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
		self:SetText(GetCoinTextureString( addon.data.GetMoney(character) ))
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
		local character = addon.GetSelectedCharacter()
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
		local character = addon.GetSelectedCharacter()
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
			tooltip:AddDoubleLine(text, price1)
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
			tooltip:AddDoubleLine(text, price2)
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
		local character = addon.GetSelectedCharacter()
		dailyQuestTable = addon.data.GetDailyQuests(character, dailyQuestTable)
		table.sort(dailyQuestTable)

		self:SetFormattedText('|T%s:0|t %d', 'Interface\\GossipFrame\\DailyActiveQuestIcon', #dailyQuestTable)
	end
	table.insert(contents.contents, dailies)

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

	local worldBosses = {
		'Interface\\Icons\\inv_hand_1h_shaclaw',          -- WORLD_BOSS_SHA_OF_ANGER
		'Interface\\Icons\\inv_mushanbeastmount',         -- WORLD_BOSS_GALLEON
		'Interface\\Icons\\inv_pet_babycloudserpent',     -- WORLD_BOSS_NALAK
		'Interface\\Icons\\inv_zandalaribabyraptorwhite', -- WORLD_BOSS_OONDASTA
		'Interface\\Icons\\inv_pet_cranegod',             -- WORLD_BOSS_FOUR_CELESTIALS
		'Interface\\Icons\\spell_fire_rune',              -- WORLD_BOSS_ORDOS
	}
	local worldBoss = contents:CreateFontString(nil, nil, 'GameFontNormal')
	worldBoss:SetJustifyH('LEFT')
	worldBoss.update = function(self, character)
		local character = addon.GetSelectedCharacter()
		local lockouts, numLockouts = '', 0
		for bossID, icon in ipairs(worldBosses) do
			local hasLockout = DataStore:IsWorldBossKilledBy(character, bossID)
			if hasLockout then
				numLockouts = numLockouts + 1
				lockouts = lockouts .. '' .. '|TInterface\\PetBattles\\DeadPetIcon:0|t'
			else
				lockouts = lockouts .. '' .. '|T'..icon..':0|t'
			end
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

	-- TODO: world bosses, hearth location, raid ids
	-- TODO: register update events

	view.panel = panel
	return panel
end

function view:Update()
	local panel = self.panel
	local character = addon.GetSelectedCharacter()

	local name = addon.data.GetName(character)
	local className, class = addon.data.GetClass(character)
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

	UpdateFlowContainer(panel.contents)
end
