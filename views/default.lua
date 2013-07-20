local addonName, ns, _ = ...
local view = ns.CreateView("default")

local MAX_PLAYER_LEVEL = 90

function view.Init()
	local tab = ns.GetTab()
	tab:GetNormalTexture():SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
	tab.view = view

	local panel = CreateFrame("Frame", addonName.."PanelDefault")

	local portrait = CreateFrame("Frame", "$parentPortrait", panel)
		  portrait:SetPoint("TOPLEFT", 5, -5)
		  portrait:SetSize(70, 70)
	local ring = portrait:CreateTexture("$parentRing", "OVERLAY")
		  ring:SetTexture("Interface\\TalentFrame\\spec-filagree")
		  ring:SetTexCoord(0.00390625, 0.27734375, 0.48437500, 0.75781250)
		  ring:SetAllPoints()
		  portrait.ring = ring
	local ringIcon = portrait:CreateTexture("$parentIcon", "ARTWORK")
		  ringIcon:SetPoint("CENTER", ring, "CENTER")
		  ringIcon:SetSize(56, 56)
		  portrait.icon = ringIcon
	panel.portrait = portrait

	local name = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		  name:SetJustifyH("LEFT")
		  name:SetPoint("BOTTOMLEFT", ringIcon, "RIGHT", 7, 2)
	panel.name = name

	local level = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		  level:SetPoint("TOPLEFT", ringIcon, "RIGHT", 7, -2)
		  level:SetJustifyH("LEFT")
	panel.level = level

	local guild = panel:CreateFontString(nil, nil, "GameFontDisable")
		  guild:SetPoint("RIGHT", panel, "TOPRIGHT", -10, 0)
		  guild:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT")
		  guild:SetJustifyH("RIGHT")
	panel.guild = guild

	local xp = panel:CreateFontString(nil, nil, "GameFontNormal")
		  xp:SetPoint("TOPRIGHT", guild, "BOTTOMRIGHT", 0, -4)
		  xp:SetJustifyH("RIGHT")
	panel.xp = xp

	-- gold colored horizontal line:
	local line = panel:CreateTexture()
	-- line:SetTexture(0.74, 0.52, 0.06, 0.6)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", portrait, "BOTTOMLEFT", 5, -4)
	line:SetPoint("RIGHT", panel, "RIGHT", -10, 0)

	local bg = panel:CreateTexture(nil, "BACKGROUND")
		  bg:SetTexture("Interface\\TALENTFRAME\\spec-paper-bg")
		  bg:SetTexCoord(0, 0.76, 0, 0.86)
		  bg:SetPoint("TOPLEFT", line, "BOTTOMLEFT", -10, 2)
		  bg:SetPoint("BOTTOMRIGHT")

	local money = panel:CreateFontString(nil, nil, "GameFontNormal")
		  money:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -10)
		  money:SetJustifyH("LEFT")
	panel.money = money

	local location = panel:CreateFontString(nil, nil, "GameFontNormal")
		  location:SetJustifyH("LEFT")
		  location:SetPoint("TOPLEFT", money, "BOTTOMLEFT", 0, -6)
	panel.location = location

	local mail = panel:CreateFontString(nil, nil, "GameFontNormal")
		  mail:SetJustifyH("LEFT")
		  mail:SetPoint("TOPLEFT", line, "BOTTOM", 4, -10)
		  mail:SetWidth(80)
	panel.mail = mail

	local auctions = panel:CreateFontString(nil, nil, "GameFontNormal")
		  auctions:SetJustifyH("LEFT")
		  auctions:SetPoint("LEFT", mail, "RIGHT", 4, 0)
		  auctions:SetPoint("TOPRIGHT", line, "BOTTOMRIGHT", 0, -10)
	panel.auctions = auctions

	view.panel = panel
	return panel
end

function view.Update()
	local panel = view.panel
	assert(view.panel, "Can't update panel before it's created")
	local character = ns.GetSelectedCharacter()

	local name = ns.data.GetName(character)
	local className, class = ns.data.GetClass(character)
	panel.name:SetFormattedText("|c%s%s|r", RAID_CLASS_COLORS[class].colorStr, name)
	panel.portrait.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
	panel.portrait.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))

	local level = ns.data.GetLevel(character)
	local raceName, race = ns.data.GetRace(character)
	panel.level:SetFormattedText("%s %d %s", LEVEL, level, raceName)

	local guild, rank, rankIndex = ns.data.GetGuildInfo(character)
	panel.guild:SetFormattedText("%s%s", guild, rankIndex == 0 and ' |TInterface\\GROUPFRAME\\UI-Group-LeaderIcon:0|t' or '')

	local xpText
	if level < MAX_PLAYER_LEVEL then
		xpText = '|TInterface\\COMMON\\ReputationStar:16:16:0:0:32:32:16:32:16:32|t ' .. ns.data.GetXPInfo(character)
	else
		xpText = ns.data.GetAverageItemLevel(character) .. ' |TInterface\\COMMON\\ReputationStar:16:16:0:1:32:32:0:16:0:16|t'
		-- '|TInterface\\PaperDollInfoFrame\\PaperDollSidebarTabs:20:20:0:1:64:256:1:34:120:155|t'
	end
	panel.xp:SetText(xpText)

	local money = ns.data.GetMoney(character)
	panel.money:SetText(GetCoinTextureString(money))

	local location, isResting = ns.data.GetLocation(character)
	panel.location:SetFormattedText("|T%s|t %s",
		isResting and 'Interface\\CHARACTERFRAME\\UI-StateIcon:16:16:0:0:32:32:0:16:0:16' or 'Interface\\CURSOR\\Crosshairs:16:16',
		location
	)

	local mailCount = ns.data.GetNumMails(character)
	panel.mail:SetFormattedText("|T%s:0|t %d", "Interface\\MINIMAP\\TRACKING\\Mailbox", mailCount)

	local auctions, bids = ns.data.GetAuctionState(character)
	if auctions + bids > 0 then
		panel.auctions:SetFormattedText("|T%s:0|t %d / %d", "Interface\\MINIMAP\\TRACKING\\Auctioneer", auctions, bids)
	else
		panel.auctions:SetText('')
	end
end
