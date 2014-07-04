local addonName, addon, _ = ...

-- GLOBALS: _G, DataStore
-- GLOBALS: CreateFrame, RGBTableToColorCode, IsModifiedClick, HandleModifiedItemClick, FauxScrollFrame_Update, FauxScrollFrame_GetOffset, FauxScrollFrame_OnVerticalScroll, GetItemInfo, GetSpellInfo, GetSpellLink, GetCoinTextureString
-- GLOBALS: ipairs, tonumber

local views = addon:GetModule('views')
local lists = views:NewModule('lists', 'AceEvent-3.0')
      lists.icon = 'Interface\\Icons\\INV_Scroll_02' -- grids: Ability_Ensnare
      lists.title = 'Lists'

local shortTags = {
	[_G.FAILED] = '|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t',
	[_G.COMPLETE] = '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t',
	[_G.DAILY] = '•',
	[_G.ELITE] = '+',
	[_G.PLAYER_V_PLAYER] = 'PvP',
	[_G.GROUP] = 'G',
	[_G.GUILD_CHALLENGE_TYPE1] = 'D',
	[_G.GUILD_CHALLENGE_TYPE2] = 'R',
	[_G.GUILD_CHALLENGE_TYPE4] = 'SC',
	[_G.GUILD_CHALLENGE_TYPE3] = 'RBG',
	-- [_G.REPEATABLE] = '∞',
	-- [_G.ITEM_QUALITY5_DESC] = 'L',
}
-- register your provider via table.insert(addon:GetModule('lists').providers, myProvider)
lists.providers = {
	--[[
	[<identifier>] = {
		label = 'My Provider',
		icon = 'Interface\\Icons\\Achievement_Quests_Completed_06',
		events = {'SOME_EVENT', 'SOME_OTHER_EVENT'}, -- events that cause the list to update

		GetNumRows = function(characterKey)
			return <number of results>
		end,
		GetRowInfo = function(characterKey, index)
			return <is header>, <title>, <link (displayed on hover/SHIFT-click)>, <short prefix, optional>, <short suffix, optional>
		end,
		GetItemInfo = function(characterKey, index, itemIndex)
			return <icon>, <link (displayed on hover/SHIFT-click)>, <tooltip text (used when no link is found)>, <count>
		end,
		OnClickRow = function(self, btn, up) ... end, -- optional, self = row, including self.link + self.tiptext
		OnClickItem = function(self, btn, up) ... end, -- optional, self = item button, including self.link + self.tiptext
	},
	--]]
	['quests'] = {
		label = 'Quests',
		icon  = 'Interface\\Icons\\Achievement_Quests_Completed_06',
		events = {'QUEST_LOG_UPDATE'},

		GetNumRows = function(characterKey) return DataStore:GetQuestLogSize(characterKey) end,
		GetRowInfo = function(characterKey, index)
			local isHeader, questLink, questTag, groupSize, _, isComplete = DataStore:GetQuestLogInfo(characterKey, index)
			local questID, questLevel = questLink:match("quest:(%d+):(-?%d+)")
			      questID, questLevel = tonumber(questID), tonumber(questLevel)
			local title = questLink:gsub('[%[%]]', ''):gsub('\124c........', ''):gsub('\124r', '')

			local tags = ''
			if isComplete == 1 then tags = tags .. shortTags[_G.COMPLETE] end
			if questTag and questTag ~= '' then
				if questTag == _G.ITEM_QUALITY5_DESC then
					title = RGBToColorCode(GetItemQualityColor(5)) .. title .. '|r'
				elseif questTag == _G.GROUP then
					tags = tags .. '['..((groupSize and groupSize > 0) and groupSize or 5)..']'
				else
					tags = tags .. '['..(shortTags[questTag] or questTag)..']'
				end
			end

			local progress = DataStore:GetQuestProgressPercentage(characterKey, questID)
			if isComplete ~= 1 and progress > 0 then
				title = title .. ' ('..math.floor(progress*100)..'%)'
			end
			local color  = questLevel and GetRelativeDifficultyColor(DataStore:GetCharacterLevel(characterKey), questLevel)
			local prefix = questLevel and RGBTableToColorCode(color) .. questLevel .. '|r' or ''

			return isHeader, title, not isHeader and questLink or nil, prefix, tags
		end,
		GetItemInfo = function(characterKey, index, itemIndex)
			local icon, link, tooltipText, count
			local numRewards = DataStore:GetQuestLogNumRewards(characterKey, index)
			local _, _, _, _, money = DataStore:GetQuestLogInfo(characterKey, index)
			local rewardsMoney = money and money > 0

			local rewardIndex = itemIndex - (rewardsMoney and 1 or 0)
			if itemIndex == 1 and rewardsMoney then
				icon, link, tooltipText = 'Interface\\MONEYFRAME\\UI-GoldIcon', nil, GetCoinTextureString(money)..' '
			elseif rewardIndex <= numRewards then
				local rewardType, rewardID
				      rewardType, rewardID, count = DataStore:GetQuestLogRewardInfo(characterKey, index, rewardIndex)
				if rewardType == 's' then
					_, _, icon = GetSpellInfo(rewardID)
					link = GetSpellLink(rewardID)
				else
					_, link, _, _, _, _, _, _, _, icon = GetItemInfo(rewardID)
				end
			end

			return icon, link, tooltipText, count
		end,
		OnClickRow = function(self, btn, up)
			if not self.link then return end
			local questID, linkType = addon.GetLinkID(self.link)
			local questIndex = GetQuestLogIndexByID(questID)
			if linkType == 'quest' and questIndex then
				-- ShowUIPanel(QuestLogDetailFrame)
				QuestLog_SetSelection(QuestLogFrame.selectedIndex == questIndex and 0 or questIndex)
			end
		end,
	},
}

