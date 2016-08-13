local addonName, addon, _ = ...
local AceConfigDialog = LibStub('AceConfigDialog-3.0')

local function GetConfigurationVariables()
	local function GetCurrencyLabel(currencyID, value)
		local name, _, texture, _, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo(currencyID)
		local label = name or currencyID
		if name then
			label = ('|T%2$s:0|t %3$s%1$s|r'):format(name, texture, isDiscovered and _G.NORMAL_FONT_COLOR_CODE or _G.GRAY_FONT_COLOR_CODE)
		end
		return currencyID, label
	end
	local function GetReminderLabel(interval, value)
		-- alternative: D_MINUTES
		return interval, _G.PET_TIME_LEFT_MINUTES:format(interval)
	end
	local function GetFactionIcons()
		local icons = {
			'Interface\\FriendsFrame\\PlusManz-%s',
			'Interface\\GROUPFRAME\\UI-Group-PVP-%s',
			'Interface\\PVPFrame\\PVPCurrency-Conquest-%s',
			'Interface\\PVPFrame\\PVPCurrency-Honor-%s',
			'Interface\\WorldStateFrame\\%sIcon',
			'Interface\\TARGETINGFRAME\\UI-PVP-%s',
			'Interface\\Timer\\%s-Logo',
		}
		local options = {
			[''] = _G.NONE,
		}
		for _, icon in ipairs(icons) do
			options[icon] = '|T'..icon:format('Horde')..':20|t |T'..icon:format('Alliance')..':20|t'
		end
		return options
	end

	local types = {
		-- main settings
		factionIcon = GetFactionIcons,
		factionIconUndecided = {
			['Interface\\TARGETINGFRAME\\PortraitQuestBadge'] = '|TInterface\\TARGETINGFRAME\\PortraitQuestBadge:20|t',
			['Interface\\MINIMAP\\TRACKING\\BattleMaster'] = '|TInterface\\MINIMAP\\TRACKING\\BattleMaster:20|t',
			['Interface\\ICONS\\FactionChange'] = '|TInterface\\ICONS\\FactionChange:20|t',
		},
		characterFilters = '*none*',
		notes = '*none*',

		-- namespaces
		Money = { -- brokers: money
			history = '*none*',
			tooltipFormat = {
				gsc  = strjoin('', _G.HIGHLIGHT_FONT_COLOR_CODE,
					'54', '|cffffd700g|r '.._G.HIGHLIGHT_FONT_COLOR_CODE,
					'03', '|cffc7c7cfs|r '.._G.HIGHLIGHT_FONT_COLOR_CODE,
					'21', '|cffeda55fc|r'
				),
				icon = strjoin('', '',
					'54', '|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t ',
					'03', '|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t ',
					'21', '|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t'
				),
				dot  = strjoin('', '|cffffd700',
					'54', '|r.|cffc7c7cf',
					'03', '|r.|cffeda55f',
					'21', '|r'
				),
			},
		},
		Currency = { -- brokers: currency
			showInTooltip = 'multiselect',
			showInLDB     = 'multiselect',
		},
		Notifications = { -- module: notifications
			eventReminders = 'multiselect',
		},
	}
	types.Money.ldbFormat = types.Money.tooltipFormat

	local locale = {
		factionIconName = 'Faction icons',
		factionIconUndecidedName = 'Undecided faction icon',

		Currency = {
			iconFirstName = 'Show icon before amount',
			showInTooltipName = 'Show in tooltip',
			showInTooltipValues = GetCurrencyLabel,
			showInLDBName = 'Show on data broker',
			showInLDBValues = GetCurrencyLabel,
			showWeeklyInLDBName = 'Show weekly progress',
			showWeeklyInLDBDesc = 'Show weekly progress on data broker',
		},
		Notifications = {
			eventRemindersName = 'Event reminders',
			eventRemindersDesc = 'Show a reminder when an event is close',
			eventRemindersValues = GetReminderLabel,
			updateIntervalName = 'Update interval',
			updateIntervalDesc = 'Interval (in seconds) between checks of event timings.|nHigher numbers mean fewer checks.',
		},
		Money = {
			ldbFormatName = 'Format for display on data broker',
			tooltipFormatName = 'Format for display in tooltip',
		},
		Tooltip = {
			itemCountsName = 'Item counts',
			onSHIFTName = 'Only on SHIFT',
			onSHIFTDesc = 'Display item counts only when SHIFT is pressed',
			showTotalsName = 'Display totals',
			showTotalsDesc = 'Display sum of items by all characters',
			showGuildsName = 'Show guild',
			showGuildsDesc = 'Show counts for items in guild storage',
			includeGuildCountInTotalName = 'Total includes guild',
			includeGuildCountInTotalDesc = 'Include guild item counts in totals',
			onlyThisCharOnBOPName = 'This character only on BoP',
			onlyThisCharOnBOPDesc = 'When an item is Binds on Pickup (BoP) only display this character\'s items.',
		},
	}

	-- variable, typeMappings, L, includeNamespaces, callback
	return addon.db, types, locale, true, nil
