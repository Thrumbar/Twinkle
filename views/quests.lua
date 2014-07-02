local addonName, addon, _ = ...

-- GLOBALS: _G
-- GLOBALS:
-- GLOBALS:

local views = addon:GetModule('views')
local quests = views:NewModule('quests')
      quests.icon = 'Interface\\Icons\\Achievement_Quests_Completed_06'
      quests.title = 'Quests'

function quests:OnEnable()
	local panel = self.panel

	local background = panel:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\TALENTFRAME\\spec-paper-bg')
	      background:SetTexCoord(0, 0.76, 0, 0.86)
	      background:SetPoint('TOPLEFT') --, '$parent', 'TOPRIGHT', -175, 0)
		  background:SetPoint('BOTTOMRIGHT')

	local list = panel:CreateFontString(nil, nil, 'GameFontNormal')
	      list:SetPoint('TOPLEFT', 20, -20)
	      list:SetPoint('BOTTOMRIGHT', -20, 20)
	      list:SetJustifyH('LEFT')
	      list:SetJustifyV('TOP')
	panel.list = list
end

function quests:OnDisable()
	--
end

function quests:Update()
	local characterKey = addon.GetSelectedCharacter()
	local equipmentSets = DataStore:GetEquipmentSetNames(characterKey)

	local text = ''
	for index = 1, DataStore:GetQuestLogSize(characterKey) do
		local _, questLink, questTag, groupSize, money, isComplete = DataStore:GetQuestLogInfo(characterKey, index)
		local questID = addon.GetLinkID(questLink)
		local progress = DataStore:GetQuestProgressPercentage(characterKey, questID)

		if not questID then
			text = text .. questLink .. '|n'
		else
			text = text .. string.format('%d: %s (%d%%)', questID, questLink, progress*100) .. '|n'
		end
	end

	self.panel.list:SetText(text)
end