local function OnRowClick(self, btn, up)
	if not self.link then
		return
	elseif IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	elseif lists.provider.OnClickRow then
		lists.provider.OnClickRow(self, btn, up)
	end
end

local function OnButtonClick(self, btn, up)
	if not self.link then
		return
	elseif IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	elseif lists.provider.OnClickItem then
		lists.provider.OnClickItem(self, btn, up)
	end
end

local function UpdateList()
	local self = lists
	local characterKey = addon.GetSelectedCharacter()
	local scrollFrame = self.panel.scrollFrame

	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	local numQuests = self.provider.GetNumRows(characterKey)
	for i, button in ipairs(scrollFrame) do
		local index = i + offset
		if index <= numQuests then
			local isHeader, title, link, prefix, suffix = self.provider.GetRowInfo(characterKey, index)
			local isCollapsed = false -- TODO: store

			button:SetText(title)
			button.link = link

			if isHeader then
				local texture = isCollapsed and 'UI-PlusButton-UP' or 'UI-MinusButton-UP'
				button:SetNormalTexture('Interface\\Buttons\\'..texture)
				button:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight')
				button.prefix:SetText('')
				button.suffix:SetText('')
			else
				button:SetNormalTexture('')
				button:SetHighlightTexture('')
				button.prefix:SetText(prefix or '')
				button.suffix:SetText(suffix or '')
			end

			-- we can display associated icons, e.g. quest rewards or crafting reagents
			for itemIndex, itemButton in ipairs(button) do
				local icon, link, tiptext = self.provider.GetItemInfo(characterKey, index, itemIndex)
				if icon then
					itemButton.icon:SetTexture(icon)
					itemButton.link = link
					itemButton.tiptext = tiptext
					itemButton:Show()
				else
					itemButton:Hide()
				end
			end
		else
			-- hide empty rows
			button:SetNormalTexture('')
			button:SetHighlightTexture('')
			button:SetText('')
			button.prefix:SetText('')
			button.suffix:SetText('')
			button.link = nil

			for itemIndex, itemButton in ipairs(button) do
				itemButton:Hide()
			end
		end
	end

	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numQuests, #scrollFrame, 20)
	-- scrollFrame:SetPoint('BOTTOMRIGHT', -10+(needsScrollBar and -14 or 0), 2)