end

local function AddConfigurationExtras(optionsTable)
	local characters = {}
	local function GetDeletableCharacters()
		local thisCharacter = addon.data.GetCurrentCharacter()
		addon.data.GetAllCharacters(characters)
		for i, characterKey in ipairs(characters) do
			if characterKey ~= thisCharacter then
				characters[characterKey] = ('%s: %s'):format(addon.data.GetRealm(characterKey), addon.data.GetCharacterText(characterKey))
				-- local realmName = addon.data.GetRealm(characterKey)
				-- characters[realmName] = characters[realmName] or {}
				-- characters[realmName][characterKey] = addon.data.GetCharacterText(characterKey)
			end
			characters[i] = nil
		end
		return characters
	end
	StaticPopupDialogs['TWINKLE_DELETE_CHARACTER'] = {
		text = 'Are you sure you want to delete |nall data of %s on %s?',
		button1 = _G.OKAY,
		button2 = _G.CANCEL,
		OnAccept = function(_, characterKey) addon.data.DeleteCharacter(characterKey) end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	-- Allow deleting characters.
	optionsTable.args.profile.args.DeleteCharacter = {
		type = 'select',
		name = 'Delete character',
		desc = 'Select a character to be deleted. The logged in character cannot be deleted.|n'
			.. 'Associated guild data will be deleted if no other character is in the guild.|n'
			.. '|cFFFF0000Use with caution, this cannot be undone!|r',
		values = GetDeletableCharacters,
		get = nop,
		set = function(info, characterKey)
			StaticPopup_Show('TWINKLE_DELETE_CHARACTER',
				addon.data.GetCharacterText(characterKey),
				addon.data.GetRealm(characterKey),
				characterKey
			)
		end,
		order = 99,
	}
end

local function InitializeConfiguration(self, args)
	local AceConfig = LibStub('AceConfig-3.0')

	LibStub('LibDualSpec-1.0'):EnhanceDatabase(addon.db, addonName)

	-- Initialize main panel.
	local optionsTable = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(GetConfigurationVariables())
	      optionsTable.name = addonName
	if AddConfigurationExtras then AddConfigurationExtras(optionsTable) end
	AceConfig:RegisterOptionsTable(addonName, optionsTable)


	-- Add panels for submodules.
	local AceConfigRegistry = LibStub('AceConfigRegistry-3.0')
	for name, subModule in addon:IterateModules() do
		if AceConfigRegistry.tables[subModule.name] then
			AceConfigDialog:AddToBlizOptions(subModule.name, name, addonName)
		end
	end

	if addon.db.defaults and addon.db.defaults.profile and next(addon.db.defaults.profile) then
		-- Add panel for profile settings.
		local profileOptions = LibStub('AceDBOptions-3.0'):GetOptionsTable(addon.db)
		profileOptions.name = addonName .. ' - ' .. profileOptions.name
		AceConfig:RegisterOptionsTable(addonName..'_profiles', profileOptions)
		AceConfigDialog:AddToBlizOptions(addonName..'_profiles', 'Profiles', addonName)
	end

	-- Restore original OnShow handler.
	self:SetScript('OnShow', self.origOnShow)
	self.origOnShow = nil

	InterfaceAddOnsList_Update()
	InterfaceOptionsList_DisplayPanel(self)
end

-- Create a placeholder configuration panel.
local panel = AceConfigDialog:AddToBlizOptions(addonName)
panel.origOnShow = panel:GetScript('OnShow')
panel:SetScript('OnShow', InitializeConfiguration)

-- use slash command to toggle config
_G['SLASH_'..addonName..'1'] = '/'..addonName
_G.SlashCmdList[addonName] = function(args) InterfaceOptionsFrame_OpenToCategory(addonName) end
