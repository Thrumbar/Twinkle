local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS:
-- GLOBALS:

-- TODO: use this as a base for reputation, currencies etc! combine into lists-view?

local views = addon:GetModule('views')
local quests = views:NewModule('quests')
      quests.icon = 'Interface\\Icons\\Achievement_Quests_Completed_06'
      quests.title = 'Quests'

local tagMap = {
	[_G.FAILED] = '|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t',
	[_G.COMPLETE] = '|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t',
	[_G.DAILY] = '•',
	[_G.ELITE] = '+',
	[_G.PLAYER_V_PLAYER] = 'PvP',
	-- [_G.REPEATABLE] = '∞',
	[_G.CALENDAR_TYPE_DUNGEON] = 'D',
	[_G.GROUP] = 'G',
	[_G.RAID] = 'R',
	[_G.ITEM_QUALITY5_DESC] = 'L',
}

local function OnButtonClick(self, btn, up)
	if self.link and IsModifiedClick() and HandleModifiedItemClick(self.link) then
		return
	end
end

local function UpdateList()
	-- title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID, startEvent, displayQuestID = GetQuestLogTitle(questIndex)
	local characterKey = addon.GetSelectedCharacter()
	local scrollFrame = quests.panel.scrollFrame

	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	local numQuests = DataStore:GetQuestLogSize(characterKey)
	for i, button in ipairs(scrollFrame) do
		local index = i + offset
		if index <= numQuests then
			local _, questLink, questTag, groupSize, money, isComplete = DataStore:GetQuestLogInfo(characterKey, index)
			local questID, questLevel = questLink:match("quest:(%d+):(-?%d+)") -- addon.GetLinkID(questLink)
			      questID, questLevel = tonumber(questID), tonumber(questLevel)
			local progress = DataStore:GetQuestProgressPercentage(characterKey, questID)

			local questTitle = questLink:gsub('[%[%]]', '')
			if isComplete == 1 then
				questTitle = questTitle .. ' |TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t'
			elseif progress > 0 then
				questTitle = questTitle .. ' ('..math.floor(progress*100)..'%)'
			end
			button:SetText(questTitle)
			button.link = nil

			if not questID then
				-- this is a header
				button:SetNormalTexture('Interface\\Buttons\\UI-MinusButton-UP')
				button:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight')
				button.prefix:SetText('')
				button.tag:SetText('')
			else
				-- regular quest
				button:SetNormalTexture('')
				button:SetHighlightTexture('')

				local color = GetQuestDifficultyColor(questLevel)
				button.prefix:SetTextColor(color.r, color.g, color.b, color.a)
				button.prefix:SetText(questLevel)
				button.tag:SetText(questTag and tagMap[questTag] or questTag or '')
				button.link = questLink
			end

			-- display quest rewards, including money
			local rewardsMoney = money and money > 0
			local numRewards = DataStore:GetQuestLogNumRewards(characterKey, index)
			for itemIndex, itemButton in ipairs(button) do
				local icon, link, tiptext
				local rewardIndex = itemIndex - (rewardsMoney and 1 or 0)
				if itemIndex == 1 and rewardsMoney then
					icon, link, tiptext = 'Interface\\MONEYFRAME\\UI-GoldIcon', nil, GetCoinTextureString(money)
				elseif rewardIndex <= numRewards then
					local rewardType, rewardID, amount, isUsable = DataStore:GetQuestLogRewardInfo(characterKey, index, rewardIndex)
					if rewardType == 's' then
						_, _, icon = GetSpellInfo(rewardID)
						link = GetSpellLink(rewardID)
					else
						_, link, _, _, _, _, _, _, _, icon = GetItemInfo(rewardID)
					end
				end
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
			button.tag:SetText('')
			button.link = nil

			for itemIndex, itemButton in ipairs(button) do
				itemButton:Hide()
			end
		end
	end

	local needsScrollBar = FauxScrollFrame_Update(scrollFrame, numQuests, #scrollFrame, 20)
	-- self:SetPoint('BOTTOMRIGHT', -10+(needsScrollBar and -18 or 0), 10)
end

function quests:OnEnable()
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
			row:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT', 10, 0)
		else
			row:SetPoint('TOPLEFT', scrollFrame[index - 1], 'BOTTOMLEFT')
		end
		row:SetPoint('RIGHT', scrollFrame, 'RIGHT')
		row:SetScript('OnClick', OnButtonClick)

		-- row:SetNormalTexture('Interface\\Buttons\\UI-PlusButton-Up')
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

		local tag = row:CreateFontString(nil, nil, 'GameFontNormalRight')
		      tag:SetPoint('TOPLEFT', label, 'TOPRIGHT', 4, 0)
		      tag:SetPoint('BOTTOMRIGHT', -80, 0)
		row.tag = tag

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

function quests:OnDisable()
	--
end

function quests:Update()
	UpdateList()
end