end

function lists:OnEnable()
	for key, provider in pairs(self.providers) do
		if not self.provider then
			self.provider = provider
		end
		if provider.events then
			for _, event in pairs(provider.events) do
				self:RegisterEvent(event, UpdateList)
			end
		end
	end

	local panel = self.panel

	local background = panel:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\TALENTFRAME\\spec-paper-bg')
	      background:SetTexCoord(0, 0.76, 0, 0.86)
	      background:SetPoint('TOPLEFT', 0, -40)
		  background:SetPoint('BOTTOMRIGHT')

	local scrollFrame = CreateFrame('ScrollFrame', '$parentScrollFrame', panel, 'FauxScrollFrameTemplate')
	      scrollFrame:SetSize(360, 354)
	      scrollFrame:SetPoint('TOPLEFT', 0, -40-6)
	      scrollFrame:SetPoint('BOTTOMRIGHT', -24, 2)
	      scrollFrame.scrollBarHideable = true
	panel.scrollFrame = scrollFrame

	scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, 20, UpdateList)
	end)

	for index = 1, 17 do
		local row = CreateFrame('Button', '$parentRow'..index, panel, nil, index)
		      row:SetHeight(20)
		scrollFrame[index] = row

		if index == 1 then
			row:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 10, -4)
		else
			row:SetPoint('TOPLEFT', scrollFrame[index - 1], 'BOTTOMLEFT')
		end
		row:SetPoint('RIGHT', scrollFrame, 'RIGHT')
		row:SetScript('OnEnter', addon.ShowTooltip)
		row:SetScript('OnLeave', addon.HideTooltip)
		row:SetScript('OnClick', OnRowClick)

		row:SetNormalTexture('Interface\\Buttons\\UI-MinusButton-UP')
		local tex = row:GetNormalTexture()
		      tex:SetSize(16, 16)
		      tex:ClearAllPoints()
		      tex:SetPoint('LEFT', 3, 0)
		row:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight', 'ADD')
		local tex = row:GetHighlightTexture()
		      tex:SetSize(16, 16)
		      tex:ClearAllPoints()
		      tex:SetPoint('LEFT', 3, 0)

		row:SetHighlightFontObject('GameFontHighlightLeft')
		row:SetDisabledFontObject('GameFontHighlightLeft')
		row:SetNormalFontObject('GameFontNormalLeft')

		local label = row:CreateFontString(nil, nil, 'GameFontNormalLeft')
		      label:SetPoint('LEFT', 20, 0)
		      label:SetHeight(row:GetHeight())
		row:SetFontString(label)

		local prefix = row:CreateFontString(nil, nil, 'GameFontNormalSmall')
		      prefix:SetPoint('TOPLEFT')
		      prefix:SetPoint('BOTTOMRIGHT', label, 'BOTTOMLEFT')
		row.prefix = prefix

		local suffix = row:CreateFontString(nil, nil, 'GameFontNormalRight')
		      suffix:SetPoint('TOPLEFT', label, 'TOPRIGHT', 4, 0)
		      suffix:SetPoint('BOTTOMRIGHT', -80, 0)
		row.suffix = suffix

		for i = 1, 5 do
			local item = CreateFrame('Button', '$parentItem'..i, row, nil, i)
			      item:SetSize(14, 14)
			local tex = item:CreateTexture(nil, 'BACKGROUND')
			      tex:SetAllPoints()
			item.icon = tex

			item:SetScript('OnEnter', addon.ShowTooltip)
			item:SetScript('OnLeave', addon.HideTooltip)
			item:SetScript('OnClick', OnButtonClick)
			row[i] = item

			if i == 1 then
				item:SetPoint('RIGHT')
			else
				item:SetPoint('RIGHT', row[i-1], 'LEFT', -1, 0)
			end
		end
	end
end

function lists:OnDisable()
	--
end

function lists:Update()
	UpdateList()
end
